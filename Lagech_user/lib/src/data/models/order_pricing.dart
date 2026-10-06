import 'business_settings_model.dart';

/// Server-computed bill from `POST /food/orders/calculate`.
///
/// Pricing is server-owned: never compute or adjust these numbers client-side.
/// The same object is echoed straight back into `POST /food/orders`.
class OrderPricing {
  final double subtotal;
  final double tax;
  final double packagingFee;
  final double deliveryFee;
  final double deliveryFeeGst;
  final double platformFee;
  final double quickDeliveryFee;
  final double discount;
  final double total;

  /// Percentages behind [tax] and [deliveryFeeGst], for labelling bill rows.
  /// 0 when the server did not send them (older backend).
  final double gstRate;
  final double deliveryFeeGstRate;
  final String currency;
  final String deliveryMode;
  final String? couponCode;

  /// Null when a coupon was rejected — `couponCode` is echoed back either way,
  /// so this is the only reliable "did the discount land" signal.
  final Map<String, dynamic>? appliedCoupon;

  final double? roadDistanceKm;

  /// Delivery fee before any waiver (0 when the server did not send it).
  final double originalDeliveryFee;

  /// Delivery fee + GST waived by a free-delivery coupon.
  final double deliveryFeeWaived;

  /// Delivery fee + GST waived because the item total reached
  /// [freeDeliveryOver] ("Free delivery over ₹X").
  final double freeDeliveryWaived;

  /// The admin's "free delivery over" threshold, or null when it is off.
  final double? freeDeliveryOver;

  /// The part of [discount] that is the first-order discount for new customers.
  final double newCustomerDiscount;

  /// The part of [discount] that food campaign dishes took off their price.
  final double campaignDiscount;

  /// Why the coupon that was sent did not apply, worded for the customer.
  final String? couponError;

  /// Tip for the delivery partner, already included in [total].
  final double riderTip;

  /// `delivery` or `takeaway`, as the server priced it.
  final String orderType;

  /// The admin's flat charge on every order (e.g. "Service charge"). Already
  /// included in [platformFee] and [total]; 0 when off.
  final double additionalCharge;

  /// What to call [additionalCharge] on the bill.
  final String additionalChargeName;

  /// Verbatim server payload, echoed into order creation unchanged.
  final Map<String, dynamic> raw;

  const OrderPricing({
    required this.subtotal,
    required this.tax,
    required this.packagingFee,
    required this.deliveryFee,
    required this.deliveryFeeGst,
    required this.platformFee,
    required this.quickDeliveryFee,
    required this.discount,
    required this.total,
    this.gstRate = 0,
    this.deliveryFeeGstRate = 0,
    required this.currency,
    required this.deliveryMode,
    this.couponCode,
    this.appliedCoupon,
    this.roadDistanceKm,
    this.originalDeliveryFee = 0,
    this.deliveryFeeWaived = 0,
    this.freeDeliveryWaived = 0,
    this.freeDeliveryOver,
    this.newCustomerDiscount = 0,
    this.campaignDiscount = 0,
    this.couponError,
    this.riderTip = 0,
    this.orderType = 'delivery',
    this.additionalCharge = 0,
    this.additionalChargeName = '',
    this.raw = const {},
  });

  /// [platformFee] without the additional charge, which gets its own line, so
  /// nothing is counted twice. The Quick Mode surcharge ([quickDeliveryFee])
  /// has no line of its own in this app, so it stays in here as before.
  double get platformFeeOnly =>
      (platformFee - additionalCharge).clamp(0, double.infinity).toDouble();

  /// The bill line label for [additionalCharge].
  String get additionalChargeLabel =>
      additionalChargeName.isNotEmpty ? additionalChargeName : 'Additional charge';

  /// Any delivery fee taken off, by a coupon or by "free delivery over".
  bool get deliveryWaived => deliveryFeeWaived > 0 || freeDeliveryWaived > 0;

  /// [discount] without the new-customer and campaign parts — what the
  /// coupon/offer gave.
  double get discountExcludingNewCustomer =>
      (discount - newCustomerDiscount - campaignDiscount).clamp(0, double.infinity).toDouble();

  /// What a coupon saved in all: its discount plus any delivery fee it waived.
  /// Read from `appliedCoupon.savings` when the server sends it.
  double get couponSavings {
    final s = appliedCoupon?['savings'];
    if (s is num) return s.toDouble();
    return discountExcludingNewCustomer + deliveryFeeWaived;
  }

