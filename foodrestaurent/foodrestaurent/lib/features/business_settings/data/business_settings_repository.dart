import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/business_settings/domain/restaurant_business_settings.dart';

/// Admin-controlled Business Settings — public, no auth needed — see
/// `/food/public/business-settings`.
class BusinessSettingsRepository {
  BusinessSettingsRepository(this._dio);

  final Dio _dio;

  Future<RestaurantBusinessSettings> getRestaurantSettings() async {
    final response = await _dio.get('/food/public/business-settings');
    final data = Map<String, dynamic>.from(response.data as Map);
    return RestaurantBusinessSettings.fromJson(data);
  }
}

final businessSettingsRepositoryProvider =
    Provider<BusinessSettingsRepository>((ref) {
      return BusinessSettingsRepository(ref.watch(dioProvider));
    });

/// Kept for the app's lifetime and re-fetched on pull-to-refresh of the
/// orders screens. Read it as `.value ?? RestaurantBusinessSettings.fallback`
/// so a failed or pending load keeps the app's usual behaviour.
final restaurantBusinessSettingsProvider =
    FutureProvider<RestaurantBusinessSettings>((ref) {
      return ref.read(businessSettingsRepositoryProvider).getRestaurantSettings();
    });
