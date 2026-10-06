import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/business_settings_model.dart';
import '../../../data/models/order_options_model.dart';
import '../../branding/app_colors.dart';

/// Checkout pieces driven by the restaurant's order options: the Delivery /
/// Takeaway toggle, the Now / Schedule slot picker and the rider tip selector.
/// Each is only built when its option is on, so with everything off checkout
/// looks as it always did.

String _rupees(num v) => v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

Color _border(bool isDark) => isDark ? AppColors.borderDark : const Color(0xFFE5E7EB);

/// A selectable pill used by every option row.
class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = selected
        ? AppColors.primary
        : (isDark ? Colors.white : const Color(0xFF1E1E1E));
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Haptics.light();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : _border(isDark),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delivery / Takeaway switch, shown when the restaurant offers both.
class OrderTypeToggle extends StatelessWidget {
  const OrderTypeToggle({
    super.key,
    required this.orderType,
    required this.onChanged,
  });

  final String orderType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Widget segment(String type, String label, IconData icon) {
      final selected = orderType == type;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (selected) return;
            Haptics.light();
            onChanged(type);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? (isDark ? AppColors.cardDark : Colors.white)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected && !isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? AppColors.primary : const Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                        : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFEDEEF2),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          segment('delivery', 'Delivery', Icons.delivery_dining_outlined),
          segment('takeaway', 'Takeaway', Icons.storefront_outlined),
        ],
      ),
    );
  }
}

/// "Today, 1:00 pm - 1:30 pm" for a picked slot.
String scheduledSlotLabel(ScheduleSlot slot, ScheduleOptions schedule) {
  for (final day in schedule.days) {
    if (day.slots.any((s) => s.scheduledAt.isAtSameMomentAs(slot.scheduledAt))) {
      final dayLabel = day.label.isNotEmpty ? day.label : day.dayName;
      return dayLabel.isEmpty ? slot.label : '$dayLabel, ${slot.label}';
    }
  }
  return slot.label;
}

/// Now / Schedule row inside the checkout card. [slot] null means "Now".
class ScheduleChoiceRow extends StatelessWidget {
  const ScheduleChoiceRow({
    super.key,
    required this.title,
    required this.schedule,
    required this.slot,
    required this.onNow,
    required this.onPickSlot,
  });

  /// "Delivery" or "Takeaway".
  final String title;
  final ScheduleOptions schedule;
  final ScheduleSlot? slot;
  final VoidCallback onNow;
  final VoidCallback onPickSlot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final picked = slot;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            picked == null ? Icons.access_time_rounded : Icons.event_available_outlined,
            size: 20,
            color: picked == null
                ? (isDark ? Colors.white : const Color(0xFF1E1E1E))
                : AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  picked == null ? title : 'Scheduled ${title.toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  picked == null
                      ? 'Want this later? Schedule it'
                      : scheduledSlotLabel(picked, schedule),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: picked == null ? FontWeight.w400 : FontWeight.w600,
                    color: picked == null ? const Color(0xFF6B7280) : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _OptionChip(
                      label: 'Now',
                      icon: Icons.bolt_rounded,
                      selected: picked == null,
                      onTap: onNow,
                    ),
                    _OptionChip(
                      label: picked == null ? 'Schedule' : 'Change slot',
                      icon: Icons.calendar_month_outlined,
                      selected: picked != null,
                      onTap: onPickSlot,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Day tabs (Today / Tomorrow) with the slots of the selected day.
/// Resolves to the chosen slot, or null when dismissed.
class ScheduleSlotSheet {
  const ScheduleSlotSheet._();

  static Future<ScheduleSlot?> show(
    BuildContext context, {
    required ScheduleOptions schedule,
    ScheduleSlot? selected,
  }) {
    return showModalBottomSheet<ScheduleSlot>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleSlotSheetBody(schedule: schedule, selected: selected),
    );
  }
}

class _ScheduleSlotSheetBody extends StatefulWidget {
  const _ScheduleSlotSheetBody({required this.schedule, this.selected});

  final ScheduleOptions schedule;
  final ScheduleSlot? selected;

