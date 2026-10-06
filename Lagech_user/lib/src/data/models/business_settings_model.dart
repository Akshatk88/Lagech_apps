/// What the admin set under Business Settings that changes what the app shows,
/// from `GET /food/public/business-settings`.
///
/// The server enforces every switch whatever the app shows, so these only
/// decide what is offered. [BusinessSettings.fallback] is the app's behaviour
/// from before these settings existed: when the call fails nothing is hidden
/// or blocked, and the server's own 400 still explains a refusal.
class BusinessSettings {
  const BusinessSettings({
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.codEnabled = true,
    this.digitalEnabled = true,
    this.offlineEnabled = false,
    this.walletPaymentEnabled = true,
    this.partialPaymentEnabled = false,
    this.partialPaymentMethod = 'both',
    this.scheduledOrder = true,
    this.freeDeliveryOver,
    this.addFund = true,
    this.vegNonVegToggle = true,
    this.newCustomerDiscount,
  });

  /// Defaults used until (or unless) the settings load.
  static const fallback = BusinessSettings();

  final bool maintenanceMode;
  final String maintenanceMessage;

  /// `payment.cod` — Cash on Delivery (`cash`).
  final bool codEnabled;

  /// `payment.digital` — Razorpay / card / UPI QR.
  final bool digitalEnabled;

  /// `payment.offline` — the server only reports it on when at least one
  /// offline method is active.
  final bool offlineEnabled;

  /// `payment.wallet` — paying for an order from the wallet.
  final bool walletPaymentEnabled;

  /// `payment.partialPayment` — paying part of an order from the wallet and
  /// the rest online or in cash. Off unless the server says so.
  final bool partialPaymentEnabled;

  /// `payment.partialPaymentMethod` — what may pay the rest of a partial
  /// payment: `both`, `cod` (cash only) or `digital` (online only).
  final String partialPaymentMethod;

  /// Whether [method] (`razorpay` or `cash`) may pay the rest of a partial
  /// payment, by this setting alone (the method's own switches still apply).
  bool partialRestAllows(String method) => switch (method) {
        'razorpay' => partialPaymentMethod != 'cod',
        'cash' => partialPaymentMethod != 'digital',
        _ => false,
      };

  /// `order.scheduledOrder` — off means "order for now" only.
  final bool scheduledOrder;

  /// `order.freeDeliveryOver` — item total from which delivery is free, or null.
  final double? freeDeliveryOver;

  /// `customer.addFund` — whether "Add money" is offered in the wallet.
  final bool addFund;

  /// `customer.vegNonVegToggle` — whether the Veg Mode switch is offered.
  final bool vegNonVegToggle;

  /// `customer.newCustomerDiscount`, or null when switched off.
  final NewCustomerDiscountInfo? newCustomerDiscount;

  /// The message to show while checkout is closed for maintenance.
  String get maintenanceText => maintenanceMessage.trim().isNotEmpty
      ? maintenanceMessage.trim()
      : 'We are under maintenance right now. Ordering will be back shortly.';

  static bool _bool(dynamic v, bool fallback) => v is bool ? v : fallback;

  factory BusinessSettings.fromApi(Map<String, dynamic> json) {
    Map<String, dynamic> section(String key) =>
        (json[key] as Map?)?.cast<String, dynamic>() ?? const {};
    final maintenance = section('maintenance');
    final payment = section('payment');
    final order = section('order');
    final customer = section('customer');
    final nc = customer['newCustomerDiscount'];

    return BusinessSettings(
      maintenanceMode: _bool(maintenance['maintenanceMode'], false),
      maintenanceMessage: (maintenance['maintenanceMessage'] ?? '').toString(),
      codEnabled: _bool(payment['cod'], true),
      digitalEnabled: _bool(payment['digital'], true),
      offlineEnabled: _bool(payment['offline'], false),
      walletPaymentEnabled: _bool(payment['wallet'], true),
      partialPaymentEnabled: _bool(payment['partialPayment'], false),
      partialPaymentMethod: switch (payment['partialPaymentMethod']) {
        'cod' => 'cod',
        'digital' => 'digital',
        _ => 'both',
      },
      scheduledOrder: _bool(order['scheduledOrder'], true),
      freeDeliveryOver: (order['freeDeliveryOver'] as num?)?.toDouble(),
      addFund: _bool(customer['addFund'], true),
      vegNonVegToggle: _bool(customer['vegNonVegToggle'], true),
      newCustomerDiscount: nc is Map
          ? NewCustomerDiscountInfo.fromApi(nc.cast<String, dynamic>())
          : null,
    );
  }
}

