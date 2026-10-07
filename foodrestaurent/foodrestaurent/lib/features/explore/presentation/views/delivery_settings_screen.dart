import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/business_settings/data/business_settings_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';

class DeliverySettingsScreen extends ConsumerWidget {
  const DeliverySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);
    final businessSettings = ref.watch(restaurantBusinessSettingsProvider).value;
    final takeawayAvailable = businessSettings?.takeawayAvailable ?? false;
    final packagingAvailable =
        businessSettings?.extraPackagingAvailable ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) context.pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Settings',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const Text(
              'Manage your delivery status',
              style: TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ],
        ),
        centerTitle: false,
      ),
      body: restaurantAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            apiErrorMessage(error, 'Failed to load delivery settings.'),
          ),
        ),
        data: (restaurant) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildStatusCard(context, ref, restaurant.isAcceptingOrders),
              const SizedBox(height: 16),
              if (takeawayAvailable) ...[
                _TakeawayCard(enabled: restaurant.takeawayEnabled),
                const SizedBox(height: 16),
              ],
              if (packagingAvailable) ...[
                _PackagingCard(settings: restaurant.extraPackaging),
                const SizedBox(height: 16),
              ],
              _buildNoteCard(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context,
    WidgetRef ref,
    bool isAcceptingOrders,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceVariantDark
                      : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delivery Status',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Control when you receive delivery orders',
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Turn on delivery',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isAcceptingOrders ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isAcceptingOrders
                            ? 'Receiving orders'
                            : 'Not receiving orders',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: isAcceptingOrders,
                activeThumbColor: Colors.green,
                onChanged: (value) async {
                  try {
                    await ref
                        .read(restaurantProfileControllerProvider.notifier)
                        .updateAvailability(value);
                  } catch (e) {
                    if (context.mounted) {
                      final message = apiErrorMessage(e, 'Failed to update. Please try again.');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.1)
            : const Color(0xFFF0F5FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.primary.withValues(alpha: 0.2)
              : const Color(0xFFE5EEFF),
        ),
      ),
      child: RichText(
        text: TextSpan(
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : const Color(0xFF4A5568),
            fontSize: 14,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: 'Note: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const TextSpan(
              text:
                  'When delivery is turned off, customers won\'t be able to place delivery orders from your restaurant. You can turn it back on anytime.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the outlet opt in or out of takeaway orders (customer collects at the
/// counter). Only shown when the platform offers takeaway at all.
class _TakeawayCard extends ConsumerStatefulWidget {
  const _TakeawayCard({required this.enabled});

  final bool enabled;

  @override
  ConsumerState<_TakeawayCard> createState() => _TakeawayCardState();
}

class _TakeawayCardState extends ConsumerState<_TakeawayCard> {
  bool _saving = false;

  Future<void> _toggle(bool value) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateTakeawayEnabled(value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, 'Failed to update. Please try again.'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariantDark
                  : const Color(0xFFF5F6FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.shopping_bag_outlined,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Takeaway orders',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Customers order ahead and collect at your counter with a '
                  'pickup code',
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Switch(
              value: widget.enabled,
              activeThumbColor: Colors.green,
              onChanged: _toggle,
            ),
        ],
      ),
    );
  }
}

/// The outlet's extra packaging charge: on/off, the amount and whether every
/// order pays it or only customers who tick it at checkout. Only shown while
/// the platform allows extra packaging charges.
class _PackagingCard extends ConsumerStatefulWidget {
  const _PackagingCard({required this.settings});

  final ExtraPackagingSettings settings;

  @override
  ConsumerState<_PackagingCard> createState() => _PackagingCardState();
}

class _PackagingCardState extends ConsumerState<_PackagingCard> {
  late bool _enabled;
  late bool _required;
  late final TextEditingController _amount;
  bool _saving = false;
  String? _amountError;

  static String _rupees(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  void _resetFrom(ExtraPackagingSettings s) {
    _enabled = s.enabled;
    _required = s.required;
    _amount.text = s.amount > 0 ? _rupees(s.amount) : '';
  }

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
    _resetFrom(widget.settings);
  }

  @override
  void didUpdateWidget(covariant _PackagingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final s = widget.settings;
    final o = oldWidget.settings;
    if (!_saving &&
        (s.enabled != o.enabled ||
            s.required != o.required ||
            s.amount != o.amount)) {
      _resetFrom(s);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool get _dirty {
    final s = widget.settings;
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    return _enabled != s.enabled ||
        (_enabled && (_required != s.required || amount != s.amount));
  }

  Future<void> _save() async {
    final text = _amount.text.trim();
    final amount = text.isEmpty ? null : double.tryParse(text);
    if (_enabled) {
      if (amount == null || amount <= 0) {
        setState(() => _amountError = 'Enter the packaging charge');
        return;
      }
      if (amount > 500) {
        setState(() => _amountError = 'Maximum is ₹500');
        return;
      }
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _amountError = null;
      _saving = true;
    });
    try {
      // Switching off sends only `enabled`, so the amount is kept for later.
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updatePackagingSettings(
            enabled: _enabled,
            amount: _enabled ? amount : null,
            required: _enabled ? _required : null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Packaging charge saved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              apiErrorMessage(e, 'Failed to update. Please try again.'),
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: onSurface.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.inventory_2_outlined, color: onSurface),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Packaging charge',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your own extra packaging charge, paid to you with no '
                      'commission',
                      style: TextStyle(color: secondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _enabled,
                activeThumbColor: Colors.green,
                onChanged: _saving
                    ? null
                    : (v) => setState(() {
                        _enabled = v;
                        _amountError = null;
                      }),
              ),
            ],
          ),
          if (_enabled) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d{0,3}(\.\d{0,2})?'),
                ),
              ],
              onChanged: (_) => setState(() => _amountError = null),
              decoration: InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
                hintText: 'Up to ₹500',
                errorText: _amountError,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Charge on every order',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _required
                            ? 'Added to every order'
                            : 'Customers choose it at checkout',
                        style: TextStyle(color: secondary, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _required,
                  activeThumbColor: Colors.green,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _required = v),
                ),
              ],
            ),
          ],
          if (_dirty || _saving) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
