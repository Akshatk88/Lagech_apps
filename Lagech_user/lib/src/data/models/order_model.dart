import '../../core/config/api_config.dart';

/// Parses a money value from the API.
double _money(Object? value) {
  if (value is num) return value.toDouble();
  if (value == null) return 0.0;
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Parses an integer value from the API safely.
int _intVal(Object? value, [int fallback = 0]) {
  if (value is num) return value.toInt();
  if (value == null) return fallback;
  return int.tryParse(value.toString()) ?? fallback;
}

/// One line item on a placed order.
class OrderItem {
  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String imageUrl;
  final bool isVeg;
  final List<String> variants;
  final List<String> addons;
  final String cookingInstructions;
  final String specialNotes;

  const OrderItem({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
    this.isVeg = false,
    this.variants = const [],
    this.addons = const [],
    this.cookingInstructions = '',
    this.specialNotes = '',
  });

  /// This line's contribution to the bill — never re-derive `price * quantity`
  /// at call sites, so every screen agrees on the same number.
  double get lineTotal => price * quantity;

  /// A variant/add-on list entry as either a bare name string or `{name,
  /// price, ...}` — never `.toString()` a raw Map, which renders as
  /// "Instance of 'Map'"/`{name: ..., price: ...}` garbage in the UI.
  static String _optionName(Object? entry) {
    if (entry is Map) return (entry['name'] ?? entry['title'] ?? '').toString();
    return entry.toString();
  }

  factory OrderItem.fromApi(Map<String, dynamic> json) {
    return OrderItem(
      itemId: (json['itemId'] ?? json['_id'] ?? json['id'] ?? json['foodId'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      price: _money(json['price'] ?? json['unitPrice']),
      quantity: _intVal(json['quantity'] ?? json['qty'], 1),
      imageUrl: ApiConfig.resolveMedia(
        json['image'] is String
            ? json['image'] as String
            : (json['image'] is Map
                ? (json['image']['url'] ?? json['image']['imageUrl'])?.toString()
                : (json['imageUrl'] ?? json['foodImage'])?.toString()),
      ),
      isVeg: json['isVeg'] == true ||
          (json['isVeg']?.toString().toLowerCase() == 'true') ||
          (json['foodType']?.toString().toLowerCase() == 'veg'),
      variants:
          ((json['variants'] ?? json['selectedVariants']) as List?)
              ?.map(_optionName)
              .where((n) => n.isNotEmpty)
              .toList() ??
          const [],
      addons:
          ((json['addons'] ?? json['selectedAddons']) as List?)
              ?.map(_optionName)
              .where((n) => n.isNotEmpty)
              .toList() ??
          const [],
      cookingInstructions: (json['cookingInstructions'] ?? '').toString(),
      specialNotes: (json['specialNotes'] ?? '').toString(),
    );
  }
}

/// One entry of the order's audit trail.
class OrderStatusEvent {
  final DateTime? at;
  final String byRole;
  final String from;
  final String to;
  final String note;

  const OrderStatusEvent({
    this.at,
    this.byRole = '',
    this.from = '',
    this.to = '',
    this.note = '',
  });

  factory OrderStatusEvent.fromApi(Map<String, dynamic> json) {
    final raw = json['at']?.toString();
    return OrderStatusEvent(
      at: raw == null ? null : DateTime.tryParse(raw),
      byRole: (json['byRole'] ?? '').toString(),
      from: (json['from'] ?? '').toString(),
      to: (json['to'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
    );
  }
}

/// One stage in the dynamic order timeline the tracking screen renders.
class OrderStage {
  final String status;
  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final DateTime? at;

  const OrderStage({
    required this.status,
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    this.at,
  });

  bool get isReached => isCompleted || isCurrent;
}

/// `order.eta` from `GET /food/orders/:id` — recomputed server-side from the
/// rider's live position (distance-based, not a Directions call, so it's
/// cheap to poll/refresh on every read).
class OrderEta {
  final int? minutes;
  final double? distanceKm;

  /// `live` (from rider GPS) | `estimate` (no GPS yet) | `completed` | `unavailable`.
  final String source;

  /// `restaurant` — rider still collecting the food; `customer` — rider has
  /// it and is on the way to you.
  final String? target;

  const OrderEta({
    this.minutes,
    this.distanceKm,
    this.source = 'unavailable',
    this.target,
  });

  factory OrderEta.fromApi(Map<String, dynamic>? json) {
    if (json == null) return const OrderEta();
    return OrderEta(
      minutes: json['minutes'] != null ? _intVal(json['minutes']) : null,
      distanceKm: json['distanceKm'] != null ? _money(json['distanceKm']) : null,
      source: (json['source'] ?? 'unavailable').toString(),
      target: json['target']?.toString(),
    );
  }
}

/// The rider assigned to an order.
class DeliveryPartner {
  final String id;
  final String name;
  final String phone;
  final double rating;

  /// Absolute photo URL. The single-order read populates `profileImage`/`avatar`
  /// on the rider; the list read does not, so this can be empty.
  final String photoUrl;

  /// Aggregate ratings count — the only "experience" figure the backend
  /// exposes (there is no total-deliveries field).
  final int totalRatings;

  /// Vehicle fields. Not yet populated by the order read (BACKEND_CHANGES
  /// P1.1) — empty until the backend selects them, so the UI shows a
  /// "Backend implementation pending" badge instead of a blank row.
  final String vehicleType;
  final String vehicleNumber;

  const DeliveryPartner({
    required this.id,
    required this.name,
    required this.phone,
    this.rating = 0,
    this.photoUrl = '',
    this.totalRatings = 0,
    this.vehicleType = '',
    this.vehicleNumber = '',
  });

  bool get hasPhone => phone.trim().isNotEmpty;
  bool get hasVehicleInfo =>
      vehicleType.trim().isNotEmpty || vehicleNumber.trim().isNotEmpty;

  factory DeliveryPartner.fromApi(Map<String, dynamic> json) {
    final image =
        json['profileImage'] ?? json['profilePhoto'] ?? json['avatar'];
    final imageUrl = image is Map
        ? (image['url'] ?? image['imageUrl'])?.toString()
        : image?.toString();
    return DeliveryPartner(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? json['fullName'] ?? '').toString(),
      phone: (json['phone'] ?? json['phoneNumber'] ?? '').toString(),
      rating: _money(json['rating']),
      photoUrl: ApiConfig.resolveMedia(imageUrl),
      totalRatings: _intVal(json['totalRatings']),
      vehicleType: (json['vehicleType'] ?? json['vehicleName'] ?? '')
          .toString(),
      vehicleNumber: (json['vehicleNumber'] ?? '').toString(),
    );
  }
}

/// A placed order, normalized from every `/food/orders` endpoint.
///
/// Three independent status axes exist and answer different questions:
///  * [orderStatus]   — the order's lifecycle (drives the stepper)
///  * [currentPhase]  — the rider's leg (drives map copy)
///  * [dispatchStatus] — whether a rider is assigned at all
class OrderModel {
  final String id;
  final String orderNumber;
  final String orderStatus;
  final String currentPhase;
  final String dispatchStatus;

  final String restaurantId;
  final String restaurantName;
  final String restaurantImage;
  final String restaurantAddress;
  final double restaurantRating;
  final bool restaurantIsOpen;
  final bool restaurantIsVerified;

  final List<OrderItem> items;
  final double total;
  final double itemTotal;
  final double addonTotal;
  final double packingCharge;
  final double platformFee;
  final double deliveryCharge;
  final double taxes;
  final double itemTax;
  final double deliveryFeeGst;
  final double gstRate;
  final double deliveryFeeGstRate;
  final double couponDiscount;
  final double walletUsed;
  final double rewardDiscount;
  final double driverTip;
  final String currency;

  final String paymentMethod;
  final String paymentStatus;
  final String refundStatus;
  final String transactionId;
  final DateTime? paymentTime;
  final double refundAmount;

  final DeliveryPartner? deliveryPartner;
  final double? riderLat;
  final double? riderLng;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? dropLat;
  final double? dropLng;

  final double? roadDistanceKm;
  final int? roadDurationMins;
  final OrderEta eta;

  final bool dropOtpRequired;
  final bool dropOtpVerified;

  final List<OrderStatusEvent> statusHistory;
  final String cancellationReason;
  final String cancelledBy;

  final DateTime? createdAt;
  final DateTime? deliveredAt;

  /// When the restaurant's acceptance window closes — the only backend signal
  /// for "estimated confirmation time" while the order sits in `created`.
  final DateTime? acceptanceDeadlineAt;

  final String deliveryAddress;
  final String customerName;
  final String customerPhone;
  final String landmark;

  /// The cooking request the customer sent with the order, if any. Stored by
  /// the backend as `note` on the order itself — not to be confused with
  /// [OrderStatusEvent.note], which annotates a timeline entry.
  final String note;

  final double foodRating;
  final double deliveryRating;
  final String foodRatingComment;
  final String deliveryRatingComment;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.orderStatus,
    this.currentPhase = '',
    this.dispatchStatus = '',
    this.restaurantId = '',
    this.restaurantName = '',
    this.restaurantImage = '',
    this.restaurantAddress = '',
    this.restaurantRating = 0.0,
    this.restaurantIsOpen = false,
    this.restaurantIsVerified = false,
    this.items = const [],
    this.total = 0,
    this.itemTotal = 0,
    this.addonTotal = 0,
    this.packingCharge = 0,
    this.platformFee = 0,
    this.deliveryCharge = 0,
    this.taxes = 0,
    this.itemTax = 0,
    this.deliveryFeeGst = 0,
    this.gstRate = 5.0,
    this.deliveryFeeGstRate = 18.0,
    this.couponDiscount = 0,
    this.walletUsed = 0,
    this.rewardDiscount = 0,
    this.driverTip = 0,
    this.currency = 'INR',
    this.paymentMethod = '',
    this.paymentStatus = '',
    this.refundStatus = 'none',
    this.transactionId = '',
    this.paymentTime,
    this.refundAmount = 0,
    this.deliveryPartner,
    this.riderLat,
    this.riderLng,
    this.restaurantLat,
    this.restaurantLng,
    this.dropLat,
    this.dropLng,
    this.roadDistanceKm,
    this.roadDurationMins,
    this.eta = const OrderEta(),
    this.dropOtpRequired = false,
    this.dropOtpVerified = false,
    this.statusHistory = const [],
    this.cancellationReason = '',
    this.cancelledBy = '',
    this.createdAt,
    this.deliveredAt,
    this.acceptanceDeadlineAt,
    this.deliveryAddress = '',
    this.customerName = '',
    this.customerPhone = '',
    this.landmark = '',
    this.note = '',
    this.foodRating = 0.0,
    this.deliveryRating = 0.0,
    this.foodRatingComment = '',
    this.deliveryRatingComment = '',
  });

  static const _activeStatuses = {
    'pending',
    'placed',
    'created',
    'waiting',
    'accepted',
    'confirmed',
    'preparing',
    'ready',
    'ready_for_pickup',
    'reached_pickup',
    'picked_up',
    'out_for_delivery',
    'en_route_to_delivery',
    'reached_drop',
    'at_drop',
    'arriving_soon',
    'pending_payment',
  };

  static const _terminal = {
    'delivered',
    'completed',
    'cancelled',
    'cancelled_by_user',
    'cancelled_by_restaurant',
    'cancelled_by_admin',
    'rejected',
    'failed',
    'expired',
  };

  /// A restaurant rating is required to submit, so its presence alone marks
  /// the order as rated — `PATCH .../ratings` rejects a second submission.
  bool get hasRated => foodRating > 0;

  /// The bill's "Item Total" row: the backend-computed subtotal, falling back
  /// to summing item lines only for the rare order predating that field.
  /// Single source of truth — every bill/summary screen reads this instead of
  /// re-deriving it.
  double get effectiveItemTotal => itemTotal > 0
      ? itemTotal
      : items.fold<double>(0, (sum, item) => sum + item.lineTotal);

  bool get isActive {
    final status = orderStatus.toLowerCase();
    if (_terminal.contains(status)) return false;
    if (_activeStatuses.contains(status)) return true;
    return status.isNotEmpty;
  }

  bool get isCancelled {
    final status = orderStatus.toLowerCase();
    return status.startsWith('cancelled') || status == 'rejected' || status == 'failed';
  }

  bool get isDelivered {
    final status = orderStatus.toLowerCase();
    return status == 'delivered' || status == 'completed';
  }

  /// True while the order sits with the restaurant, before it has accepted or
  /// rejected — the "waiting for confirmation" phase.
  bool get isAwaitingAcceptance {
    final status = orderStatus.toLowerCase();
    return status == 'created' || status == 'pending' || status == 'placed' || status == 'pending_payment';
  }

  /// "Usually confirmed within Xm Ys", derived from the backend's own
  /// acceptance window — never a guessed number.
  String? get confirmationEtaLabel {
    final deadline = acceptanceDeadlineAt;
    if (!isAwaitingAcceptance || deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'Confirming any moment now';
    final mins = remaining.inMinutes;
    final secs = remaining.inSeconds % 60;
    if (mins <= 0) return 'Confirming within ${secs}s';
    return 'Usually confirmed within ${mins}m ${secs}s';
  }

  /// The backend rejects cancellation once the food is on its way.
  bool get canCancel =>
      isActive &&
      const {'created', 'pending', 'placed', 'pending_payment', 'confirmed', 'preparing'}
          .contains(orderStatus.toLowerCase());

  bool get hasRider => deliveryPartner != null && dispatchStatus == 'accepted';
  bool get showDropOtp => dropOtpRequired && !dropOtpVerified;

  /// The live map is shown only once the food is on its way — i.e. after the
  /// rider has picked it up, per the tracking spec. Derived from both status
  /// axes so either advancing turns it on.
  bool get isOutForDelivery {
    final status = orderStatus.toLowerCase();
    final phase = currentPhase.toLowerCase();
    return const {'picked_up', 'reached_drop', 'out_for_delivery', 'en_route_to_delivery'}.contains(status) ||
        const {'en_route_to_delivery', 'at_drop'}.contains(phase);
  }

  /// Human-readable stage label. Kept here so list, detail and tracking all
  /// render the same wording.
  String get statusLabel {
    switch (orderStatus.toLowerCase()) {
      case 'pending_payment':
        return 'Awaiting payment';
      case 'created':
      case 'placed':
      case 'pending':
        return 'Order placed';
      case 'confirmed':
      case 'accepted':
        return 'Confirmed';
      case 'preparing':
        return 'Preparing your food';
      case 'ready':
      case 'ready_for_pickup':
        return 'Ready for pickup';
      case 'reached_pickup':
        return 'Rider at restaurant';
      case 'picked_up':
      case 'out_for_delivery':
      case 'en_route_to_delivery':
        return 'On the way';
      case 'reached_drop':
      case 'at_drop':
        return 'Rider has arrived';
      case 'delivered':
      case 'completed':
        return 'Delivered';
      case 'cancelled_by_user':
        return 'Cancelled by you';
      case 'cancelled_by_restaurant':
        return 'Cancelled by restaurant';
      case 'cancelled_by_admin':
      case 'cancelled':
        return 'Cancelled';
      default:
        return orderStatus;
    }
  }

  /// Live ETA line, e.g. "Arriving in 18 mins" — recomputed server-side from
  /// the rider's live position on every order read (see [OrderEta]). Falls
  /// back to the older pricing-derived road duration for callers still on a
  /// cached response without an `eta` object. Never invents a number.
  String? get etaLabel {
    if (isDelivered || isCancelled) return null;
    switch (eta.source) {
      case 'live':
      case 'estimate':
        final mins = eta.minutes;
        if (mins == null || mins <= 0) break;
        final verb = eta.target == 'restaurant'
            ? 'Rider reaching restaurant in'
            : 'Arriving in';
        return '$verb $mins min${mins == 1 ? '' : 's'}';
      case 'unavailable':
        return 'Calculating...';
      case 'completed':
        return null;
    }
    final mins = roadDurationMins;
    if (mins == null || mins <= 0) return null;
    return 'Arriving in $mins min${mins == 1 ? '' : 's'}';
  }

  /// A number-first version of [etaLabel] for tight spaces (the floating
  /// active-order card) — "27 min" instead of a full sentence.
  String? get compactEtaLabel {
    if (isDelivered || isCancelled) return null;
    final mins = eta.minutes ?? roadDurationMins;
    if (mins == null || mins <= 0) return null;
    return '$mins min${mins == 1 ? '' : 's'}';
  }

  String? get distanceLabel {
    final km = eta.distanceKm ?? roadDistanceKm;
    if (km == null || km <= 0) return null;
    return '${km.toStringAsFixed(1)} km away';
  }

  /// The order's happy-path lifecycle, in order. Cancellations are terminal and
  /// handled separately, so they are not part of the stepper.
  static const List<String> _lifecycle = [
    'created',
    'confirmed',
    'preparing',
    'ready_for_pickup',
    'reached_pickup',
    'picked_up',
    'reached_drop',
    'delivered',
  ];

  /// A dynamic timeline the UI renders without hardcoding stages.
  ///
  /// Each stage's completion is derived from where [orderStatus] sits in the
  /// lifecycle, and its timestamp (when present) from [statusHistory] — so a
  /// backend that adds a new status still renders in the right place via
  /// [statusLabel], and unknown statuses simply append.
  List<OrderStage> get timeline {
    final normStatus = switch (orderStatus.toLowerCase()) {
      'pending_payment' || 'pending' || 'placed' => 'created',
      'accepted' => 'confirmed',
      'ready' => 'ready_for_pickup',
      'out_for_delivery' || 'en_route_to_delivery' => 'picked_up',
      'at_drop' => 'reached_drop',
      'completed' => 'delivered',
      _ => orderStatus.toLowerCase(),
    };
    final currentIndex = _lifecycle.indexOf(normStatus);

    DateTime? timeFor(String status) {
      for (final e in statusHistory) {
        if (e.to.toLowerCase() == status) return e.at;
      }
      return null;
    }

    final stages = <OrderStage>[];
    for (var i = 0; i < _lifecycle.length; i++) {
      final status = _lifecycle[i];
      final reached = currentIndex >= 0 && i <= currentIndex;
      stages.add(
        OrderStage(
          status: status,
          label: _labelFor(status),
          isCompleted: reached && status != normStatus,
          isCurrent: status == normStatus,
          at: timeFor(status),
        ),
      );
    }
    return stages;
  }

  static String _labelFor(String status) {
    switch (status) {
      case 'created':
        return 'Order placed';
      case 'confirmed':
        return 'Order confirmed';
      case 'preparing':
        return 'Preparing your food';
      case 'ready_for_pickup':
        return 'Food is ready';
      case 'reached_pickup':
        return 'Rider at restaurant';
      case 'picked_up':
        return 'Order picked up';
      case 'reached_drop':
        return 'Arriving at your door';
      case 'delivered':
        return 'Delivered';
      default:
        return status;
    }
  }

  static double? _coord(dynamic list, int index) {
    if (list is List && list.length > index) {
      final val = list[index];
      if (val is num) return val.toDouble();
      return double.tryParse(val?.toString() ?? '');
    }
    return null;
  }

  factory OrderModel.fromApi(Map<String, dynamic> rawJson) {
    // Unwrap envelope if present: { order: ... }, { data: { order: ... } }, { data: ... }
    final Map<String, dynamic> json;
    if (rawJson['order'] is Map) {
      json = (rawJson['order'] as Map).cast<String, dynamic>();
    } else if (rawJson['data'] is Map) {
      final inner = (rawJson['data'] as Map).cast<String, dynamic>();
      if (inner['order'] is Map) {
        json = (inner['order'] as Map).cast<String, dynamic>();
      } else {
        json = inner;
      }
    } else {
      json = rawJson;
    }

    // restaurantId is populated to an object on read, but a bare id elsewhere.
    final restaurant = json['restaurantId'] ?? json['restaurant'];
    final restaurantMap = restaurant is Map
        ? restaurant.cast<String, dynamic>()
        : const <String, dynamic>{};

    final pricing =
        (json['pricing'] as Map?)?.cast<String, dynamic>() ?? const {};
    final payment =
        (json['payment'] as Map?)?.cast<String, dynamic>() ?? const {};
    final dispatch =
        (json['dispatch'] as Map?)?.cast<String, dynamic>() ?? const {};
    final deliveryState =
        (json['deliveryState'] as Map?)?.cast<String, dynamic>() ?? const {};
    final address =
        (json['deliveryAddress'] as Map?)?.cast<String, dynamic>() ??
        (json['address'] as Map?)?.cast<String, dynamic>() ??
        const {};
    final ratings =
        (json['ratings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final restaurantRatingMap = (ratings['restaurant'] as Map?)
        ?.cast<String, dynamic>();
    final deliveryRatingMap = (ratings['deliveryPartner'] as Map?)
        ?.cast<String, dynamic>();

    final partner = dispatch['deliveryPartnerId'] ?? json['deliveryPartner'];
    final currentLocation = (deliveryState['currentLocation'] as Map?)
        ?.cast<String, dynamic>();

    final dropOtp =
        ((json['deliveryVerification'] as Map?)?['dropOtp'] as Map?)
            ?.cast<String, dynamic>() ??
        const {};

    final created = json['createdAt']?.toString();
    final delivered = json['deliveredAt']?.toString();
    final acceptanceDeadline = json['acceptanceDeadlineAt']?.toString();

    final statusStr = (json['orderStatus'] ?? json['status'] ?? '').toString().toLowerCase().trim();

    return OrderModel(
      id: (json['_id'] ?? json['orderMongoId'] ?? json['id'] ?? '').toString(),
      orderNumber: (json['order_id'] ?? json['orderId'] ?? json['orderNumber'] ?? json['_id'] ?? '').toString(),
      orderStatus: statusStr,
      currentPhase: (deliveryState['currentPhase'] ?? '').toString(),
      dispatchStatus: (dispatch['status'] ?? '').toString(),
      restaurantId: (restaurantMap['_id'] ?? restaurantMap['id'] ?? (restaurant is String ? restaurant : '')).toString(),
      restaurantName: (restaurantMap['restaurantName'] ?? restaurantMap['name'] ?? json['restaurantName'] ?? '').toString(),
      restaurantImage: ApiConfig.resolveMedia(() {
        final restProfileImg = restaurantMap['profileImage'];
        final restProfileUrl = restProfileImg is Map
            ? (restProfileImg['url'] ?? restProfileImg['imageUrl']) as String?
            : restProfileImg as String?;
        final restCovers = (restaurantMap['coverImages'] as List?)
            ?.map((e) => e is Map ? (e['url'] ?? e['imageUrl']) as String? : e as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList() ?? const [];
        return (restProfileUrl != null && restProfileUrl.isNotEmpty)
            ? restProfileUrl
            : (restaurantMap['image'] is String && (restaurantMap['image'] as String).isNotEmpty
                ? restaurantMap['image'] as String
                : (restCovers.isNotEmpty ? restCovers.first : null));
      }()),
      restaurantAddress: (restaurantMap['address'] ?? '').toString(),
      restaurantRating: _money(restaurantMap['rating']),
      restaurantIsOpen: restaurantMap['isOpen'] == true || restaurantMap['isOpen']?.toString().toLowerCase() == 'true',
      restaurantIsVerified: restaurantMap['isVerified'] == true || restaurantMap['isVerified']?.toString().toLowerCase() == 'true',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OrderItem.fromApi(e.cast<String, dynamic>()))
          .toList(),
      total: _money(pricing['total'] ?? json['total'] ?? json['grandTotal'] ?? json['amount']),
      itemTotal: _money(pricing['subtotal'] ?? pricing['itemTotal']),
      addonTotal: _money(pricing['addonTotal']),
      packingCharge: _money(pricing['packagingFee'] ?? pricing['packingCharge']),
      platformFee: _money(pricing['platformFee']),
      deliveryCharge: _money(pricing['deliveryFee'] ?? pricing['deliveryCharge']),
      taxes: _money(pricing['tax']) +
          _money(pricing['deliveryFeeGst']) +
          _money(pricing['taxes']),
      itemTax: _money(pricing['tax']) > 0
          ? _money(pricing['tax'])
          : double.parse((_money(pricing['subtotal'] ?? pricing['itemTotal']) * 0.05).toStringAsFixed(2)).clamp(
              0.0,
              _money(pricing['tax']) + _money(pricing['deliveryFeeGst']) + _money(pricing['taxes']),
            ),
      deliveryFeeGst: _money(pricing['tax']) > 0
          ? (_money(pricing['deliveryFeeGst']) + _money(pricing['taxes']))
          : double.parse(
              ((_money(pricing['tax']) + _money(pricing['deliveryFeeGst']) + _money(pricing['taxes'])) -
                      double.parse((_money(pricing['subtotal'] ?? pricing['itemTotal']) * 0.05).toStringAsFixed(2)).clamp(
                        0.0,
                        _money(pricing['tax']) + _money(pricing['deliveryFeeGst']) + _money(pricing['taxes']),
                      ))
                  .toStringAsFixed(2),
            ),
      gstRate: _money(pricing['gstRate']) > 0 ? _money(pricing['gstRate']) : 5.0,
      deliveryFeeGstRate: _money(pricing['deliveryFeeGstRate']) > 0 ? _money(pricing['deliveryFeeGstRate']) : 18.0,
      couponDiscount: _money(pricing['discount'] ?? pricing['couponDiscount']),
      walletUsed: _money(pricing['walletUsed'] ?? pricing['walletDiscount']),
      rewardDiscount: _money(pricing['rewardDiscount']),
      driverTip: _money(
        pricing['tip'] ?? pricing['driverTip'] ?? pricing['deliveryTip'],
      ),
      currency: (pricing['currency'] ?? json['currency'] ?? 'INR').toString(),
      paymentMethod: (payment['method'] ?? payment['paymentMethod'] ?? json['paymentMethod'] ?? json['payment_method'] ?? '').toString(),
      paymentStatus: (payment['status'] ?? payment['paymentStatus'] ?? json['paymentStatus'] ?? json['payment_status'] ?? '').toString(),
      refundStatus: ((payment['refund'] as Map?)?['status'] ?? 'none').toString(),
      transactionId: (payment['transactionId'] ?? '').toString(),
      paymentTime: payment['time'] != null
          ? DateTime.tryParse(payment['time'].toString())
          : (payment['createdAt'] != null
                ? DateTime.tryParse(payment['createdAt'].toString())
                : null),
      refundAmount: _money((payment['refund'] as Map?)?['amount']),
      deliveryPartner: partner is Map
          ? DeliveryPartner.fromApi(partner.cast<String, dynamic>())
          : null,
      riderLat: currentLocation?['lat'] != null ? _money(currentLocation!['lat']) : null,
      riderLng: currentLocation?['lng'] != null ? _money(currentLocation!['lng']) : null,
      restaurantLat: _coord(
        (restaurantMap['location'] as Map?)?['coordinates'],
        1,
      ),
      restaurantLng: _coord(
        (restaurantMap['location'] as Map?)?['coordinates'],
        0,
      ),
      dropLat: _coord((address['location'] as Map?)?['coordinates'], 1),
      dropLng: _coord((address['location'] as Map?)?['coordinates'], 0),
      roadDistanceKm: pricing['roadDistanceKm'] != null ? _money(pricing['roadDistanceKm']) : null,
      roadDurationMins: pricing['roadDurationMins'] != null ? _intVal(pricing['roadDurationMins']) : null,
      eta: OrderEta.fromApi((json['eta'] as Map?)?.cast<String, dynamic>()),
      dropOtpRequired: dropOtp['required'] == true || dropOtp['required']?.toString() == 'true' || json['dropOtpRequired'] == true,
      dropOtpVerified: dropOtp['verified'] == true || dropOtp['verified']?.toString() == 'true' || json['dropOtpVerified'] == true,
      statusHistory: ((json['statusHistory'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => OrderStatusEvent.fromApi(e.cast<String, dynamic>()))
          .toList(),
      cancellationReason: (json['cancellationReason'] ?? '').toString(),
      cancelledBy: (json['cancelledBy'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created),
      deliveredAt: delivered == null ? null : DateTime.tryParse(delivered),
      acceptanceDeadlineAt: acceptanceDeadline == null
          ? null
          : DateTime.tryParse(acceptanceDeadline),
      deliveryAddress: [
        address['street'],
        address['city'],
        address['state'],
        address['zipCode'],
      ].whereType<String>().where((e) => e.trim().isNotEmpty).join(', '),
      customerName:
          (json['customerName'] ?? address['name'] ?? address['fullName'] ?? '')
              .toString(),
      customerPhone: (json['customerPhone'] ?? address['phone'] ?? '')
          .toString(),
      landmark: (address['landmark'] ?? '').toString(),
      note: (json['note'] ?? json['cookingRequest'] ?? '').toString(),
      foodRating: _money(restaurantRatingMap?['rating']),
      deliveryRating: _money(deliveryRatingMap?['rating']),
      foodRatingComment: (restaurantRatingMap?['comment'] ?? '').toString(),
      deliveryRatingComment: (deliveryRatingMap?['comment'] ?? '').toString(),
    );
  }
}
