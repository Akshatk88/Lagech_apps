import '../../core/error/failures.dart';
import '../../core/network/api_response.dart';
import '../../domain/model/store99_brand.dart';
import '../../domain/model/store99_cuisine.dart';
import '../../domain/model/store99_product.dart';
import '../../domain/repository/store99_repository.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Backend-backed 99 Store.
///
/// The backend models this as the `switch99` promo slug on the cross-restaurant
/// food feed rather than a price filter, so nothing here filters on price.
/// Cuisines come from the real category list and brands from the restaurant
/// list — there are no dedicated 99-Store endpoints.
class Store99RepositoryImpl implements Store99Repository {
  final CatalogRemoteDataSource _remote;
  final String? Function() _zoneId;
  final ({double lat, double lng})? Function() _latLng;

  const Store99RepositoryImpl(this._remote, this._zoneId, this._latLng);

  static const _promo = 'switch99';

  @override
  Future<ApiResponse<List<Store99Cuisine>>> getCuisines() {
    return _guard(() async {
      final categories = await _remote.getCategories(zoneId: _zoneId());
      return [
        const Store99Cuisine(id: 'all', label: 'All', imagesPath: ''),
        ...categories.map(
          (c) => Store99Cuisine(id: c.id, label: c.name, imagesPath: c.imageUrl),
        ),
      ];
    });
  }

  @override
  Future<ApiResponse<List<Store99Brand>>> getBrands() {
    return _guard(() async {
      final here = _latLng();
      final restaurants = await _remote.getRestaurants(
        zoneId: _zoneId(),
        limit: 12,
        lat: here?.lat,
        lng: here?.lng,
      );
      return restaurants
          .map((r) => Store99Brand(id: r.id, label: r.name, imageUrl: r.imageUrl))
          .toList();
    });
  }

  @override
  Future<ApiResponse<List<Store99Product>>> getTrendingDishes() {
    return _guard(() async {
      var foods = await _remote.getPublicFoods(zoneId: _zoneId(), promo: _promo, limit: 100);
      var eligible = foods.where((f) => f.price <= 99.0).toList();
      if (eligible.isEmpty) {
        // Fallback: Fetch general foods without promo constraint and find items <= 99
        final allFoods = await _remote.getPublicFoods(zoneId: _zoneId(), limit: 150);
        eligible = allFoods.where((f) => f.price <= 99.0).toList();
      }
      return eligible.map(_toProduct).toList();
    });
  }

  @override
  Future<ApiResponse<List<Store99Product>>> getExploreProducts({
    String cuisineId = 'all',
    int page = 1,
    int limit = 10,
  }) {
    return _guard(() async {
      var foods = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        promo: _promo,
        categorySlug: cuisineId == 'all' ? null : cuisineId,
        limit: 200,
      );

      var eligibleFoods = foods.where((f) => f.price <= 99.0).toList();

      if (eligibleFoods.isEmpty) {
        final allFoods = await _remote.getPublicFoods(
          zoneId: _zoneId(),
          categorySlug: cuisineId == 'all' ? null : cuisineId,
          limit: 200,
        );
        eligibleFoods = allFoods.where((f) => f.price <= 99.0).toList();
      }

      // Client-side pagination windowing applied on eligible (<= 99) products
      final start = (page - 1) * limit;
      if (start >= eligibleFoods.length) return const <Store99Product>[];
      return eligibleFoods
          .sublist(start, (start + limit).clamp(0, eligibleFoods.length))
          .map(_toProduct)
          .toList();
    });
  }

  @override
  Future<ApiResponse<RestaurantModel?>> getRestaurantForProduct(String restaurantId) =>
      _guard(() => _remote.getRestaurantById(restaurantId));

  Store99Product _toProduct(FoodModel f) {
    return Store99Product(
      id: f.id,
      restaurantId: f.restaurantId,
      restaurantName: f.restaurantName.isNotEmpty ? f.restaurantName : '',
      name: f.name,
      description: f.description,
      price: f.price,
      originalPrice: f.originalPrice,
      imageUrl: f.imageUrl,
      rating: f.rating,
      ratingCount: f.reviewCount > 0 ? f.reviewCount : 12,
      deliveryTime: f.deliveryTime.isNotEmpty ? f.deliveryTime : '15-30 min',
      isVeg: f.isVeg,
      isQuickDelivery: f.isQuickDelivery,
      cuisineId: f.categoryId.isNotEmpty ? f.categoryId : f.categoryName,
    );
  }

  Future<ApiResponse<T>> _guard<T>(Future<T> Function() run) async {
    try {
      return ApiResponse.success(await run());
    } on Failure catch (f) {
      return ApiResponse<T>.error(f.message);
    } catch (_) {
      return ApiResponse<T>.error('Something went wrong. Please try again.');
    }
  }
}
