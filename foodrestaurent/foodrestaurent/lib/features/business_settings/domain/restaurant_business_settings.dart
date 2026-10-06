/// The `restaurant` block of the admin's Business Settings, published at
/// `GET /food/public/business-settings`.
class RestaurantBusinessSettings {
  const RestaurantBusinessSettings({
    required this.canCancelOrder,
    required this.dishApprovalRequired,
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
    return RestaurantBusinessSettings(
      canCancelOrder: flag('canCancelOrder', fallback.canCancelOrder),
      dishApprovalRequired: flag(
        'dishApprovalRequired',
        fallback.dishApprovalRequired,
      ),
    );
  }

  /// Whether the restaurant may cancel an order it has already accepted.
  /// Rejecting a new (`created`) order is always allowed.
  final bool canCancelOrder;

  /// Whether new or edited dishes wait for admin approval before going live.
  final bool dishApprovalRequired;
}
