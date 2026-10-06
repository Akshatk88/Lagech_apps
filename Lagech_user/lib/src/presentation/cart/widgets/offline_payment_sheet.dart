import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/business_settings_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/app_snackbar.dart';

/// Offline payment (bank transfer, UPI, ...) at checkout.
///
/// The customer picks one of the admin's methods, sees where to send the
/// money, pays outside the app, then fills in the fields the method asks for
/// (e.g. the transaction id). Returns the `offlinePayment` object for
/// `POST /food/orders` — `{ methodId, fields, note }` — or null if dismissed.
class OfflinePaymentSheet {
  const OfflinePaymentSheet._();

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required List<OfflinePaymentMethod> methods,
    required double amount,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OfflinePaymentSheetBody(methods: methods, amount: amount),
    );
  }
}

class _OfflinePaymentSheetBody extends StatefulWidget {
  const _OfflinePaymentSheetBody({required this.methods, required this.amount});

  final List<OfflinePaymentMethod> methods;
  final double amount;

  @override
  State<_OfflinePaymentSheetBody> createState() => _OfflinePaymentSheetBodyState();
}

class _OfflinePaymentSheetBodyState extends State<_OfflinePaymentSheetBody> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final Map<String, TextEditingController> _fields = {};
  late OfflinePaymentMethod _method = widget.methods.first;

  @override
  void dispose() {
    _note.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(OfflinePaymentField field) =>
      _fields.putIfAbsent('${_method.id}:${field.key}', TextEditingController.new);

  String? _validate(OfflinePaymentField field, String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) {
      return field.required ? '${field.label} is required' : null;
    }
    if (field.type == 'number' && !RegExp(r'^\d+$').hasMatch(value)) {
      return '${field.label} must contain digits only';
    }
    if (field.type == 'email' &&
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Haptics.light();
    final values = <String, String>{};
    for (final field in _method.fields) {
      final value = _controllerFor(field).text.trim();
      // Numbers go as strings so leading zeros survive.
      if (value.isNotEmpty) values[field.key] = value;
    }
    final note = _note.text.trim();
    Navigator.of(context).pop(<String, dynamic>{
      'methodId': _method.id,
      'fields': values,
      if (note.isNotEmpty) 'note': note,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final fieldFill = isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight;

    InputDecoration decoration(String label, String hint) => InputDecoration(
          labelText: label,
          hintText: hint.isEmpty ? null : hint,
          filled: true,
          fillColor: fieldFill,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: secondaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Offline payment',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pay ₹${widget.amount.toStringAsFixed(2)} using the details below, then '
                    'enter your payment details. We confirm your order once the payment is verified.',
                    style: TextStyle(fontSize: 12.5, color: secondaryColor, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  if (widget.methods.length > 1) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in widget.methods)
                          ChoiceChip(
                            label: Text(m.name),
                            selected: m.id == _method.id,
                            selectedColor: AppColors.primary.withValues(alpha: 0.15),
                            onSelected: (_) => setState(() => _method = m),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_method.paymentInfo.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _method.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          for (final info in _method.paymentInfo)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      info.label,
                                      style: TextStyle(fontSize: 12.5, color: secondaryColor),
                                    ),
                                  ),
                                  Flexible(
                                    flex: 2,
                                    child: SelectableText(
                                      info.value,
                                      textAlign: TextAlign.end,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                  if (info.value.isNotEmpty)
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: info.value));
                                        AppSnackbar.info(context, '${info.label} copied');
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 8),
                                        child: Icon(
                                          Icons.copy_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  for (final field in _method.fields) ...[
                    TextFormField(
                      key: ValueKey('${_method.id}:${field.key}'),
                      controller: _controllerFor(field),
                      keyboardType: switch (field.type) {
                        'number' => TextInputType.number,
                        'email' => TextInputType.emailAddress,
                        _ => TextInputType.text,
                      },
                      inputFormatters: field.type == 'number'
                          ? [FilteringTextInputFormatter.digitsOnly]
                          : null,
                      style: TextStyle(color: textColor),
                      decoration: decoration(
                        field.required ? '${field.label} *' : field.label,
                        field.placeholder,
                      ),
                      validator: (v) => _validate(field, v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _note,
                    maxLength: 300,
                    maxLines: 2,
                    style: TextStyle(color: textColor),
                    decoration: decoration('Note (optional)', ''),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      onPressed: _submit,
                      child: const Text(
                        'PLACE ORDER',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
