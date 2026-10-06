import '../../core/config/api_config.dart';
import 'food_variant.dart';

class FoodModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final List<String> imageGallery;
  final double rating;
  final int reviewCount;
  final int calories;
  final String deliveryTime;
  final bool isVeg;
  final bool isSpicy;
  final bool isPopular;
  final bool isQuickDelivery;
  final String categoryName;
  final String categoryId;
  final String restaurantName;

  /// Size/portion choices. Empty when the item has a single price.
  final List<FoodVariant> variants;

  /// Free-text nutrition facts, e.g. "Calories 250 kcal". Empty when unset.
  final List<String> nutrition;

  /// Free-text allergens, e.g. "Peanuts". Empty when unset.
  final List<String> allergens;

  /// Set when this is a food campaign dish rather than a menu item ([id] is
  /// then the campaign id too). The server prices it from the campaign.
  final String? campaignId;

  bool get isCampaign => campaignId != null && campaignId!.isNotEmpty;

  const FoodModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.imageGallery = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.calories = 0,
    this.deliveryTime = '',
    this.isVeg = false,
    this.isSpicy = false,
    this.isPopular = false,
    this.isQuickDelivery = false,
    this.categoryName = '',
    this.categoryId = '',
    this.restaurantName = '',
    this.variants = const [],
    this.nutrition = const [],
    this.allergens = const [],
    this.campaignId,
  });

  /// "X% OFF" badge value, or null when there's no genuine [originalPrice] to
  /// compare against. Single source of truth so every badge agrees.
  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= 0) return null;
    return (((1 - (price / original)) * 100).clamp(0, 99)).round();
  }

  /// Every image for the dish, primary first, as absolute URLs.
  ///
  /// Deduplicated because the backend keeps `image` as `images[0]`, so a naive
  /// merge of the two would repeat the primary and render a duplicate slide.
  static List<String> _galleryFrom(Map<String, dynamic> json) {
    final imagesRaw = json['images'];
    final List<dynamic> imagesList = imagesRaw is List
        ? imagesRaw
        : (imagesRaw is String && imagesRaw.trim().isNotEmpty)
            ? [imagesRaw.trim()]
            : const [];

    final raw = <String?>[
      json['image'] as String?,
      ...imagesList.map((e) => e?.toString()),
    ];

    final seen = <String>{};
    final gallery = <String>[];
    for (final entry in raw) {
      if (entry == null || entry.trim().isEmpty) continue;
      final url = ApiConfig.resolveMedia(entry);
      if (url.isEmpty || !seen.add(url)) continue;
      gallery.add(url);
    }
    return gallery;
  }

  /// A compare-at price, or null when there is no genuine discount to show.
  ///
  /// The backend stores `otherPrice: 0` for dishes that were never given one,
  /// and 0 is not null — so it slipped through every `originalPrice != null`
  /// guard in the UI. The percent-off badges divide by it, and 1 - price/0 is
  /// Infinity, which `.toInt()` refuses: "Unsupported operation: Infinity or
  /// NaN toInt". That replaced the whole section with a red error box the
  /// moment a dish priced this way went live.
  ///
  /// Anything not strictly above the selling price is discarded here rather
  /// than at each call site, so the strikethrough and the badge can never
  /// disagree, and no future screen has to remember the rule.
  static double? _compareAtPrice(Object? raw, double price) {
    final value = (raw as num?)?.toDouble();
    if (value == null || !value.isFinite) return null;
    return value > price ? value : null;
  }

  /// Tolerant string-list parse: accepts a list (non-string entries are
  /// stringified), a comma-separated string, or anything else as empty.
  static List<String> _stringList(Object? raw) {
    final Iterable<Object?> items = raw is List
        ? raw
        : (raw is String ? raw.split(',') : const <Object?>[]);
    return items
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// Maps a backend food/menu item. Used by the cross-restaurant feed
  /// (`/public/foods`) and by each menu section's `items[]` — same shape.
  factory FoodModel.fromApi(Map<String, dynamic> json, {String? restaurantId}) {
    final price = (json['price'] as num?)?.toDouble() ?? 0.0;
    final imagesRaw = json['images'];
    final rawImage = (json['image'] is String && (json['image'] as String).trim().isNotEmpty)
        ? (json['image'] as String).trim()
        : (imagesRaw is List && imagesRaw.isNotEmpty)
            ? imagesRaw.first?.toString().trim()
            : (imagesRaw is String && imagesRaw.trim().isNotEmpty)
                ? imagesRaw.trim()
                : null;

    return FoodModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      restaurantId: (json['restaurantId'] ?? restaurantId ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: price,
      originalPrice: _compareAtPrice(json['otherPrice'], price),
      imageUrl: ApiConfig.resolveMedia(rawImage),
      // The API sends `images` (primary first) for dishes with a gallery, and
      // only `image` for everything saved before galleries existed. Falling back
      // to the single image means the detail screen can always just read
      // imageGallery instead of special-casing the old shape.
      imageGallery: _galleryFrom(json),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['totalRatings'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      deliveryTime: (json['preparationTime'] ?? json['prepTime'] ?? json['deliveryTime'] ?? '').toString(),
      isVeg: () {
        if (json['foodType'] != null) {
          final ft = json['foodType'].toString().trim().toLowerCase();
          if (ft.contains('non') || ft == 'egg') return false;
          if (ft == 'veg' || ft == 'pure veg') return true;
        }
        if (json['isVeg'] is bool) return json['isVeg'] as bool;
        if (json['isVeg'] != null) {
          final s = json['isVeg'].toString().trim().toLowerCase();
          if (s == 'true' || s == '1') return true;
          if (s == 'false' || s == '0') return false;
        }
        return false;
      }(),
      isPopular: json['isRecommended'] as bool? ?? false,
      isQuickDelivery: json['isQuickDelivery'] as bool? ?? false,
      categoryName: (json['categoryName'] ?? '').toString(),
      categoryId: (json['categoryId'] ?? json['category'] ?? '').toString(),
      restaurantName: (json['restaurantName'] ?? '').toString(),
      variants: FoodVariant.listFrom(json),
      nutrition: _stringList(json['nutrition']),
      allergens: _stringList(json['allergens']),
    );
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['imageGallery'];
    final List<String> parsedGallery = (imagesRaw is List)
        ? imagesRaw.map((e) => e.toString()).toList()
        : (imagesRaw is String && imagesRaw.isNotEmpty)
            ? [imagesRaw]
            : const [];

    return FoodModel(
      id: (json['id'] ?? '').toString(),
      restaurantId: (json['restaurantId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      // Same rule as fromApi: a cached model must not resurrect a zero or
      // below-price compare-at value that the network path would have dropped.
      originalPrice: _compareAtPrice(
        json['originalPrice'],
        (json['price'] as num?)?.toDouble() ?? 0.0,
      ),
      imageUrl: (json['imageUrl'] ?? '').toString(),
      imageGallery: parsedGallery,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      isVeg: json['isVeg'] == true ||
          json['isVeg']?.toString().toLowerCase() == 'true' ||
          (json['foodType']?.toString().toLowerCase() == 'veg'),
      isSpicy: json['isSpicy'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
      isQuickDelivery: json['isQuickDelivery'] as bool? ?? false,
      categoryName: json['categoryName'] as String? ?? '',
      categoryId: json['categoryId'] as String? ?? '',
      restaurantName: json['restaurantName'] as String? ?? '',
      variants: FoodVariant.listFrom(json),
      nutrition: _stringList(json['nutrition']),
      allergens: _stringList(json['allergens']),
      campaignId: (json['campaignId'] as String?)?.trim().isNotEmpty == true
          ? (json['campaignId'] as String).trim()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'imageGallery': imageGallery,
      'rating': rating,
      'reviewCount': reviewCount,
      'calories': calories,
      'deliveryTime': deliveryTime,
      'isVeg': isVeg,
      'isSpicy': isSpicy,
      'isPopular': isPopular,
      'isQuickDelivery': isQuickDelivery,
      'categoryName': categoryName,
      'categoryId': categoryId,
      'restaurantName': restaurantName,
      'variants': variants.map((v) => v.toJson()).toList(),
      'nutrition': nutrition,
      'allergens': allergens,
      'campaignId': ?campaignId,
    };
  }
}
