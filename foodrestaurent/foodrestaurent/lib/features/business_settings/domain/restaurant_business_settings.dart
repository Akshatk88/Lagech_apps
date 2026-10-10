/// What the restaurant app reads from the admin's Business Settings, published
/// at `GET /food/public/business-settings` (mostly the `restaurant` block).
class RestaurantBusinessSettings {
  const RestaurantBusinessSettings({
    required this.canCancelOrder,
    required this.dishApprovalRequired,
    this.takeawayAvailable = false,
    this.extraPackagingAvailable = false,
    this.confirmedByDeliveryman = false,
    this.subscriptionModel = true,
    this.selfRegistration = true,
    this.otpProvider = 'firebase',
  });

  /// Used until the settings load, and whenever they can't be fetched. Both
  /// match the server's own defaults and what the app did before it read
  /// these settings: no cancelling an accepted order, and dishes go through
  /// admin approval.
  static const fallback = RestaurantBusinessSettings(
    canCancelOrder: false,
    dishApprovalRequired: true,
  );

  factory RestaurantBusinessSettings.fromJson(Map<String, dynamic> json) {
    final restaurant = json['restaurant'] is Map
        ? Map<String, dynamic>.from(json['restaurant'] as Map)
        : const <String, dynamic>{};
    bool flag(String key, bool orElse) =>
        restaurant[key] is bool ? restaurant[key] as bool : orElse;
    final order = json['order'] is Map
        ? Map<String, dynamic>.from(json['order'] as Map)
        : const <String, dynamic>{};
    final business = json['business'] is Map
        ? Map<String, dynamic>.from(json['business'] as Map)
        : const <String, dynamic>{};
    return RestaurantBusinessSettings(
      canCancelOrder: flag('canCancelOrder', fallback.canCancelOrder),
      dishApprovalRequired: flag(
        'dishApprovalRequired',
        fallback.dishApprovalRequired,
      ),
      takeawayAvailable: order['takeaway'] == true,
      extraPackagingAvailable: order['extraPackagingCharge'] == true,
      confirmedByDeliveryman: order['confirmedBy'] == 'deliveryman',
      subscriptionModel: business['subscriptionModel'] is bool
          ? business['subscriptionModel'] as bool
          : fallback.subscriptionModel,
      selfRegistration: flag('selfRegistration', fallback.selfRegistration),
      otpProvider: json['login'] is Map &&
              (json['login'] as Map)['otpProvider'] == 'sms'
          ? 'sms'
          : 'firebase',
    );
  }

  /// Whether the restaurant may cancel an order it has already accepted.
  /// Rejecting a new (`created`) order is always allowed.
  final bool canCancelOrder;

  /// Whether new or edited dishes wait for admin approval before going live.
  final bool dishApprovalRequired;

  /// `order.takeaway` — the platform offers takeaway orders at all. Only then
  /// does a restaurant see its own "Takeaway orders" switch.
  final bool takeawayAvailable;

  /// `order.extraPackagingCharge` — restaurants may set their own extra
  /// packaging charge. Only then is the "Packaging charge" setting shown.
  final bool extraPackagingAvailable;

  /// `order.confirmedBy == "deliveryman"` — delivery orders arrive already
  /// `confirmed` (no accept step, no acceptance timer). Takeaway orders are
  /// still accepted by the restaurant.
  final bool confirmedByDeliveryman;

  /// `business.subscriptionModel` — the subscription plans exist at all. When
  /// false the subscription screens are hidden.
  final bool subscriptionModel;

  /// `restaurant.selfRegistration` — new restaurants may sign up from the app.
  final bool selfRegistration;

  /// `login.otpProvider` — `firebase` (Firebase Phone Authentication, the
  /// default, also when the server does not say) or `sms` (our SMS OTP).
  final String otpProvider;

  bool get useFirebaseOtp => otpProvider != 'sms';
}
