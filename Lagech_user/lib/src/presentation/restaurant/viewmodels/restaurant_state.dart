import '../../../data/models/food_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../../domain/model/restaurant_menu_category.dart';

/// Immutable presentation state for the Restaurant Details screen.
class RestaurantState {
  final RestaurantModel? restaurant;
  final List<FoodModel> allItems;
  final List<FoodModel> filteredItems;
  final List<RestaurantMenuCategory> categories;
  final String selectedCategoryId;
  final String searchQuery;
  final bool isVegOnly;
  final bool isNonVegOnly;
  final bool isMinRating4;
  final bool isBestSellerOnly;
  final bool isRatingSort;
  final bool isLoading;
  final String? errorMessage;

  const RestaurantState({
    this.restaurant,
    this.allItems = const [],
    this.filteredItems = const [],
    this.categories = const [],
    this.selectedCategoryId = 'all',
    this.searchQuery = '',
    this.isVegOnly = false,
    this.isNonVegOnly = false,
    this.isMinRating4 = false,
    this.isBestSellerOnly = false,
    this.isRatingSort = false,
    this.isLoading = false,
    this.errorMessage,
  });

  RestaurantState copyWith({
    RestaurantModel? restaurant,
    List<FoodModel>? allItems,
    List<FoodModel>? filteredItems,
    List<RestaurantMenuCategory>? categories,
    String? selectedCategoryId,
    String? searchQuery,
    bool? isVegOnly,
    bool? isNonVegOnly,
    bool? isMinRating4,
    bool? isBestSellerOnly,
    bool? isRatingSort,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RestaurantState(
      restaurant: restaurant ?? this.restaurant,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      isVegOnly: isVegOnly ?? this.isVegOnly,
      isNonVegOnly: isNonVegOnly ?? this.isNonVegOnly,
      isMinRating4: isMinRating4 ?? this.isMinRating4,
      isBestSellerOnly: isBestSellerOnly ?? this.isBestSellerOnly,
      isRatingSort: isRatingSort ?? this.isRatingSort,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
