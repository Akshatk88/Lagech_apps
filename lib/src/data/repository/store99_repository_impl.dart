import '../../core/error/failures.dart';
import '../../core/network/api_response.dart';
import '../../domain/model/store99_brand.dart';
import '../../domain/model/store99_cuisine.dart';
import '../../domain/model/store99_product.dart';
import '../../domain/repository/store99_repository.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Backend-backed ₹99 store: every dish priced ₹99 or less.
///
/// The server applies the price cap (promo `switch99`), so the store holds the
/// whole catalog's cheap dishes. Fetching the newest 100/500 dishes and
/// filtering here dropped every older cheap one (1,681 dishes, 489 at ₹99).
class Store99RepositoryImpl implements Store99Repository {
  final CatalogRemoteDataSource _remote;
  final String? Function() _zoneId;
  final ({double lat, double lng})? Function() _latLng;

  const Store99RepositoryImpl(this._remote, this._zoneId, this._latLng);

  static const _promo = 'switch99'; // ₹99 or less, applied by the server
  static const _maxPrice = 99.0; // same cap, re-checked on what comes back
  static const _fetchLimit = 1000;

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
      final foods = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        promo: _promo,
        limit: _fetchLimit,
      );
      return foods.where((f) => f.price <= _maxPrice).map(_toProduct).toList();
    });
  }

  @override
  Future<ApiResponse<List<Store99Product>>> getExploreProducts({
    String cuisineId = 'all',
    int page = 1,
    int limit = 20,
  }) {
    return _guard(() async {
      // cuisineId is a category id (see getCuisines), so filter by id.
      final foods = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        categoryId: cuisineId == 'all' ? null : cuisineId,
        promo: _promo,
        limit: _fetchLimit,
      );

      final eligibleFoods = foods.where((f) => f.price <= _maxPrice).toList();

      // Client-side pagination on eligible products
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
      ratingCount: f.reviewCount,
      deliveryTime: f.deliveryTime,
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

