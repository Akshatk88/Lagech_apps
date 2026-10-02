import '../../core/error/failures.dart';
import '../../core/network/api_response.dart';
import '../../domain/repository/restaurant_repository.dart';
import '../datasources/catalog_remote_datasource.dart';
import '../models/category_model.dart';
import '../models/food_model.dart';
import '../models/restaurant_model.dart';

/// Backend-backed catalog repository.
///
/// [zoneIdProvider] is a callback rather than a value so every call picks up
/// the zone detected after location permission, without this repository being
/// rebuilt or holding a stale id.
class RestaurantRepositoryImpl implements RestaurantRepository {
  final CatalogRemoteDataSource _remote;
  final String? Function() _zoneId;

  /// Callback for the same reason as [_zoneId]: coordinates resolve after
  /// location permission, and without them the backend omits distanceInKm — so
  /// every restaurant card renders with no distance at all.
  final ({double lat, double lng})? Function() _latLng;

  const RestaurantRepositoryImpl(this._remote, this._zoneId, this._latLng);

  @override
  Future<ApiResponse<List<CategoryModel>>> getCategories({
    void Function(List<CategoryModel>)? onCache,
  }) =>
      _guard(() => _remote.getCategories(zoneId: _zoneId(), onCache: onCache));

  @override
  Future<ApiResponse<List<CategoryModel>>> getExploreIcons() =>
      _guard(() => _remote.getExploreIcons());

  @override
  Future<ApiResponse<List<RestaurantModel>>> getFeaturedRestaurants() =>
      _guard(() {
        final here = _latLng();
        return _remote.getRestaurants(
          zoneId: _zoneId(),
          sortBy: 'rating',
          limit: 20,
          lat: here?.lat,
          lng: here?.lng,
        );
      });

  @override
  Future<ApiResponse<List<RestaurantModel>>> getPopularRestaurants({
    void Function(List<RestaurantModel>)? onCache,
  }) => _guard(() {
    final here = _latLng();
    return _remote.getRestaurants(
      zoneId: _zoneId(),
      limit: 50,
      onCache: onCache,
      lat: here?.lat,
      lng: here?.lng,
    );
  });

  @override
  Future<ApiResponse<List<FoodModel>>> getRestaurantMenu(String restaurantId) =>
      _guard(() => _remote.getRestaurantMenu(restaurantId));

  @override
  Future<ApiResponse<List<FoodModel>>> getPopularFoods({
    void Function(List<FoodModel>)? onCache,
  }) => _guard(
    () => _remote.getPublicFoods(
      zoneId: _zoneId(),
      limit: 5000,
      onCache: onCache,
    ),
  );

  @override
  Future<ApiResponse<List<FoodModel>>> getFoodsByCategory(
    String categoryId, {
    void Function(List<FoodModel>)? onCache,
    String? categoryName,
    String? realCategoryId,
  }) => _guard(
    () async {
      final categoryParam = (categoryName != null && categoryName.trim().isNotEmpty)
          ? categoryName.trim()
          : categoryId.trim();

      final res = await _remote.getPublicFoods(
        zoneId: _zoneId(),
        limit: 5000,
        categorySlug: categoryParam,
        categoryId: realCategoryId,
        categoryName: categoryParam,
        onCache: onCache,
      );
      return res;
    },
  );

  @override
  Future<ApiResponse<List<RestaurantModel>>> getRestaurantsByCategory(
    CategoryModel category,
  ) => _guard(() async {
    final here = _latLng();
    // 1. Query unified search by categoryId (matches dishes filed under this category)
    if (category.id.isNotEmpty) {
      final results = await _remote.search(
        '',
        categoryId: category.id,
        zoneId: _zoneId(),
        lat: here?.lat,
        lng: here?.lng,
        limit: 50,
      );
      if (results.isNotEmpty) return results;
    }

    // 2. Query unified search by category name (cuisine or dish keyword match)
    if (category.name.isNotEmpty) {
      final nameResults = await _remote.search(
        category.name,
        zoneId: _zoneId(),
        lat: here?.lat,
        lng: here?.lng,
        limit: 50,
      );
      if (nameResults.isNotEmpty) return nameResults;
    }

    return <RestaurantModel>[];
  });

  /// The ₹99 rail — returns only foods where final selling price <= 99
  @override
  Future<ApiResponse<List<FoodModel>>> getBestOffers({
    void Function(List<FoodModel>)? onCache,
  }) => _guard(() async {
    bool eligible(FoodModel f) => f.price <= 99.0;
    final foods = await _remote.getPublicFoods(
      zoneId: _zoneId(),
      promo: 'switch99',
      onCache: onCache == null
          ? null
          : (cached) => onCache(cached.where(eligible).toList()),
    );
    return foods.where(eligible).toList();
  });

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