  /// True once a coupon actually landed — checked against `discount`/
  /// `couponCode` too, not just `appliedCoupon`, since a backend that omits
  /// the nested `appliedCoupon` object but still returns a real `discount`
  /// and `couponCode` should still read as "applied" rather than silently
  /// showing no discount.
  ///
  /// A `couponError` means the code was refused, and the new-customer discount
  /// is part of `discount` without being a coupon, so neither counts here.
  bool get hasCouponApplied =>
      appliedCoupon != null ||
      ((couponCode?.isNotEmpty ?? false) &&
          couponError == null &&
          discountExcludingNewCustomer > 0);

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  factory OrderPricing.fromApi(Map<String, dynamic> json) {
    final appliedCoupon = (json['appliedCoupon'] as Map?)?.cast<String, dynamic>();
    return OrderPricing(
      subtotal: _d(json['subtotal']),
      tax: _d(json['tax']),
      packagingFee: _d(json['packagingFee']),
      deliveryFee: _d(json['deliveryFee']),
      deliveryFeeGst: _d(json['deliveryFeeGst']),
      platformFee: _d(json['platformFee']),
      quickDeliveryFee: _d(json['quickDeliveryFee']),
      // Same discount, different key across backend responses — mirrors the
      // fallback chain OrderModel already uses for a placed order's pricing.
      discount: _d(
        json['discount'] ?? json['discountAmount'] ?? json['couponDiscount'],
      ),
      total: _d(json['total'] ?? json['finalAmount'] ?? json['totalPayable']),
      gstRate: _d(json['gstRate']),
      deliveryFeeGstRate: _d(json['deliveryFeeGstRate']),
      currency: (json['currency'] ?? 'INR').toString(),
      deliveryMode: (json['deliveryMode'] ?? 'basic').toString(),
      couponCode: (json['couponCode'] ?? appliedCoupon?['code'])?.toString(),
      appliedCoupon: appliedCoupon,
      roadDistanceKm: (json['roadDistanceKm'] as num?)?.toDouble(),
      originalDeliveryFee: _d(json['originalDeliveryFee']),
      deliveryFeeWaived: _d(json['deliveryFeeWaived']),
      freeDeliveryWaived: _d(json['freeDeliveryWaived']),
      freeDeliveryOver: (json['freeDeliveryOver'] as num?)?.toDouble(),
      newCustomerDiscount: _d(json['newCustomerDiscount']),
      campaignDiscount: _d(json['campaignDiscount']),
      couponError: (json['couponError'] as String?)?.trim().isNotEmpty == true
          ? (json['couponError'] as String).trim()
          : null,
      riderTip: _d(json['riderTip']),
      orderType: (json['orderType'] ?? 'delivery').toString(),
      additionalCharge: _d(json['additionalCharge']),
      additionalChargeName:
          (json['additionalChargeName'] ?? '').toString().trim(),
      raw: json,
    );
  }
}

/// A menu price that moved between adding to cart and checking out.
///
/// Non-empty `priceChanges` must be confirmed by the user before the order is
/// submitted — that is the entire reason the backend returns it.
class PriceChange {
  final String itemId;
  final String name;
  final double previousPrice;
  final double price;

  const PriceChange({
    required this.itemId,
    required this.name,
    required this.previousPrice,
    required this.price,
  });

  factory PriceChange.fromApi(Map<String, dynamic> json) {
    return PriceChange(
      itemId: (json['itemId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      previousPrice: (json['previousPrice'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Full `/calculate` result: authoritative items, price drift, and the bill.
class OrderCalculation {
  final List<Map<String, dynamic>> items;
  final List<PriceChange> priceChanges;
  final OrderPricing pricing;

  /// Which methods the order's zone accepts; null from an older backend.
  final ZonePaymentOptions? paymentOptions;

  const OrderCalculation({
    required this.items,
    required this.priceChanges,
    required this.pricing,
    this.paymentOptions,
  });

  OrderCalculation withPaymentOptions(ZonePaymentOptions options) =>
      OrderCalculation(
        items: items,
        priceChanges: priceChanges,
        pricing: pricing,
        paymentOptions: options,
      );

  bool get hasPriceChanges => priceChanges.isNotEmpty;

  factory OrderCalculation.fromApi(Map<String, dynamic> json) {
    return OrderCalculation(
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList(),
      priceChanges: ((json['priceChanges'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => PriceChange.fromApi(e.cast<String, dynamic>()))
          .toList(),
      pricing: OrderPricing.fromApi(
        ((json['pricing'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
      paymentOptions: json['paymentOptions'] is Map
          ? ZonePaymentOptions.fromApi(
              (json['paymentOptions'] as Map).cast<String, dynamic>(),
            )
          : null,
    );
  }
}
