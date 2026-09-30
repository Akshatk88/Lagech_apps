import '../../core/network/api_response.dart';
import '../../data/models/food_model.dart';
import '../model/restaurant_menu_category.dart';
import '../repository/restaurant_repository.dart';

/// Business domain service for restaurant menu processing, category extraction, and filtering.
class RestaurantService {
  final RestaurantRepository _repository;

  RestaurantService(this._repository);

  Future<ApiResponse<List<FoodModel>>> getMenu(String restaurantId) {
    return _repository.getRestaurantMenu(restaurantId);
  }

  /// Dynamically extract categories from menu items using the real categories
  /// assigned by the restaurant/backend, with 'All' and 'Recommended' (if any popular dishes exist).
  List<RestaurantMenuCategory> extractCategories(List<FoodModel> items) {
    if (items.isEmpty) return const [];

    final result = <RestaurantMenuCategory>[];

    // 1. 'All' category
    result.add(RestaurantMenuCategory(id: 'all', name: 'All', itemCount: items.length));

    // 2. 'Recommended' category if any dishes are flagged popular
    final popularDishes = items.where((f) => f.isPopular).toList();
    if (popularDishes.isNotEmpty) {
      result.add(RestaurantMenuCategory(
        id: 'recommended',
        name: 'Recommended',
        itemCount: popularDishes.length,
      ));
    }

    // 3. Extract distinct restaurant categories in order of appearance
    final seen = <String>{};
    final categoryCounts = <String, int>{};
    final categoryNames = <String, String>{};
    final categoryOrder = <String>[];

    for (final item in items) {
      final rawName = item.categoryName.trim().isNotEmpty
          ? item.categoryName.trim()
          : (item.categoryId.trim().isNotEmpty ? item.categoryId.trim() : 'Menu');
      final normalizedId = rawName.toLowerCase();

      if (normalizedId == 'all' || normalizedId == 'recommended') continue;

      if (!seen.contains(normalizedId)) {
        seen.add(normalizedId);
        categoryOrder.add(normalizedId);
        categoryNames[normalizedId] = rawName;
      }
      categoryCounts[normalizedId] = (categoryCounts[normalizedId] ?? 0) + 1;
    }

    for (final id in categoryOrder) {
      result.add(RestaurantMenuCategory(
        id: id,
        name: categoryNames[id] ?? id,
        itemCount: categoryCounts[id] ?? 0,
      ));
    }

    return result;
  }

  /// Groups items by category preserving category order.
  Map<String, List<FoodModel>> groupByCategory(
    List<FoodModel> items,
    List<RestaurantMenuCategory> categories,
  ) {
    final map = <String, List<FoodModel>>{};
    for (final cat in categories) {
      if (cat.id == 'all') continue;
      if (cat.id == 'recommended') {
        final matched = items.where((f) => f.isPopular).toList();
        if (matched.isNotEmpty) map[cat.id] = matched;
        continue;
      }

      final matched = items.where((f) {
        final rawName = f.categoryName.trim().isNotEmpty
            ? f.categoryName.trim()
            : (f.categoryId.trim().isNotEmpty ? f.categoryId.trim() : 'Menu');
        return rawName.toLowerCase() == cat.id;
      }).toList();

      if (matched.isNotEmpty) map[cat.id] = matched;
    }

    // Safety fallback: if no category matched but items exist, show them under 'menu'
    if (map.isEmpty && items.isNotEmpty) {
      map['menu'] = items;
    }

    return map;
  }

  /// Filters food items based on query, selected category, veg/non-veg toggles, bestseller, and rating.
  List<FoodModel> filterMenu({
    required List<FoodModel> items,
    required String query,
    required String categoryId,
    required bool isVegOnly,
    required bool isNonVegOnly,
    required bool isMinRating4,
    bool isBestSellerOnly = false,
    bool isRatingSort = false,
  }) {
    var result = List<FoodModel>.from(items);

    // 1. Text Search Filter
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isNotEmpty) {
      result = result.where((f) {
        final matchesName = f.name.toLowerCase().contains(cleanQuery);
        final matchesDesc = f.description.toLowerCase().contains(cleanQuery);
        final matchesCat = f.categoryName.toLowerCase().contains(cleanQuery);
        return matchesName || matchesDesc || matchesCat;
      }).toList();
    }

    // 2. Category Filter
    if (categoryId != 'all') {
      if (categoryId == 'recommended') {
        result = result.where((f) => f.isPopular).toList();
      } else {
        result = result.where((f) {
          final rawName = f.categoryName.trim().isNotEmpty
              ? f.categoryName.trim()
              : (f.categoryId.trim().isNotEmpty ? f.categoryId.trim() : 'Menu');
          return rawName.toLowerCase() == categoryId.toLowerCase();
        }).toList();
      }
    }

    // 3. Veg / Non-Veg Toggle
    if (isVegOnly) {
      result = result.where((f) => f.isVeg).toList();
    } else if (isNonVegOnly) {
      result = result.where((f) => !f.isVeg).toList();
    }

    // 4. Rating Filter (4.0+)
    if (isMinRating4) {
      result = result.where((f) => f.rating >= 4.0).toList();
    }

    // 5. Best Seller Filter (bestselling dishes of this restaurant)
    if (isBestSellerOnly) {
      final popular = result.where((f) => f.isPopular).toList();
      if (popular.isNotEmpty) {
        result = popular;
      } else {
        final sorted = List<FoodModel>.from(result)
          ..sort((a, b) {
            final cmp = b.rating.compareTo(a.rating);
            if (cmp != 0) return cmp;
            return b.reviewCount.compareTo(a.reviewCount);
          });
        result = sorted.take((result.length * 0.6).ceil().clamp(1, result.length)).toList();
      }
    }

    // 6. Rating Sort (highest rated food displayed first)
    if (isRatingSort) {
      result.sort((a, b) {
        final cmp = b.rating.compareTo(a.rating);
        if (cmp != 0) return cmp;
        return b.reviewCount.compareTo(a.reviewCount);
      });
    }

    return result;
  }
}
