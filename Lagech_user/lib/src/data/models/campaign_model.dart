import '../../core/config/api_config.dart';

/// Restaurant summary embedded in a campaign.
class CampaignRestaurant {
  final String id;
  final String name;
  final String logo;
  final String coverImage;
  final String area;
  final double rating;
  final int totalRatings;
  final bool isAcceptingOrders;

  const CampaignRestaurant({
    required this.id,
    this.name = '',
    this.logo = '',
    this.coverImage = '',
    this.area = '',
    this.rating = 0,
    this.totalRatings = 0,
    this.isAcceptingOrders = true,
  });

  factory CampaignRestaurant.fromApi(Map<String, dynamic> json) {
    return CampaignRestaurant(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      logo: ApiConfig.resolveMedia(json['logo']?.toString()),
      coverImage: ApiConfig.resolveMedia(json['coverImage']?.toString()),
      area: (json['area'] ?? '').toString(),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalRatings: (json['totalRatings'] as num?)?.toInt() ?? 0,
      isAcceptingOrders: json['isAcceptingOrders'] as bool? ?? true,
    );
  }

  static CampaignRestaurant? maybeFromApi(Object? raw) {
    if (raw is! Map) return null;
    final r = CampaignRestaurant.fromApi(raw.cast<String, dynamic>());
    return r.id.isEmpty ? null : r;
  }
}

/// One running campaign from `GET /food/public/campaigns`.
///
/// `basic` campaigns are a banner with participating [restaurants] (possibly
/// none); `food` campaigns promote one dish of one restaurant, priced
/// [price] → [finalPrice]. Food campaigns aren't orderable through checkout
/// yet, so tapping either kind opens a restaurant.
class CampaignModel {
  final String id;
  final bool isFood;
  final String title;
  final String description;
  final String image;
  final List<CampaignRestaurant> restaurants;

  /// Food campaigns only.
  final double price;
  final double finalPrice;
  final String discountType;
  final double discount;

  const CampaignModel({
    required this.id,
    required this.isFood,
    this.title = '',
    this.description = '',
    this.image = '',
    this.restaurants = const [],
    this.price = 0,
    this.finalPrice = 0,
    this.discountType = '',
    this.discount = 0,
  });

  bool get hasDiscount => isFood && price > 0 && finalPrice > 0 && finalPrice < price;

  factory CampaignModel.fromApi(Map<String, dynamic> json, {required bool isFood}) {
    final restaurants = isFood
        ? [CampaignRestaurant.maybeFromApi(json['restaurant'])].whereType<CampaignRestaurant>().toList()
        : ((json['restaurants'] as List?) ?? const [])
            .map(CampaignRestaurant.maybeFromApi)
            .whereType<CampaignRestaurant>()
            .toList();
    return CampaignModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      isFood: isFood,
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      image: ApiConfig.resolveMedia(json['image']?.toString()),
      restaurants: restaurants,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      finalPrice: (json['finalPrice'] as num?)?.toDouble() ?? 0.0,
      discountType: (json['discountType'] ?? '').toString(),
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// `{ basic, food }` flattened, food dishes first. Campaigns with no title
  /// and no image have nothing to show and are dropped.
  static List<CampaignModel> listFromApi(Map<String, dynamic> json) {
    List<CampaignModel> parse(Object? raw, bool isFood) => ((raw as List?) ?? const [])
        .whereType<Map>()
        .map((e) => CampaignModel.fromApi(e.cast<String, dynamic>(), isFood: isFood))
        .where((c) => c.title.trim().isNotEmpty || c.image.isNotEmpty)
        .toList();
    return [...parse(json['food'], true), ...parse(json['basic'], false)];
  }
}
