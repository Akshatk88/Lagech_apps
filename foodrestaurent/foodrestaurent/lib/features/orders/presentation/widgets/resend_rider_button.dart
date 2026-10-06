import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';

/// Sends the order's offer to nearby delivery partners again, for when a rider
/// missed the first alert.
///
/// Each press restarts the backend's hunt and rings every nearby rider, so presses
/// are spaced by [_cooldown]. The cooldown is kept per order across rebuilds — the
/// live list rebuilds on every socket event.
class ResendRiderButton extends ConsumerStatefulWidget {
  const ResendRiderButton({super.key, required this.order, this.compact = false});

  final OrderModel order;

  /// A text button for tight rows instead of the full-width banner.
  final bool compact;

  @override
  ConsumerState<ResendRiderButton> createState() => _ResendRiderButtonState();
}

class _ResendRiderButtonState extends ConsumerState<ResendRiderButton> {
  /// Matches the backend's 45s rider accept window: resending sooner would cut
  /// short an offer riders are still looking at.
  static const _cooldown = Duration(seconds: 45);
  static final Map<String, DateTime> _lastSentAt = {};

  bool _sending = false;
  Timer? _ticker;

  int get _secondsLeft {
    final sent = _lastSentAt[widget.order.id];
    if (sent == null) return 0;
    final left = _cooldown - DateTime.now().difference(sent);
    return left.isNegative ? 0 : left.inSeconds + 1;
  }

  @override
  void initState() {
    super.initState();
    if (_secondsLeft > 0) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(liveOrdersControllerProvider.notifier)
          .resendNotification(widget.order.id);
      _lastSentAt[widget.order.id] = DateTime.now();
      _startTicker();
      messenger.showSnackBar(
        const SnackBar(content: Text('Order sent to delivery partners again.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            apiErrorMessage(e, 'Could not resend to delivery partners.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = _secondsLeft;
    final enabled = !_sending && secondsLeft == 0;
    final label = _sending
        ? 'Sending...'
        : secondsLeft > 0
            ? 'Resend in ${secondsLeft}s'
            : 'Resend to drivers';

    if (widget.compact) {
      return TextButton(
        onPressed: enabled ? _resend : null,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.primaryLight.withValues(alpha: 0.12)
            : AppColors.primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryTintStrong),
      ),
      // Message on its own line, button full width below: side by side, the
      // button left the message one word per line on a phone-width card.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_top, size: 18, color: AppColors.primaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No driver yet? Notify them again.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.primaryTintStrong : AppColors.primaryDeepText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: enabled ? _resend : null,
            icon: _sending
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.notifications_active, size: 16),
            label: Text(label, style: const TextStyle(fontSize: 12.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, 42),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
