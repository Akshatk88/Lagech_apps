import 'business_settings_model.dart';

/// What checkout may offer for one restaurant, from
/// `GET /food/public/restaurants/:restaurantId/order-options`: delivery and/or
/// takeaway, scheduled-order slots, rider tips and the restaurant's extra
/// packaging.
///
/// [RestaurantOrderOptions.deliveryOnly] is the app's behaviour from before
/// these options existed — used whenever the call fails.
class RestaurantOrderOptions {
  const RestaurantOrderOptions({
    this.restaurantId = '',
    this.delivery = true,
    this.takeaway = false,
    this.schedule = ScheduleOptions.off,
    this.tips = TipSettings.off,
    this.extraPackaging,
  });

  static const deliveryOnly = RestaurantOrderOptions();

  final String restaurantId;

  /// `orderTypes.delivery` / `orderTypes.takeaway`.
  final bool delivery;
  final bool takeaway;

  final ScheduleOptions schedule;
  final TipSettings tips;

  /// The restaurant's extra packaging charge; null when not offered.
  final ExtraPackagingOption? extraPackaging;

  /// Extra packaging the customer may tick at checkout (not always charged).
  bool get offersOptionalPackaging =>
      extraPackaging != null && !extraPackaging!.required;

  /// Both order types are open, so the customer gets a choice.
  bool get offersChoice => delivery && takeaway;

  /// Only takeaway is open: it is preselected and there is nothing to choose.
  bool get takeawayOnly => takeaway && !delivery;

  factory RestaurantOrderOptions.fromApi(Map<String, dynamic> json) {
    final types = (json['orderTypes'] as Map?)?.cast<String, dynamic>() ?? const {};
    final schedule = json['schedule'];
    final tips = json['tips'];
    final packaging = json['extraPackaging'];
    return RestaurantOrderOptions(
      restaurantId: (json['restaurantId'] ?? '').toString(),
      delivery: types['delivery'] is bool ? types['delivery'] as bool : true,
      takeaway: types['takeaway'] == true,
      schedule: schedule is Map
          ? ScheduleOptions.fromApi(schedule.cast<String, dynamic>())
          : ScheduleOptions.off,
      tips: tips is Map
          ? TipSettings.fromApi(tips.cast<String, dynamic>())
          : TipSettings.off,
      extraPackaging: packaging is Map
          ? ExtraPackagingOption.fromApi(packaging.cast<String, dynamic>())
          : null,
    );
  }
}

/// `extraPackaging: { amount, required }` from the order options.
class ExtraPackagingOption {
  const ExtraPackagingOption({required this.amount, required this.required});

  /// Rupees.
  final double amount;

  /// Charged on every order; otherwise only when the customer asks for it.
  final bool required;

  /// Null when there is no amount to charge.
  static ExtraPackagingOption? fromApi(Map<String, dynamic> json) {
    final amount = (json['amount'] as num?)?.toDouble() ?? 0;
    if (amount <= 0) return null;
    return ExtraPackagingOption(
      amount: amount,
      required: json['required'] == true,
    );
  }
}

/// Scheduled-order slots the restaurant can take.
class ScheduleOptions {
  const ScheduleOptions({
    this.enabled = false,
    this.slotMinutes = 0,
    this.minLeadMinutes = 0,
    this.days = const [],
  });

  static const off = ScheduleOptions();

  final bool enabled;
  final int slotMinutes;
  final int minLeadMinutes;
  final List<ScheduleDay> days;

  /// Switched on and at least one slot left to pick.
  bool get hasSlots => enabled && days.any((d) => d.slots.isNotEmpty);

  /// Whether [at] is still one of the offered slots.
  bool offers(DateTime at) =>
      days.any((d) => d.slots.any((s) => s.scheduledAt.isAtSameMomentAs(at)));

  factory ScheduleOptions.fromApi(Map<String, dynamic> json) {
    return ScheduleOptions(
      enabled: json['enabled'] == true,
      slotMinutes: (json['slotMinutes'] as num?)?.toInt() ?? 0,
      minLeadMinutes: (json['minLeadMinutes'] as num?)?.toInt() ?? 0,
      days: ((json['days'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ScheduleDay.fromApi(e.cast<String, dynamic>()))
          .where((d) => d.slots.isNotEmpty)
          .toList(),
    );
  }
}

/// One day of slots: "Today" / "Tomorrow".
class ScheduleDay {
  const ScheduleDay({
    required this.date,
    required this.label,
    required this.dayName,
    required this.slots,
  });

  /// `2026-10-06`.
  final String date;

  /// "Today" or "Tomorrow".
  final String label;

  /// "Tue, 6 Oct".
  final String dayName;
  final List<ScheduleSlot> slots;

  factory ScheduleDay.fromApi(Map<String, dynamic> json) {
    return ScheduleDay(
      date: (json['date'] ?? '').toString(),
      label: (json['label'] ?? json['dayName'] ?? '').toString(),
      dayName: (json['dayName'] ?? '').toString(),
      slots: ((json['slots'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ScheduleSlot.fromApi(e.cast<String, dynamic>()))
          .whereType<ScheduleSlot>()
          .toList(),
    );
  }
}

/// A pickable delivery window, e.g. "1:00 pm - 1:30 pm".
class ScheduleSlot {
  const ScheduleSlot({
    required this.scheduledAt,
    this.endsAt,
    required this.label,
  });

  final DateTime scheduledAt;
  final DateTime? endsAt;
  final String label;

  /// Null when the server sent no usable start time.
  static ScheduleSlot? fromApi(Map<String, dynamic> json) {
    final at = DateTime.tryParse((json['scheduledAt'] ?? '').toString());
    if (at == null) return null;
    return ScheduleSlot(
      scheduledAt: at,
      endsAt: DateTime.tryParse((json['endsAt'] ?? '').toString()),
      label: (json['label'] ?? '').toString(),
    );
  }
}
