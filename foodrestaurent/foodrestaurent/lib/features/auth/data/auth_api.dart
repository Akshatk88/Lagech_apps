import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';

/// Thin wrapper around the raw `/food/auth/restaurant/*` + `/food/restaurant/current`
/// endpoints. Returns the already-unwrapped `data` payload (see the Dio
/// `onResponse` interceptor) as a `Map<String, dynamic>`.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _dio.post(
      '/food/auth/restaurant/request-otp',
      data: {'phone': phone},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
    String platform = 'mobile',
  }) async {
    final response = await _dio.post(
      '/food/auth/restaurant/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        'platform': platform,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// `POST /food/auth/restaurant/firebase-login` — the Firebase ID token from
  /// Firebase Phone Authentication instead of our OTP. Same response as
  /// verify-otp.
  Future<Map<String, dynamic>> firebaseLogin({
    required String idToken,
    String? fcmToken,
    String platform = 'mobile',
  }) async {
    final response = await _dio.post(
      '/food/auth/restaurant/firebase-login',
      data: {
        'idToken': idToken,
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
        'platform': platform,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getCurrentRestaurant() async {
    final response = await _dio.get('/food/restaurant/current');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> logout({String? refreshToken, String? fcmToken}) async {
    await _dio.post(
      '/food/auth/logout',
      data: {
        'refreshToken': refreshToken,
        'fcmToken': fcmToken,
        'platform': 'mobile',
      },
    );
  }

  /// `DELETE /food/restaurant/me` is the one delete route the server has (the two
  /// `/food/auth/...` paths this used to fall back to do not exist and return
  /// 404). Failures are the server's real answer and must reach the user as is,
  /// e.g. 400 "Restaurants with order history cannot be deleted. Please contact
  /// support."
  Future<void> deleteAccount() async {
    await _dio.delete('/food/restaurant/me');
  }
}

final authApiProvider = Provider<AuthApi>((ref) {
  return AuthApi(ref.watch(dioProvider));
});
