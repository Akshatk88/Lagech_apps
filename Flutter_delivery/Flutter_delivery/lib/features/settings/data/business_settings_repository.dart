import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// The rider-facing slice of the admin's business settings
/// (`GET /food/public/business-settings` → `data.rider`).
///
/// Every field defaults to what the app did before these settings existed, so
/// a failed or partial response never changes behaviour.
class RiderBusinessSettings {
  const RiderBusinessSettings({
    this.showEarning = true,
    this.canCancelOrder = false,
    this.maxAssignedOrders,
    this.selfRegistration = true,
    this.otpProvider = 'firebase',
  });

  /// Show the rider's earning on incoming offers.
  final bool showEarning;

  /// Whether riders may cancel an accepted order. The app has no rider cancel
  /// action today, so this is carried for completeness only.
  final bool canCancelOrder;

  /// Admin's "Maximum assigned order limit". Informational — the live limit
  /// the app acts on comes from `/orders/current` (`orderLimit`).
  final int? maxAssignedOrders;

  /// `rider.selfRegistration` — new riders may sign up from the app. When
  /// false `POST /food/delivery/register` answers 403 and the app sends a new
  /// number back to login instead of the sign-up form.
  final bool selfRegistration;

  /// `login.otpProvider` — `firebase` (Firebase Phone Authentication, the
  /// default, also when the server does not say) or `sms` (our SMS OTP).
  final String otpProvider;

  bool get useFirebaseOtp => otpProvider != 'sms';

  static const defaults = RiderBusinessSettings();

  factory RiderBusinessSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return RiderBusinessSettings(
      showEarning: json['showEarning'] is bool
          ? json['showEarning'] as bool
          : defaults.showEarning,
      canCancelOrder: json['canCancelOrder'] is bool
          ? json['canCancelOrder'] as bool
          : defaults.canCancelOrder,
      maxAssignedOrders: (json['maxAssignedOrders'] as num?)?.toInt(),
      selfRegistration: json['selfRegistration'] is bool
          ? json['selfRegistration'] as bool
          : defaults.selfRegistration,
      otpProvider: json['otpProvider'] == 'sms' ? 'sms' : 'firebase',
    );
  }

  Map<String, dynamic> toJson() => {
        'showEarning': showEarning,
        'canCancelOrder': canCancelOrder,
        'maxAssignedOrders': ?maxAssignedOrders,
        'selfRegistration': selfRegistration,
        'otpProvider': otpProvider,
      };

  @override
  bool operator ==(Object other) =>
      other is RiderBusinessSettings &&
      other.showEarning == showEarning &&
      other.canCancelOrder == canCancelOrder &&
      other.maxAssignedOrders == maxAssignedOrders &&
      other.selfRegistration == selfRegistration &&
      other.otpProvider == otpProvider;

  @override
  int get hashCode => Object.hash(
        showEarning,
        canCancelOrder,
        maxAssignedOrders,
        selfRegistration,
        otpProvider,
      );
}

class BusinessSettingsRepository {
  BusinessSettingsRepository(this._dio);

  final Dio _dio;

  Future<Result<RiderBusinessSettings, AppError>> getRiderSettings() async {
    try {
      final res = await _dio.get(ApiEndpoints.businessSettings);
      final body = res.data;
      final data = body is Map<String, dynamic> ? body['data'] : null;
      final rider = data is Map<String, dynamic> ? data['rider'] : null;
      if (rider is! Map<String, dynamic>) {
        return Result.failure(NetworkError('Business settings unavailable'));
      }
      // `login` sits beside `rider`; the OTP provider is carried in the same
      // object so it is cached with the rest.
      final login = data['login'];
      return Result.success(RiderBusinessSettings.fromJson({
        ...rider,
        if (login is Map) 'otpProvider': login['otpProvider'],
      }));
    } on DioException catch (_) {
      return Result.failure(NetworkError('Business settings unavailable'));
    } catch (_) {
      return Result.failure(UnknownError('Business settings unavailable'));
    }
  }
}

final businessSettingsRepositoryProvider =
    Provider<BusinessSettingsRepository>((ref) {
  return BusinessSettingsRepository(ref.read(dioProvider));
});
