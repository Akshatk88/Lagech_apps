import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/wallet_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_refresh_indicator.dart';
import '../viewmodels/loyalty_points_viewmodel.dart';

/// Full loyalty points ledger, opened from the wallet's loyalty card.
class LoyaltyPointsScreen extends ConsumerStatefulWidget {
  const LoyaltyPointsScreen({super.key});

  @override
  ConsumerState<LoyaltyPointsScreen> createState() => _LoyaltyPointsScreenState();
}

class _LoyaltyPointsScreenState extends ConsumerState<LoyaltyPointsScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(loyaltyHistoryViewModelProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(loyaltyHistoryViewModelProvider);
    final viewModel = ref.read(loyaltyHistoryViewModelProvider.notifier);

    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryColor = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final cardColor = isDark ? AppColors.cardDark : AppColors.cardLight;
    final backgroundColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textColor, size: 20),
          onPressed: () {
            Haptics.light();
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/wallet');
            }
          },
        ),
        title: Text(
          'Loyalty Points',
          style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: AppRefreshIndicator(
          onRefresh: viewModel.load,
          child: _buildBody(state, viewModel, isDark, cardColor, textColor, secondaryColor),
        ),
      ),
    );
  }

  Widget _buildBody(
    LoyaltyHistoryState state,
    LoyaltyHistoryViewModel viewModel,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color secondaryColor,
  ) {
    if (state.status == LoyaltyHistoryStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == LoyaltyHistoryStatus.error) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 54),
          const SizedBox(height: 16),
          Text(
            state.errorMessage ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: secondaryColor),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                Haptics.medium();
                viewModel.load();
              },
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              label: const Text('RETRY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
    }

    final summary = state.summary;
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (summary != null) _buildSummary(summary, isDark, cardColor, textColor, secondaryColor),
        const SizedBox(height: 20),
        Text(
          'Points History',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        if (state.transactions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                Icon(Icons.stars_rounded, size: 44, color: AppColors.primary),
                const SizedBox(height: 12),
                Text(
                  'No points activity yet',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 6),
                Text(
                  'Points you earn on delivered orders and convert to wallet money will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ],
            ),
          )
        else
          ...state.transactions.map(
            (txn) => LoyaltyTransactionTile(
              txn: txn,
              isDark: isDark,
              cardColor: cardColor,
              textColor: textColor,
              secondaryColor: secondaryColor,
            ),
          ),
        if (state.isLoadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  Widget _buildSummary(
    LoyaltyPoints summary,
    bool isDark,
    Color cardColor,
    Color textColor,
    Color secondaryColor,
  ) {
    Widget stat(String label, String value) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11.5, color: secondaryColor)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: isDark
            ? []
            : [const BoxShadow(color: AppColors.shadow1, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              stat('Points balance', '${summary.points}'),
              stat('Worth', summary.worthText),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              stat('Total earned', '${summary.totalEarned}'),
              stat('Total converted', '${summary.totalConverted}'),
            ],
          ),
          if (summary.pointsPerHundred > 0) ...[
            const SizedBox(height: 14),
            Text(
              'Earn ${summary.pointsPerHundred} points for every ₹100 on delivered orders.',
              style: TextStyle(fontSize: 12, color: secondaryColor),
            ),
          ],
        ],
      ),
    );
  }
}

/// One ledger row — shared by this screen and the wallet's loyalty card.
class LoyaltyTransactionTile extends StatelessWidget {
  final LoyaltyPointsTransaction txn;
  final bool isDark;
  final Color cardColor;
  final Color textColor;
  final Color secondaryColor;

  const LoyaltyTransactionTile({
    super.key,
    required this.txn,
    required this.isDark,
    required this.cardColor,
    required this.textColor,
    required this.secondaryColor,
  });

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  String _title() {
    if (txn.note.trim().isNotEmpty) return txn.note.trim();
    if (txn.source.toLowerCase() == 'conversion') return 'Converted to wallet';
    if (txn.source.toLowerCase() == 'order') return 'Earned on order';
    return txn.isCredit ? 'Points earned' : 'Points used';
  }

  String _date() {
    final d = txn.createdAt?.toLocal();
    if (d == null) return '';
    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} ${_months[(d.month - 1).clamp(0, 11)]}, $hour:$minute $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = txn.isCredit;
    final date = _date();
    final subtitle = [
      if (date.isNotEmpty) date,
      if (!isCredit && txn.walletAmount > 0) '₹${txn.walletAmount.toStringAsFixed(2)} to wallet',
    ].join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark
            ? []
            : [const BoxShadow(color: AppColors.shadow2, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isCredit ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCredit ? Icons.stars_rounded : Icons.swap_horiz_rounded,
              color: isCredit ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: textColor),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 11.5, color: secondaryColor)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isCredit ? '+' : '-'}${txn.points} pts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isCredit ? AppColors.success : textColor,
            ),
          ),
        ],
      ),
    );
  }
}
