import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/repository/favorites_repository.dart';
import '../datasources/favorites_remote_datasource.dart';

/// Favorites store with backend sync and SharedPreferences fallback.
class FavoritesRepositoryImpl implements FavoritesRepository {
  static const _keyRestaurant = 'favorite_restaurant_ids';
  static const _keyFood = 'favorite_food_ids';

  final FavoritesRemoteDataSource? _remote;

  const FavoritesRepositoryImpl([this._remote]);

  @override
  Future<Set<String>> getFavoriteIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRestaurant)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveFavoriteIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyRestaurant, ids.toList());
  }

  @override
  Future<Set<String>> getFavoriteFoodIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyFood)?.toSet() ?? <String>{};
  }

  @override
  Future<void> saveFavoriteFoodIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_keyFood, ids.toList());
  }

  @override
  Future<void> toggleFavoriteRestaurant(String restaurantId, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyRestaurant)?.toSet() ?? <String>{};

    if (isFavorite) {
      ids.add(restaurantId);
    } else {
      ids.remove(restaurantId);
    }

    // Save locally FIRST
    await prefs.setStringList(_keyRestaurant, ids.toList());

    if (_remote != null) {
      try {
        await _remote.toggleFavoriteRestaurant(restaurantId, isFavorite);
      } catch (e) {
        developer.log(
          '[FAVORITE] [Repository Error] Toggle restaurant failed for ID: $restaurantId | Action: ${isFavorite ? "ADD" : "REMOVE"} | Error: $e',
          name: 'FAVORITE',
        );
        // Do not rethrow, allow offline usage
      }
    }
  }

  @override
  Future<void> toggleFavoriteFood(String foodId, bool isFavorite) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_keyFood)?.toSet() ?? <String>{};

    if (isFavorite) {
      ids.add(foodId);
    } else {
      ids.remove(foodId);
    }

    // Save locally FIRST
    await prefs.setStringList(_keyFood, ids.toList());

    if (_remote != null) {
      try {
        await _remote.toggleFavoriteFood(foodId, isFavorite);
      } catch (e) {
        developer.log(
          '[FAVORITE] [Repository Error] Toggle food failed for ID: $foodId | Action: ${isFavorite ? "ADD" : "REMOVE"} | Error: $e',
          name: 'FAVORITE',
        );
        // Do not rethrow, allow offline usage
      }
    }
  }

  @override
  Future<FavoritesResponse?> getRemoteFavorites() async {
    if (_remote == null) return null;
    try {
      final res = await _remote.getFavorites();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyRestaurant, res.restaurantIds.toList());
      await prefs.setStringList(_keyFood, res.foodIds.toList());
      return res;
    } catch (e) {
      developer.log('[FAVORITE] Repository getRemoteFavorites Error: $e', name: 'FAVORITE');
      return null;
    }
  }

  @override
  Future<void> syncWithBackend() async {
    await getRemoteFavorites();
  }

  @override
  Future<void> clearLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyRestaurant);
    await prefs.remove(_keyFood);
  }
}
