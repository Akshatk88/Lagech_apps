import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/services/haptic_service.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/data/models/delivery_order.dart';

/// Confirmation sheet for cancelling an accepted delivery (only offered when
/// the admin allows it and the order hasn't been picked up). Asks for a
/// reason, sends it with the cancel, and pops `true` once the backend has
/// released the order. A refusal (e.g. already picked up) is shown inline
/// and the order is kept.
Future<bool?> showCancelDeliverySheet(BuildContext context, DeliveryOrder order) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CancelDeliverySheet(order: order),
  );
}

class CancelDeliverySheet extends ConsumerStatefulWidget {
  const CancelDeliverySheet({super.key, required this.order});

  final DeliveryOrder order;

  @override
  ConsumerState<CancelDeliverySheet> createState() => _CancelDeliverySheetState();
}

class _CancelDeliverySheetState extends ConsumerState<CancelDeliverySheet> {
  static const _otherReason = 'Other';
  static const _reasons = [
    'Vehicle problem',
    'Accident / emergency',
    'Restaurant too far',
    'Restaurant delay',
    _otherReason,
  ];
  static const _maxReasonLength = 300;

  final TextEditingController _otherController = TextEditingController();
  String? _selected;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  /// The reason sent to the backend, or null while none is complete.
  String? get _reason {
    if (_selected == null) return null;
    if (_selected != _otherReason) return _selected;
    final typed = _otherController.text.trim();
    return typed.isEmpty ? null : typed;
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;
    HapticService.medium();
    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await ref
        .read(ordersControllerProvider.notifier)
        .rejectOrder(widget.order.id, reason: reason);
    if (!mounted) return;
    result.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (error) => setState(() {
        _error = error.message;
        _submitting = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E1E1E);
    final subTextColor = isDarkMode ? Colors.grey[400] : Colors.grey[600];
    final canSubmit = _reason != null && !_submitting;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cancel delivery?',
                  style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: textColor),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Order #${widget.order.orderCode} will be assigned to another rider. Tell us why you can\'t deliver it.',
                  style: TextStyle(fontSize: 13.sp, color: subTextColor),
                ),
                SizedBox(height: 16.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    for (final reason in _reasons)
                      ChoiceChip(
                        label: Text(reason),
                        selected: _selected == reason,
                        showCheckmark: false,
                        selectedColor: theme.primaryColor,
                        labelStyle: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: _selected == reason ? Colors.white : textColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.r),
                          side: BorderSide(
                            color: _selected == reason ? theme.primaryColor : Colors.grey[300]!,
                          ),
                        ),
                        onSelected: _submitting
                            ? null
                            : (_) {
                                HapticService.light();
                                setState(() {
                                  _selected = reason;
                                  _error = null;
                                });
                              },
                      ),
                  ],
                ),
                if (_selected == _otherReason) ...[
                  SizedBox(height: 12.h),
                  TextField(
                    controller: _otherController,
                    enabled: !_submitting,
                    autofocus: true,
                    maxLength: _maxReasonLength,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14.sp, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Describe the reason',
                      hintStyle: TextStyle(fontSize: 13.sp, color: subTextColor),
                      contentPadding: EdgeInsets.all(12.r),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16.r),
                        borderSide: BorderSide(color: theme.primaryColor),
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  SizedBox(height: 12.h),
                  Text(
                    _error!,
                    style: TextStyle(fontSize: 13.sp, color: Colors.red[700], fontWeight: FontWeight.w600),
                  ),
                ],
                SizedBox(height: 20.h),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          side: BorderSide(color: Colors.grey[300]!),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: Text(
                          'Keep delivery',
                          style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 14.sp),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: canSubmit ? _submit : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.primaryColor.withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                        ),
                        child: _submitting
                            ? SizedBox(
                                width: 20.r,
                                height: 20.r,
                                child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                'Cancel delivery',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.sp),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