  @override
  State<_ScheduleSlotSheetBody> createState() => _ScheduleSlotSheetBodyState();
}

class _ScheduleSlotSheetBodyState extends State<_ScheduleSlotSheetBody> {
  late int _day;

  @override
  void initState() {
    super.initState();
    final at = widget.selected?.scheduledAt;
    final index = at == null
        ? -1
        : widget.schedule.days.indexWhere(
            (d) => d.slots.any((s) => s.scheduledAt.isAtSameMomentAs(at)),
          );
    _day = index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final days = widget.schedule.days;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: _border(isDark),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Schedule your order',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          const Text(
            'Pick a time slot',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 16),
          if (days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No slots are available right now.',
                style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            // Day tabs
            Row(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Haptics.light();
                        setState(() => _day = i);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: i == _day
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i == _day ? AppColors.primary : _border(isDark),
                            width: i == _day ? 1.4 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              days[i].label.isNotEmpty ? days[i].label : days[i].dayName,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: i == _day ? AppColors.primary : textColor,
                              ),
                            ),
                            if (days[i].dayName.isNotEmpty && days[i].label.isNotEmpty)
                              Text(
                                days[i].dayName,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in days[_day.clamp(0, days.length - 1)].slots)
                      _OptionChip(
                        label: slot.label,
                        selected: widget.selected?.scheduledAt
                                .isAtSameMomentAs(slot.scheduledAt) ??
                            false,
                        onTap: () => Navigator.of(context).pop(slot),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Preset tips, "Custom" (capped at the admin's max) and "No tip".
class TipSelectorCard extends StatelessWidget {
  const TipSelectorCard({
    super.key,
    required this.tips,
    required this.tip,
    required this.onChanged,
  });

  final TipSettings tips;

  /// Current tip in rupees; 0 for none.
  final double tip;
  final ValueChanged<double> onChanged;

  bool get _isCustom =>
      tip > 0 && (tip % 1 != 0 || !tips.presets.contains(tip.round()));

  Future<void> _askCustom(BuildContext context) async {
    final controller = TextEditingController(
      text: _isCustom ? _rupees(tip) : '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            void submit() {
              final v = double.tryParse(controller.text.trim());
              if (v == null || v <= 0) {
                setDialogState(() => error = 'Enter an amount');
                return;
              }
              if (v > tips.max) {
                setDialogState(() => error = 'Maximum tip is ₹${_rupees(tips.max)}');
                return;
              }
              Navigator.of(ctx).pop(v);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Custom tip'),
              content: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: false),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  hintText: 'Up to ₹${_rupees(tips.max)}',
                  errorText: error,
                  border: const OutlineInputBorder(),
                ),
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  onPressed: submit,
                  child: const Text('Add tip', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
    if (value != null) onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border(isDark)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tip your delivery partner',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Padding(
            padding: EdgeInsets.only(left: 30),
            child: Text(
              'The whole tip goes to your delivery partner',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OptionChip(
                label: 'No tip',
                selected: tip <= 0,
                onTap: () => onChanged(0),
              ),
              for (final p in tips.presets)
                _OptionChip(
                  label: '₹$p',
                  selected: !_isCustom && tip.round() == p,
                  onTap: () => onChanged(p.toDouble()),
                ),
              _OptionChip(
                label: _isCustom ? 'Custom ₹${_rupees(tip)}' : 'Custom',
                icon: Icons.edit_outlined,
                selected: _isCustom,
                onTap: () => _askCustom(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Add extra packaging (₹X)" — the restaurant's optional packaging charge.
/// Only built when the order options offer it and it is not required.
class ExtraPackagingCard extends StatelessWidget {
  const ExtraPackagingCard({
    super.key,
    required this.packaging,
    required this.selected,
    required this.onChanged,
  });

  final ExtraPackagingOption packaging;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    return Material(
      color: isDark ? AppColors.cardDark : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _border(isDark)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Haptics.light();
          onChanged(!selected);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add extra packaging (₹${_rupees(packaging.amount)})',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: textColor),
                ),
              ),
              Checkbox(
                value: selected,
                activeColor: AppColors.primary,
                onChanged: (v) {
                  Haptics.light();
                  onChanged(v ?? false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
