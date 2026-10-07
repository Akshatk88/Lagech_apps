import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/features/reviews/domain/review_model.dart';
import 'package:food_user_application/features/reviews/presentation/controllers/reviews_controller.dart';

/// Customer reviews of this restaurant, newest first, with the restaurant's
/// replies. "Reply" / "Edit reply" shows only while the admin's Business
/// Settings let restaurants reply.
class ReviewsList extends ConsumerWidget {
  const ReviewsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsControllerProvider);

    return AppRefreshIndicator(
      onRefresh: () => ref.read(reviewsControllerProvider.notifier).refresh(),
      child: reviewsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                apiErrorMessage(error, 'Failed to load reviews.'),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        data: (page) => page.reviews.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No reviews yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                itemCount: page.reviews.length + 1,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) => index == 0
                    ? _Summary(page: page)
                    : _ReviewCard(
                        review: page.reviews[index - 1],
                        canReply: page.canReply,
                      ),
              ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.page});

  final ReviewsPage page;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 22),
        const SizedBox(width: 4),
        Text(
          page.rating.toStringAsFixed(1),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Text('${page.totalRatings} ratings', style: TextStyle(fontSize: 13, color: muted)),
        if (!page.canReply) ...[
          const Spacer(),
          Flexible(
            child: Text(
              'Replies are off',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review, required this.canReply});

  final ReviewModel review;
  final bool canReply;

  Future<void> _openReply(BuildContext context) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReplySheet(review: review),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final date = review.ratedAt == null
        ? ''
        : DateFormat('d MMM yyyy').format(review.ratedAt!.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  review.userName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: onSurface,
                  ),
                ),
              ),
              Text(
                date,
                style: TextStyle(fontSize: 11, color: onSurface.withValues(alpha: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  Icons.star_rounded,
                  size: 16,
                  color: i <= review.rating
                      ? const Color(0xFFFFB800)
                      : onSurface.withValues(alpha: 0.2),
                ),
              if (review.dishName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    review.dishName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.6)),
                  ),
                ),
              ],
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: TextStyle(fontSize: 13, color: onSurface.withValues(alpha: 0.85)),
            ),
          ],
          if (review.hasReply) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    review.repliedAt == null
                        ? 'Your reply'
                        : 'Your reply · ${DateFormat('d MMM yyyy').format(review.repliedAt!.toLocal())}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(review.reply, style: const TextStyle(fontSize: 12.5)),
                ],
              ),
            ),
          ],
          if (canReply) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openReply(context),
                icon: Icon(review.hasReply ? Icons.edit_outlined : Icons.reply, size: 18),
                label: Text(review.hasReply ? 'Edit reply' : 'Reply'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Write, edit or remove the reply to one review. Pops `true` once saved.
class _ReplySheet extends ConsumerStatefulWidget {
  const _ReplySheet({required this.review});

  final ReviewModel review;

  @override
  ConsumerState<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends ConsumerState<_ReplySheet> {
  late final _controller = TextEditingController(text: widget.review.reply);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String text) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(reviewsControllerProvider.notifier).reply(widget.review.id, text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = apiErrorMessage(e, 'Could not save the reply. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reply to ${widget.review.userName}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          if (widget.review.comment.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${widget.review.comment}"',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 1000,
            minLines: 3,
            maxLines: 6,
            enabled: !_saving,
            decoration: const InputDecoration(
              hintText: 'Your reply is shown to customers under the review',
              border: OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              if (widget.review.hasReply)
                TextButton(
                  onPressed: _saving ? null : () => _save(''),
                  child: const Text('Remove reply'),
                ),
              const Spacer(),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) => FilledButton(
                  onPressed: _saving || value.text.trim().isEmpty
                      ? null
                      : () => _save(value.text),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(widget.review.hasReply ? 'Save' : 'Reply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
