import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../di/restaurant_providers.dart';
import '../../../di/location_providers.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../data/models/food_model.dart';
import '../../../data/models/zone_model.dart';
import '../../../domain/repository/restaurant_repository.dart';
import 'zone_viewmodel.dart';

class HomeState {
  final AsyncValue<List<CategoryModel>> categories;
  final AsyncValue<List<FoodModel>> popularFoods;
  final AsyncValue<List<FoodModel>> bestOffers;
  final AsyncValue<List<RestaurantModel>> nearbyRestaurants;

  /// Admin-picked restaurants from `?recommended=true`. An empty list (or a
  /// failed call) means the home row falls back to [nearbyRestaurants].
  final List<RestaurantModel> recommendedRestaurants;

  HomeState({
    required this.categories,
    required this.popularFoods,
    required this.bestOffers,
    required this.nearbyRestaurants,
    this.recommendedRestaurants = const [],
  });

  HomeState copyWith({
    AsyncValue<List<CategoryModel>>? categories,
    AsyncValue<List<FoodModel>>? popularFoods,
    AsyncValue<List<FoodModel>>? bestOffers,
    AsyncValue<List<RestaurantModel>>? nearbyRestaurants,
    List<RestaurantModel>? recommendedRestaurants,
  }) {
    return HomeState(
      categories: categories ?? this.categories,
      popularFoods: popularFoods ?? this.popularFoods,
      bestOffers: bestOffers ?? this.bestOffers,
      nearbyRestaurants: nearbyRestaurants ?? this.nearbyRestaurants,
      recommendedRestaurants: recommendedRestaurants ?? this.recommendedRestaurants,
    );
  }
}

final homeViewModelProvider = NotifierProvider<HomeViewModel, HomeState>(() {
  return HomeViewModel();
});

class HomeViewModel extends Notifier<HomeState> {
  RestaurantRepository get _repository => ref.read(restaurantRepositoryProvider);

  @override
  HomeState build() {
    ref.watch(restaurantRepositoryProvider);

    // Reactively refresh when zone or location changes
    ref.listen(currentZoneIdProvider, (previous, next) {
      if (previous != next) {
        loadHomeData(isRefresh: true);
      }
    });

    ref.listen(userLatLngProvider, (previous, next) {
      if (previous?.value != next.value && next.value != null) {
        loadHomeData(isRefresh: true);
      }
    });

    Future.microtask(() => loadHomeData());
    return HomeState(
      categories: const AsyncValue.loading(),
      popularFoods: const AsyncValue.loading(),
      bestOffers: const AsyncValue.loading(),
      nearbyRestaurants: const AsyncValue.loading(),
    );
  }

  Future<void> loadHomeData({
    bool isRefresh = false,
    String? categoryId,
  }) async {
    if (!isRefresh) {
      state = state.copyWith(
        categories: const AsyncValue.loading(),
        popularFoods: const AsyncValue.loading(),
        bestOffers: const AsyncValue.loading(),
        nearbyRestaurants: const AsyncValue.loading(),
      );
    }

    // First resolve the user's location and detected admin zone
    await Future.wait([
      ref.read(userLatLngProvider.future).catchError((_) => null),
      ref.read(zoneViewModelProvider.future).catchError((_) => ZoneModel.unknown),
    ]);

    // Each onCache fires synchronously, right here, with whatever's still
    // cached from the last fetch — paints the screen instantly instead of a
    // spinner, and gets overwritten below once the live response lands.
    final responses = await Future.wait([
      _repository.getCategories(
        onCache: (c) => state = state.copyWith(categories: AsyncValue.data(c)),
      ),
      categoryId != null
          ? _repository.getFoodsByCategory(
              categoryId,
              onCache: (f) =>
                  state = state.copyWith(popularFoods: AsyncValue.data(f)),
            )
          : _repository.getPopularFoods(
              onCache: (f) =>
                  state = state.copyWith(popularFoods: AsyncValue.data(f)),
            ),
      _repository.getBestOffers(
        onCache: (f) => state = state.copyWith(bestOffers: AsyncValue.data(f)),
      ),
      _repository.getPopularRestaurants(
        onCache: (r) =>
            state = state.copyWith(nearbyRestaurants: AsyncValue.data(r)),
      ), // mapping popular to nearby
      _repository.getRecommendedRestaurants(
        onCache: (r) => state = state.copyWith(recommendedRestaurants: r),
      ),
    ]);

    final categoriesRes = responses[0] as dynamic;
    final popularFoodsRes = responses[1] as dynamic;
    final bestOffersRes = responses[2] as dynamic;
    final nearbyRes = responses[3] as dynamic;
    final recommendedRes = responses[4] as dynamic;

    state = state.copyWith(
      categories: categoriesRes.isSuccess
          ? AsyncValue.data(categoriesRes.data)
          : AsyncValue.error(
              categoriesRes.message ?? 'Unknown error',
              StackTrace.current,
            ),
      popularFoods: popularFoodsRes.isSuccess
          ? AsyncValue.data(popularFoodsRes.data)
          : AsyncValue.error(
              popularFoodsRes.message ?? 'Unknown error',
              StackTrace.current,
            ),
      bestOffers: bestOffersRes.isSuccess
          ? AsyncValue.data(bestOffersRes.data)
          : AsyncValue.error(
              bestOffersRes.message ?? 'Unknown error',
              StackTrace.current,
            ),
      nearbyRestaurants: nearbyRes.isSuccess
          ? AsyncValue.data(nearbyRes.data)
          : AsyncValue.error(
              nearbyRes.message ?? 'Unknown error',
              StackTrace.current,
            ),
      // Failure is treated as "none picked" so the row falls back silently.
      recommendedRestaurants: recommendedRes.isSuccess
          ? List<RestaurantModel>.from((recommendedRes.data as List?) ?? const [])
          : const <RestaurantModel>[],
    );
  }

  Future<void> fetchFoodsByCategory(
    String categoryId, {
    String? categoryName,
    String? realCategoryId,
  }) async {
    state = state.copyWith(popularFoods: const AsyncValue.loading());
    final res = await _repository.getFoodsByCategory(
      categoryId,
      categoryName: categoryName,
      realCategoryId: realCategoryId,
      onCache: (f) => state = state.copyWith(popularFoods: AsyncValue.data(f)),
    );
    state = state.copyWith(
      popularFoods: res.isSuccess
          ? AsyncValue.data(res.data!)
          : AsyncValue.error(
              res.message ?? 'Unknown error',
              StackTrace.current,
            ),
    );
  }

  Future<void> fetchPopularFoods() async {
    state = state.copyWith(popularFoods: const AsyncValue.loading());
    final res = await _repository.getPopularFoods();
    state = state.copyWith(
      popularFoods: res.isSuccess
          ? AsyncValue.data(res.data!)
          : AsyncValue.error(
              res.message ?? 'Unknown error',
              StackTrace.current,
            ),
    );
  }
}
