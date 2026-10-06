import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../models/business_settings_model.dart';

/// Transport for the public Business Settings endpoints. All unauthenticated.
class SettingsRemoteDataSource {
  final ApiClient _client;

  const SettingsRemoteDataSource(this._client);

  /// The admin can change these at any time, so the cached copy is short-lived;
  /// it is there to paint instantly at launch and to stand in when offline.
  static const _cacheTtl = Duration(minutes: 10);

  /// `GET /food/public/business-settings`.
  Future<BusinessSettings> getBusinessSettings({
    void Function(BusinessSettings)? onCache,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.publicBusinessSettings,
      auth: false,
      cacheTtl: _cacheTtl,
      onCache: onCache == null
          ? null
          : (cached) => onCache(BusinessSettings.fromApi(cached)),
    );
    return BusinessSettings.fromApi(data);
  }

  /// `GET /food/zones/payment-options` — what the order's zone accepts. Pass
  /// [restaurantId] at checkout: it resolves the same zone order placement does.
  Future<ZonePaymentOptions> getZonePaymentOptions({
    String? restaurantId,
    String? zoneId,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.zonePaymentOptions,
      query: {'restaurantId': restaurantId, 'zoneId': zoneId},
      auth: false,
    );
    return ZonePaymentOptions.fromApi(data);
  }

  /// `GET /food/public/offline-payment-methods`. Empty when the feature is
  /// switched off, so the caller never has to check `enabled` separately.
  Future<List<OfflinePaymentMethod>> getOfflinePaymentMethods() async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.offlinePaymentMethods,
      auth: false,
    );
    if (data['enabled'] != true) return const [];
    return ((data['methods'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => OfflinePaymentMethod.fromApi(e.cast<String, dynamic>()))
        .where((m) => m.id.isNotEmpty && m.name.isNotEmpty)
        .toList();
  }
}
