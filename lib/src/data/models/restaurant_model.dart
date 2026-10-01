import 'package:flutter/foundation.dart';
import '../../core/config/api_config.dart';

class RestaurantModel {
  final String id;
  final String name;
  final String imageUrl;
  final List<String> coverImages;
  final List<String> menuImages;
  final double rating;
  final int reviewCount;
  final String deliveryTime;
  final double deliveryFee;
  final List<String> tags;
  final bool isFeatured;
  final double distanceKm;
  final double priceForOne;
  final String? featuredDishName;
  final bool isNearAndFast;
  final List<String> offerBadges;
  final List<String> restaurantTags;
  final bool isOpen;
  final String closingTime;
  final bool isPureVeg;
  final bool isFreeDelivery;
  final String area;

  /// The restaurant's own coordinates, when the backend sent them. Kept so the
  /// app can measure distance itself: [distanceKm] is only populated when the
  /// request carried the user's lat/lng, and it silently arrives as 0 otherwise.
  final double? latitude;
  final double? longitude;

  const RestaurantModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    this.coverImages = const [],
    this.menuImages = const [],
    required this.rating,
    this.reviewCount = 0,
    required this.deliveryTime,
    required this.deliveryFee,
    required this.tags,
    this.isFeatured = false,
    this.distanceKm = 0.0,
    this.priceForOne = 0.0,
    this.featuredDishName,
    this.isNearAndFast = false,
    this.offerBadges = const [],
    this.restaurantTags = const [],
    this.isOpen = true,
    this.closingTime = '',
    this.isPureVeg = false,
    this.isFreeDelivery = false,
    this.area = '',
    this.latitude,
    this.longitude,
  });

  /// Pulls lat/lng out of whichever shape the backend used: a `location` map
  /// with latitude/longitude, or GeoJSON `coordinates` as [lng, lat].
  static (double?, double?) _coordsOf(Map<String, dynamic> json) {
    final loc = json['location'];
    if (loc is! Map) return (null, null);
    final lat = (loc['latitude'] as num?)?.toDouble();
    final lng = (loc['longitude'] as num?)?.toDouble();
    if (lat != null && lng != null) return (lat, lng);
    final coords = loc['coordinates'];
    if (coords is List && coords.length >= 2) {
      return (
        (coords[1] as num?)?.toDouble(),
        (coords[0] as num?)?.toDouble(),
      );
    }
    return (null, null);
  }

  /// Robustly determines whether a restaurant is open or closed based on backend payload.
  static bool _parseIsOpen(Map<String, dynamic> json) {
    // 1. Explicit boolean or string 'false' for closed indicators
    final isClosedVal = json['isClosed'] ?? json['closed'] ?? json['isStoreClosed'];
    if (isClosedVal == true ||
        isClosedVal?.toString().trim().toLowerCase() == 'true' ||
        isClosedVal == 1 ||
        isClosedVal?.toString().trim() == '1') {
      return false;
    }

    // 2. Status string checks (closed, inactive, offline, paused, disabled)
    final rawStatus = (json['status'] ??
            json['restaurantStatus'] ??
            json['storeStatus'] ??
            json['businessStatus'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (rawStatus != null && rawStatus.isNotEmpty) {
      if (rawStatus == 'closed' ||
          rawStatus == 'inactive' ||
          rawStatus == 'offline' ||
          rawStatus == 'disabled' ||
          rawStatus == 'paused' ||
          rawStatus == 'shut' ||
          rawStatus == 'close') {
        return false;
      }
    }

    // 3. Explicit active flags: if isActive is false, restaurant is closed
    if (json.containsKey('isActive')) {
      final active = json['isActive'];
      if (active == false ||
          active?.toString().trim().toLowerCase() == 'false' ||
          active == 0 ||
          active?.toString().trim() == '0') {
        return false;
      }
    }
    if (json.containsKey('active')) {
      final active = json['active'];
      if (active == false ||
          active?.toString().trim().toLowerCase() == 'false' ||
          active == 0 ||
          active?.toString().trim() == '0') {
        return false;
      }
    }

    // 4. isAcceptingOrders flag: if false, it cannot accept orders (closed for ordering)
    if (json.containsKey('isAcceptingOrders')) {
      final acc = json['isAcceptingOrders'];
      if (acc == false ||
          acc?.toString().trim().toLowerCase() == 'false' ||
          acc == 0 ||
          acc?.toString().trim() == '0') {
        return false;
      }
    }

    // 5. isOpen / isRestaurantOpen / open flags
    final openVal = json['isOpen'] ?? json['isRestaurantOpen'] ?? json['open'];
    if (openVal != null) {
      if (openVal == false ||
          openVal.toString().trim().toLowerCase() == 'false' ||
          openVal == 0 ||
          openVal.toString().trim() == '0') {
        return false;
      }
      if (openVal == true ||
          openVal.toString().trim().toLowerCase() == 'true' ||
          openVal == 1 ||
          openVal.toString().trim() == '1') {
        return true;
      }
    }

    // 6. isOnline flag
    if (json.containsKey('isOnline')) {
      final online = json['isOnline'];
      if (online == false ||
          online?.toString().trim().toLowerCase() == 'false' ||
          online == 0 ||
          online?.toString().trim() == '0') {
        return false;
      }
    }

    // 7. If isAcceptingOrders was explicitly true
    if (json['isAcceptingOrders'] == true ||
        json['isAcceptingOrders']?.toString().trim().toLowerCase() == 'true') {
      return true;
    }

    // 8. If status was explicitly open/active
    if (rawStatus == 'open' || rawStatus == 'active' || rawStatus == 'opened') {
      return true;
    }

    return true;
  }

  /// Extracts locality / area name from backend restaurant JSON.
  static String _extractLocationFromApi(Map<String, dynamic> json) {
    // 1. Direct String fields for area / locality / locationName
    final directKeys = [
      'area',
      'locality',
      'subLocality',
      'locationName',
      'areaName',
      'outletArea',
      'branchName',
      'neighborhood',
      'vicinity',
    ];

    for (final key in directKeys) {
      final val = json[key];
      if (val is String && val.trim().isNotEmpty) {
        return val.trim();
      }
    }

    // 2. Check if 'location' or 'address' is a Map object
    final mapsToCheck = <Map>[];
    if (json['location'] is Map) mapsToCheck.add(json['location'] as Map);
    if (json['address'] is Map) mapsToCheck.add(json['address'] as Map);

    for (final locMap in mapsToCheck) {
      final mapKeys = [
        'area',
        'locality',
        'subLocality',
        'locationName',
        'areaName',
        'name',
        'addressLine1',
        'street',
        'city',
      ];
      for (final key in mapKeys) {
        final val = locMap[key];
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    }

    // 3. Fallback to raw address or location string (e.g. "Shop 12, Main Road, Vijay Nagar, Indore")
    String? rawAddress;
    if (json['address'] is String && (json['address'] as String).trim().isNotEmpty) {
      rawAddress = (json['address'] as String).trim();
    } else if (json['location'] is String && (json['location'] as String).trim().isNotEmpty) {
      rawAddress = (json['location'] as String).trim();
    } else if (json['addressLine1'] is String && (json['addressLine1'] as String).trim().isNotEmpty) {
      rawAddress = (json['addressLine1'] as String).trim();
    } else if (json['city'] is String && (json['city'] as String).trim().isNotEmpty) {
      rawAddress = (json['city'] as String).trim();
    }

    if (rawAddress != null && rawAddress.isNotEmpty) {
      final parts = rawAddress
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (parts.isNotEmpty) {
        if (parts.length == 1) {
          return parts.first;
        } else if (parts.length == 2) {
          return parts.first;
        } else {
          // If e.g. "Shop 101, Main Road, Vijay Nagar, Indore", pick second to last part ("Vijay Nagar")
          return parts[parts.length - 2];
        }
      }
    }

    return '';
  }

  /// Parses rating from diverse backend response schemas.
  static double _parseRating(Map<String, dynamic> json) {
    final candidates = [
      json['rating'],
      json['avgRating'],
      json['averageRating'],
      json['ratingAverage'],
      json['ratings'],
      json['restaurantRating'],
      json['starRating'],
      json['overallRating'],
      json['userRating'],
      json['ratingValue'],
      json['stars'],
      json['rate'],
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      if (candidate is num && candidate > 0) return candidate.toDouble();
      if (candidate is String) {
        final parsed = double.tryParse(candidate);
        if (parsed != null && parsed > 0) return parsed;
      }
      if (candidate is Map) {
        final subCandidates = [
          candidate['average'],
          candidate['avg'],
          candidate['value'],
          candidate['rating'],
          candidate['val'],
          candidate['stars'],
          candidate['rate'],
        ];
        for (final sub in subCandidates) {
          if (sub is num && sub > 0) return sub.toDouble();
          if (sub is String) {
            final parsed = double.tryParse(sub);
            if (parsed != null && parsed > 0) return parsed;
          }
        }
      }
    }
    return 0.0;
  }

  /// Maps a backend restaurant document.
  factory RestaurantModel.fromApi(Map<String, dynamic> json) {
    final image = json['profileImage'] ?? json['logo'] ?? json['image'];
    final imageUrlRaw = image is Map
        ? (image['url'] ?? image['imageUrl']) as String?
        : image as String?;
    
    final covers = json['coverImages'];
    final coversRaw = (covers is List)
        ? covers
            .map((e) => e is Map ? (e['url'] ?? e['imageUrl']) as String? : e as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList()
        : (covers is String && covers.isNotEmpty)
            ? [covers]
            : const <String>[];

    final singleCover = json['coverImage'];
    final singleCoverUrl = singleCover is Map
        ? (singleCover['url'] ?? singleCover['imageUrl']) as String?
        : singleCover as String?;

    final allCovers = [
      ...coversRaw,
      if (coversRaw.isEmpty && singleCoverUrl != null && singleCoverUrl.isNotEmpty) singleCoverUrl,
    ];

    final resolvedCovers = allCovers.map((c) => ApiConfig.resolveMedia(c)).toList();

    final menus = json['menuImages'];
    final menusRaw = (menus is List)
        ? menus
            .map((e) => e is Map ? (e['url'] ?? e['imageUrl']) as String? : e as String?)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .toList()
        : (menus is String && menus.isNotEmpty)
            ? [menus]
            : const <String>[];

    final resolvedMenuImages = menusRaw.map((c) => ApiConfig.resolveMedia(c)).toList();

    final primaryImageUrl = ApiConfig.resolveMedia(
      (imageUrlRaw != null && imageUrlRaw.isNotEmpty)
          ? imageUrlRaw
          : (resolvedCovers.isNotEmpty ? resolvedCovers.first : null),
    );

    final offers = <String>[];
    final offer = json['offer'];
    if (offer is String && offer.isNotEmpty) offers.add(offer);
    final rawOffers = json['offers'];
    final offersList = rawOffers is List ? rawOffers : const [];
    for (final o in offersList) {
      if (o is Map && o['title'] is String) {
        offers.add(o['title'] as String);
      } else if (o is String && o.isNotEmpty) {
        offers.add(o);
      }
    }
    if (json['discountText'] is String && (json['discountText'] as String).isNotEmpty) {
      offers.add(json['discountText'] as String);
    }

    final isPureVeg = json['pureVegRestaurant'] == true ||
        json['isVeg'] == true ||
        json['isPureVeg'] == true ||
        json['pureVeg'] == true ||
        json['veg'] == true ||
        json['isVegOnly'] == true ||
        (json['category']?.toString().toLowerCase().contains('veg') == true) ||
        (json['foodType']?.toString().toLowerCase() == 'veg');
    final isFreeDeliv = json['isFreeDelivery'] == true ||
        json['isFreeDelivery']?.toString().toLowerCase() == 'true' ||
        json['freeDelivery'] == true ||
        json['freeDelivery']?.toString().toLowerCase() == 'true' ||
        json['free_delivery'] == true ||
        json['free_delivery']?.toString().toLowerCase() == 'true' ||
        json['hasFreeDelivery'] == true;
    final areaName = _extractLocationFromApi(json);

    final restId = (json['_id'] ?? json['id'] ?? json['restaurantId'] ?? '').toString();
    final restName = (json['restaurantName'] ?? json['name'] ?? '').toString();

    final isOpen = _parseIsOpen(json);

    if (kDebugMode) {
      debugPrint('[RESTAURANT] ID: $restId | Name: $restName | Location: "$areaName" | isOpen: $isOpen');
    }

    final closes = (json['closingTime'] ??
            json['closesIn'] ??
            json['operatingHours'] ??
            json['openingTime'] ??
            json['timings'] ??
            json['timing'] ??
            '')
        .toString();
    final featuredDishName = (json['featuredDish'] as String?)?.isNotEmpty == true ? json['featuredDish'] as String : null;

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? (double.tryParse(val)?.toInt() ?? 0);
      return 0;
    }

    final priceForOne = parseDouble(
        json['featuredPrice'] ?? json['priceForOne'] ?? json['startingPrice'] ?? json['minOrder']);

    final deliveryTimeStr = (json['estimatedDeliveryTime'] ??
            json['deliveryTime'] ??
            (json['estimatedDeliveryTimeMinutes'] != null ? '${json['estimatedDeliveryTimeMinutes']} mins' : ''))
        .toString();

    return RestaurantModel(
      id: restId,
      name: restName,
      imageUrl: primaryImageUrl,
      coverImages: resolvedCovers.isNotEmpty ? resolvedCovers : (primaryImageUrl.isNotEmpty ? [primaryImageUrl] : const []),
      menuImages: resolvedMenuImages,
      rating: _parseRating(json),
      reviewCount: parseInt(json['totalRatings'] ?? json['reviewCount']),
      deliveryTime: deliveryTimeStr,
      deliveryFee: parseDouble(json['deliveryFee']),
      tags: () {
        final cuisinesRaw = json['cuisines'];
        final tagsRaw = json['tags'];
        if (cuisinesRaw is List) {
          return cuisinesRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        } else if (cuisinesRaw is String && cuisinesRaw.isNotEmpty) {
          return cuisinesRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        } else if (tagsRaw is List) {
          return tagsRaw.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
        } else if (tagsRaw is String && tagsRaw.isNotEmpty) {
          return tagsRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        }
        return const <String>[];
      }(),
      isFeatured: json['isFeatured'] as bool? ?? false,
      distanceKm: parseDouble(json['distanceInKm'] ?? (parseDouble(json['distanceMeters']) / 1000)),
      latitude: _coordsOf(json).$1,
      longitude: _coordsOf(json).$2,
      priceForOne: priceForOne,
      featuredDishName: featuredDishName,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges: offers,
      restaurantTags: [
        if (isPureVeg) 'Pure Veg',
        if (isFreeDeliv) 'Free Delivery',
        if (areaName.isNotEmpty) areaName,
      ],
      isOpen: isOpen,
      closingTime: closes,
      isPureVeg: isPureVeg,
      isFreeDelivery: isFreeDeliv,
      area: areaName,
    );
  }

  factory RestaurantModel.fromJson(Map<String, dynamic> json) {
    final areaVal = json['area'] as String? ?? _extractLocationFromApi(json);
    final covers = json['coverImages'];
    final parsedCovers = (covers is List)
        ? covers.map((e) => e.toString()).toList()
        : (covers is String && covers.isNotEmpty)
            ? [covers]
            : const <String>[];

    final menus = json['menuImages'];
    final parsedMenus = (menus is List)
        ? menus.map((e) => e.toString()).toList()
        : (menus is String && menus.isNotEmpty)
            ? [menus]
            : const <String>[];

    final rawTags = json['tags'];
    final parsedTags = (rawTags is List)
        ? rawTags.map((e) => e.toString()).toList()
        : (rawTags is String && rawTags.isNotEmpty)
            ? rawTags.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
            : const <String>[];

    final rawOffers = json['offerBadges'];
    final parsedOffers = (rawOffers is List)
        ? rawOffers.map((e) => e.toString()).toList()
        : const <String>[];

    final rawRestTags = json['restaurantTags'];
    final parsedRestTags = (rawRestTags is List)
        ? rawRestTags.map((e) => e.toString()).toList()
        : const <String>[];

    return RestaurantModel(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      coverImages: parsedCovers,
      menuImages: parsedMenus,
      rating: _parseRating(json),
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      deliveryFee: (json['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      tags: parsedTags,
      isFeatured: json['isFeatured'] as bool? ?? false,
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      priceForOne: (json['priceForOne'] as num?)?.toDouble() ?? 0.0,
      featuredDishName: json['featuredDishName'] as String?,
      isNearAndFast: json['isNearAndFast'] as bool? ?? false,
      offerBadges: parsedOffers,
      restaurantTags: parsedRestTags,
      isOpen: _parseIsOpen(json),
      closingTime: json['closingTime'] as String? ?? '',
      isPureVeg: json['isPureVeg'] as bool? ?? false,
      isFreeDelivery: json['isFreeDelivery'] == true ||
          json['isFreeDelivery']?.toString().toLowerCase() == 'true' ||
          json['freeDelivery'] == true ||
          json['freeDelivery']?.toString().toLowerCase() == 'true' ||
          json['free_delivery'] == true ||
          json['free_delivery']?.toString().toLowerCase() == 'true' ||
          json['hasFreeDelivery'] == true,
      area: areaVal,
    );
  }

  RestaurantModel copyWith({
    String? id,
    String? name,
    String? imageUrl,
    List<String>? coverImages,
    List<String>? menuImages,
    double? rating,
    int? reviewCount,
    String? deliveryTime,
    double? deliveryFee,
    List<String>? tags,
    bool? isFeatured,
    double? distanceKm,
    double? priceForOne,
    String? featuredDishName,
    bool? isNearAndFast,
    List<String>? offerBadges,
    List<String>? restaurantTags,
    bool? isOpen,
    String? closingTime,
    bool? isPureVeg,
    bool? isFreeDelivery,
    String? area,
    double? latitude,
    double? longitude,
  }) {
    return RestaurantModel(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      coverImages: coverImages ?? this.coverImages,
      menuImages: menuImages ?? this.menuImages,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      tags: tags ?? this.tags,
      isFeatured: isFeatured ?? this.isFeatured,
      distanceKm: distanceKm ?? this.distanceKm,
      priceForOne: priceForOne ?? this.priceForOne,
      featuredDishName: featuredDishName ?? this.featuredDishName,
      isNearAndFast: isNearAndFast ?? this.isNearAndFast,
      offerBadges: offerBadges ?? this.offerBadges,
      restaurantTags: restaurantTags ?? this.restaurantTags,
      isOpen: isOpen ?? this.isOpen,
      closingTime: closingTime ?? this.closingTime,
      isPureVeg: isPureVeg ?? this.isPureVeg,
      isFreeDelivery: isFreeDelivery ?? this.isFreeDelivery,
      area: area ?? this.area,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'coverImages': coverImages,
      'menuImages': menuImages,
      'rating': rating,
      'reviewCount': reviewCount,
      'deliveryTime': deliveryTime,
      'deliveryFee': deliveryFee,
      'tags': tags,
      'isFeatured': isFeatured,
      'distanceKm': distanceKm,
      'latitude': latitude,
      'longitude': longitude,
      'priceForOne': priceForOne,
      'featuredDishName': featuredDishName,
      'isNearAndFast': isNearAndFast,
      'offerBadges': offerBadges,
      'restaurantTags': restaurantTags,
      'isOpen': isOpen,
      'closingTime': closingTime,
      'isPureVeg': isPureVeg,
      'isFreeDelivery': isFreeDelivery,
      'area': area,
    };
  }
}
