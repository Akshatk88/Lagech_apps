import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/widgets/app_toast.dart';
import 'package:food_user_application/features/orders/domain/order_model.dart';
import 'package:food_user_application/features/orders/presentation/controllers/live_orders_controller.dart';

/// For a takeaway order: checks the 4-digit pickup code the customer shows at
/// the counter and hands the order over (it becomes `delivered`). The
/// restaurant never receives the code itself. Renders nothing for orders that
/// cannot be handed over.
class TakeawayHandoverButton extends ConsumerWidget {
  const TakeawayHandoverButton({
    super.key,
    required this.order,
    this.onHandedOver,
  });

  final OrderModel order;

  /// Called with the updated order after a successful handover.
  final ValueChanged<OrderModel>? onHandedOver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!order.canHandOver) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final updated = await showDialog<OrderModel>(
              context: context,
              builder: (_) => _HandoverDialog(order: order),
            );
            if (updated == null) return;
            onHandedOver?.call(updated);
            if (context.mounted) {
              AppToast.showSuccess(
                context,
                'Order ${order.formattedDisplayId} handed over',
              );
            }
          },
          icon: const Icon(Icons.verified_outlined, size: 20),
          label: const Text(
            'Verify pickup code & hand over',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: AppColors.successDeep,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
    );
  }
}

class _HandoverDialog extends ConsumerStatefulWidget {
  const _HandoverDialog({required this.order});

  final OrderModel order;

  @override
  ConsumerState<_HandoverDialog> createState() => _HandoverDialogState();
}

class _HandoverDialogState extends ConsumerState<_HandoverDialog> {
  final _controller = TextEditingController();
  bool _submitting = false;

  /// Shown inside the dialog: a SnackBar would sit behind the barrier.
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _controller.text.trim();
    if (code.length != 4) {
      setState(() => _error = 'Enter the 4-digit pickup code.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final updated = await ref
          .read(liveOrdersControllerProvider.notifier)
          .handOverTakeaway(widget.order.id, code);
      if (mounted) Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = apiErrorMessage(e, 'Could not hand over. Please try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Hand over takeaway'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ask the customer for the pickup code shown in their app for '
            '${widget.order.formattedDisplayId}.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            enabled: !_submitting,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 12,
            ),
            decoration: InputDecoration(
              hintText: '----',
              counterText: '',
              errorText: _error,
              errorMaxLines: 3,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Hand over'),
        ),
      ],
    );
  }
}
