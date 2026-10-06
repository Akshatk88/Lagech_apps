import '../../core/config/api_config.dart';

/// A promotional banner shown in the home carousel, uploaded by an admin.
class PromoBannerModel {
  const PromoBannerModel({
    required this.id,
    required this.imageUrl,
    this.title = '',
    this.ctaLink = '',
    this.bannerType = '',
    this.linkedRestaurantIds = const [],
    this.linkedFoodId,
    this.linkedFoodRestaurantId,
  });

  final String id;
  final String imageUrl;
  final String title;

  /// What a tap opens: `restaurant`, `food` or `link`. Empty from an older
  /// backend, which keeps the [ctaLink]-only behaviour.
  final String bannerType;

  /// For `restaurant` banners: the first one is opened.
  final List<String> linkedRestaurantIds;

  /// For `food` banners: the dish, and the restaurant it belongs to. Null when
  /// the dish was deleted or unapproved — the banner is then a plain image.
  final String? linkedFoodId;
  final String? linkedFoodRestaurantId;

  /// Optional destination. Empty means the banner is decorative and should not
  /// react to taps at all — showing a pressed state for a banner that goes
  /// nowhere reads as a broken link.
  final String ctaLink;

  /// In-app routes a banner is allowed to open.
  ///
  /// Whitelisted rather than pushed blindly because the router has no
  /// errorBuilder: an unknown path shows go_router's raw "page not found"
  /// screen. Admins type these by hand, and some existing banners point at web
  /// paths (/food/user/offers) that only exist on the website — those must be
  /// inert, not a broken screen.
  static const _appRoutePrefixes = <String>{
    '/home',
    '/search',
    '/cart',
    '/orders',
    '/all-offers',
    '/store-99',
    '/favorites',
    '/wallet',
    '/referral',
    '/refer-earn',
    '/restaurant-detail',
    '/food-detail',
    '/notifications',
    '/buy-again',
  };

  /// Where a tap should go, or null when the banner is decorative.
  ///
  /// Returns the link itself for a valid in-app route, or an http(s) URL to be
  /// opened externally. Anything else resolves to null so the banner simply
  /// does not respond.
  String? get destination {
    final link = ctaLink.trim();
    if (link.isEmpty) return null;

    if (link.startsWith('/')) {
      final matches = _appRoutePrefixes.any(
        (p) => link == p || link.startsWith('$p/') || link.startsWith('$p?'),
      );
      return matches ? link : null;
    }

    final uri = Uri.tryParse(link);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return link;
    }
    return null;
  }

  bool get isTappable => destination != null;

  /// The in-app route or http(s) URL a tap opens, following `bannerType`:
  /// restaurant → that restaurant, food → that dish, link → [ctaLink].
  /// Null means the banner does nothing. [hasTypedTarget] tells the caller
  /// whether to use this rather than the legacy [destination] fallback.
  String? get typedDestination {
    switch (bannerType) {
      case 'restaurant':
        final id = linkedRestaurantIds.firstOrNull;
        return (id == null || id.isEmpty) ? null : '/restaurant-detail/$id';
      case 'food':
        final foodId = linkedFoodId;
        final restaurantId = linkedFoodRestaurantId;
        if (foodId == null || foodId.isEmpty) return null;
        return Uri(
          path: '/food-detail',
          queryParameters: {
            'id': foodId,
            if (restaurantId != null && restaurantId.isNotEmpty)
              'restaurantId': restaurantId,
          },
        ).toString();
      case 'link':
        return destination;
      default:
        return null;
    }
  }

  /// True for banners carrying a known `bannerType`.
  bool get hasTypedTarget =>
      const {'restaurant', 'food', 'link'}.contains(bannerType);

  factory PromoBannerModel.fromApi(Map<String, dynamic> json) {
    final linkedFood = (json['linkedFood'] as Map?)?.cast<String, dynamic>();
    return PromoBannerModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      // Stored as `imageUrl` on this model, unlike dishes which use `image`.
      // resolveMedia handles both absolute URLs and upload-relative paths.
      imageUrl: ApiConfig.resolveMedia(
        (json['imageUrl'] ?? json['image']) as String?,
      ),
      title: (json['title'] ?? '').toString(),
      ctaLink: (json['ctaLink'] ?? '').toString(),
      bannerType: (json['bannerType'] ?? '').toString().trim().toLowerCase(),
      linkedRestaurantIds: ((json['linkedRestaurantIds'] as List?) ?? const [])
          .map((e) => e is Map ? (e['id'] ?? e['_id'] ?? '').toString() : e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      // A food banner whose dish is gone has linkedFood: null — no target.
      linkedFoodId: linkedFood == null
          ? null
          : (linkedFood['id'] ?? json['linkedFoodId'])?.toString(),
      linkedFoodRestaurantId: linkedFood?['restaurantId']?.toString(),
    );
  }
}
