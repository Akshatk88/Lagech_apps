import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/order_help_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';
import '../viewmodels/order_help_viewmodel.dart';

enum OrderHelpKind { refund, issue }

/// Bottom sheet for "Request refund" and "Report an issue" on an order:
/// a reason from the admin's list, an optional note and up to three photos.
///
/// Refunds also offer "Other" with the customer's own words. An issue report
/// may only use the admin's reasons, unless the admin has set none up.
class OrderHelpSheet extends ConsumerStatefulWidget {
  final OrderHelpKind kind;
  final String orderId;
  final String orderNumber;

  /// Refunds only: the most that can be refunded, and where it would go.
  final double? maxAmount;
  final String refundTo;

  const OrderHelpSheet({
    super.key,
    required this.kind,
    required this.orderId,
    required this.orderNumber,
    this.maxAmount,
    this.refundTo = '',
  });

  /// Opens the sheet; resolves true when something was sent.
  static Future<bool> show(
    BuildContext context, {
    required OrderHelpKind kind,
    required String orderId,
    required String orderNumber,
    double? maxAmount,
    String refundTo = '',
  }) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderHelpSheet(
        kind: kind,
        orderId: orderId,
        orderNumber: orderNumber,
        maxAmount: maxAmount,
        refundTo: refundTo,
      ),
    );
    return sent == true;
  }

  @override
  ConsumerState<OrderHelpSheet> createState() => _OrderHelpSheetState();
}

class _OrderHelpSheetState extends ConsumerState<OrderHelpSheet> {
  static const _maxPhotos = 3;
  static const _otherId = '__other__';

  final _noteController = TextEditingController();
  final _otherController = TextEditingController();
  final List<String> _photos = [];
  String? _reasonId;

  bool get _isRefund => widget.kind == OrderHelpKind.refund;

  @override
  void dispose() {
    _noteController.dispose();
    _otherController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= _maxPhotos) return;
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
      if (image == null || !mounted) return;
      Haptics.light();
      setState(() => _photos.add(image.path));
    } catch (_) {
      if (mounted) AppSnackbar.error(context, 'Could not open your photos.');
    }
  }

  Future<void> _submit(List<HelpReason> reasons) async {
    final usingOwnWords = _reasonId == _otherId || reasons.isEmpty;
    final ownWords = _otherController.text.trim();
    if (!usingOwnWords && _reasonId == null) {
      AppSnackbar.error(context, 'Please choose a reason.');
      return;
    }
    if (usingOwnWords && ownWords.isEmpty) {
      AppSnackbar.error(context, _isRefund ? 'Please tell us why.' : 'Please tell us what went wrong.');
      return;
    }
    final note = _noteController.text.trim();
    final vm = ref.read(orderHelpViewModelProvider.notifier);
    Haptics.medium();
    final error = _isRefund
        ? await vm.requestRefund(
            orderId: widget.orderId,
            reasonId: usingOwnWords ? null : _reasonId,
            reason: usingOwnWords ? ownWords : null,
            note: note.isEmpty ? null : note,
            imagePaths: List.of(_photos),
          )
        : await vm.reportIssue(
            orderId: widget.orderId,
            reasonId: usingOwnWords ? null : _reasonId,
            reason: usingOwnWords ? ownWords : null,
            note: note.isEmpty ? null : note,
            imagePaths: List.of(_photos),
          );
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.error(context, error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final sending = ref.watch(orderHelpViewModelProvider);
    final reasonsAsync = ref.watch(_isRefund ? refundReasonsProvider : orderIssueReasonsProvider);
    final reasons = reasonsAsync.asData?.value ?? const <HelpReason>[];

    final showOwnWords = _isRefund ? _reasonId == _otherId : (reasonsAsync.hasValue && reasons.isEmpty);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _isRefund ? 'Request a refund' : 'Report an issue',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor),
            ),
            const SizedBox(height: 4),
            Text(
              _isRefund
                  ? 'Order #${widget.orderNumber}${widget.maxAmount != null ? ' · up to ₹${widget.maxAmount!.toStringAsFixed(0)}' : ''}'
                  : 'Order #${widget.orderNumber}',
              style: TextStyle(fontSize: 13, color: secondary),
            ),
            if (_isRefund && widget.refundTo.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.refundTo == 'razorpay'
                    ? 'If approved, the money goes back to your original payment method.'
                    : 'If approved, the money goes to your Lagech wallet.',
                style: TextStyle(fontSize: 12, color: secondary),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              _isRefund ? 'Why do you want a refund?' : 'What went wrong?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 10),
            reasonsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
              error: (_, _) => Row(
                children: [
                  Expanded(
                    child: Text('Could not load the reasons.', style: TextStyle(fontSize: 13, color: secondary)),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(_isRefund ? refundReasonsProvider : orderIssueReasonsProvider),
                    child: Text('RETRY', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final reason in list) _reasonChip(reason.id, reason.text, isDark, textColor),
                  if (_isRefund) _reasonChip(_otherId, 'Other', isDark, textColor),
                ],
              ),
            ),
            if (showOwnWords) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _otherController,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: _isRefund ? 'Your reason' : 'What went wrong',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLength: 1000,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Add details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Photos (optional, up to $_maxPhotos)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (var i = 0; i < _photos.length; i++) _photoTile(i, border),
                if (_photos.length < _maxPhotos)
                  InkWell(
                    onTap: sending ? null : _addPhoto,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Icon(Icons.add_a_photo_outlined, color: secondary),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: sending || reasonsAsync.isLoading ? null : () => _submit(reasons),
                child: sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        _isRefund ? 'SEND REFUND REQUEST' : 'SEND REPORT',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reasonChip(String id, String text, bool isDark, Color textColor) {
    final selected = _reasonId == id;
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      onSelected: (_) {
        Haptics.light();
        setState(() => _reasonId = id);
      },
      selectedColor: AppColors.primaryAlpha(0.14),
      labelStyle: TextStyle(
        color: selected ? AppColors.primary : textColor,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide(color: selected ? AppColors.primary : (isDark ? AppColors.borderDark : AppColors.borderLight)),
      showCheckmark: false,
    );
  }

  Widget _photoTile(int index, Color border) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(File(_photos[index]), width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          top: -6,
          right: -6,
          child: GestureDetector(
            onTap: () => setState(() => _photos.removeAt(index)),
            child: Container(
              decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