/// The first-order discount for new customers, as the admin configured it.
class NewCustomerDiscountInfo {
  const NewCustomerDiscountInfo({
    required this.type,
    required this.value,
    this.maxDiscount,
    this.minOrderAmount = 0,
    this.validityDays = 0,
  });

  /// `amount` or `percent`.
  final String type;
  final double value;
  final double? maxDiscount;
  final double minOrderAmount;
  final int validityDays;

  /// e.g. "20% off your first order (up to ₹100) on orders above ₹199".
  String get headline {
    final off = type == 'percent'
        ? '${_fmt(value)}% off'
        : '₹${_fmt(value)} off';
    final cap = type == 'percent' && (maxDiscount ?? 0) > 0
        ? ' (up to ₹${_fmt(maxDiscount!)})'
        : '';
    final min = minOrderAmount > 0 ? ' on orders above ₹${_fmt(minOrderAmount)}' : '';
    return '$off your first order$cap$min';
  }

  static String _fmt(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  factory NewCustomerDiscountInfo.fromApi(Map<String, dynamic> json) {
    return NewCustomerDiscountInfo(
      type: (json['type'] ?? 'amount').toString(),
      value: (json['value'] as num?)?.toDouble() ?? 0,
      maxDiscount: (json['maxDiscount'] as num?)?.toDouble(),
      minOrderAmount: (json['minOrderAmount'] as num?)?.toDouble() ?? 0,
      validityDays: (json['validityDays'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Which payment methods the order's zone accepts — `data.paymentOptions` from
/// `POST /orders/calculate`, or `GET /zones/payment-options`. A missing zone
/// accepts everything, as every order did before the per-zone switches.
class ZonePaymentOptions {
  const ZonePaymentOptions({
    this.zoneId,
    this.cashOnDelivery = true,
    this.digitalPayment = true,
    this.wallet = true,
  });

  final String? zoneId;
  final bool cashOnDelivery;
  final bool digitalPayment;
  final bool wallet;

  factory ZonePaymentOptions.fromApi(Map<String, dynamic> json) {
    return ZonePaymentOptions(
      zoneId: json['zoneId']?.toString(),
      cashOnDelivery: json['cashOnDelivery'] is bool ? json['cashOnDelivery'] as bool : true,
      digitalPayment: json['digitalPayment'] is bool ? json['digitalPayment'] as bool : true,
      wallet: json['wallet'] is bool ? json['wallet'] as bool : true,
    );
  }
}

/// An admin-defined offline payment method (bank transfer, UPI, ...) from
/// `GET /food/public/offline-payment-methods`.
class OfflinePaymentMethod {
  const OfflinePaymentMethod({
    required this.id,
    required this.name,
    this.paymentInfo = const [],
    this.fields = const [],
  });

  final String id;
  final String name;

  /// Where to send the money: label / value pairs shown to the customer.
  final List<({String label, String value})> paymentInfo;

  /// What the customer fills in after paying.
  final List<OfflinePaymentField> fields;

  factory OfflinePaymentMethod.fromApi(Map<String, dynamic> json) {
    return OfflinePaymentMethod(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      paymentInfo: ((json['paymentInfo'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => (
                label: (e['label'] ?? '').toString(),
                value: (e['value'] ?? '').toString(),
              ))
          .where((e) => e.label.isNotEmpty || e.value.isNotEmpty)
          .toList(),
      fields: ((json['fields'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OfflinePaymentField.fromApi(e.cast<String, dynamic>()))
          .where((f) => f.key.isNotEmpty)
          .toList(),
    );
  }
}

class OfflinePaymentField {
  const OfflinePaymentField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = false,
    this.placeholder = '',
  });

  final String key;
  final String label;

  /// `text`, `number` or `email`.
  final String type;
  final bool required;
  final String placeholder;

  factory OfflinePaymentField.fromApi(Map<String, dynamic> json) {
    return OfflinePaymentField(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? json['key'] ?? '').toString(),
      type: (json['type'] ?? 'text').toString(),
      required: json['required'] == true,
      placeholder: (json['placeholder'] ?? '').toString(),
    );
  }
}
