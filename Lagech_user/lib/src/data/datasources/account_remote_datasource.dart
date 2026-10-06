import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/token_storage.dart';
import '../models/user_model.dart';
import '../models/wallet_model.dart';

/// Wallet, referrals, notification inbox and FCM registration — the
/// account-scoped endpoints under `/food/user`, `/food/notifications` and
/// `/fcm-tokens`. All Bearer-only.
class AccountRemoteDataSource {
  final ApiClient _client;
  final TokenStorage _tokens;

  const AccountRemoteDataSource(this._client, this._tokens);

  // --------------------------------------------------------------- wallet

  Future<WalletModel> getWallet() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.wallet);
    final wallet = data['wallet'];
    return WalletModel.fromApi(
      wallet is Map ? wallet.cast<String, dynamic>() : data,
    );
  }

  /// Creates a Razorpay order for a top-up. `amount` in the response is paise.
  Future<Map<String, dynamic>> createTopupOrder(double amount) async {
    final data = await _client.post<Map<String, dynamic>>(
      '${ApiPaths.wallet}/topup/order',
      body: {'amount': amount},
    );
    return ((data['razorpay'] as Map?) ?? const {}).cast<String, dynamic>();
  }

  /// Idempotent — re-verifying a completed top-up returns the wallet unchanged
  /// rather than double-crediting. `bonus` is the running top-up offer the
  /// server credited alongside it, or null (always null on a replay).
  Future<TopupVerification> verifyTopup({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      '${ApiPaths.wallet}/topup/verify',
      body: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
        'amount': amount,
      },
    );
    final wallet = data['wallet'];
    return TopupVerification(
      wallet: WalletModel.fromApi(
        wallet is Map ? wallet.cast<String, dynamic>() : data,
      ),
      bonus: TopupBonus.fromApi(data['bonus']),
    );
  }

  /// Top-up bonus offers running now — shown on the add-money sheet.
  Future<List<WalletBonusOffer>> getWalletBonuses() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.walletBonuses);
    return WalletBonusOffer.listFromApi(data);
  }

  // -------------------------------------------------------- loyalty points

  Future<LoyaltyPoints> getLoyaltyPoints({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.loyaltyPoints,
      query: {'page': page, 'limit': limit},
    );
    return LoyaltyPoints.fromApi(data);
  }

  /// Converts [points] into wallet balance. [requestId] makes the call
  /// idempotent — a retry with the same id converts nothing more.
  Future<({LoyaltyPoints loyalty, WalletModel? wallet})> convertLoyaltyPoints({
    required int points,
    required String requestId,
  }) async {
    final data = await _client.post<Map<String, dynamic>>(
      ApiPaths.loyaltyPointsConvert,
      body: {'points': points, 'requestId': requestId},
    );
    final wallet = data['wallet'];
    return (
      loyalty: LoyaltyPoints.fromApi(data),
      wallet: wallet is Map ? WalletModel.fromApi(wallet.cast<String, dynamic>()) : null,
    );
  }

  // ------------------------------------------------------------ pay later

  Future<PayLaterAccount> getPayLaterAccount() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.payLater);
    return PayLaterAccount.fromApi(
      (data['payLater'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  Future<PayLaterAccount> repayPayLaterFromWallet() async {
    await _client.post<Map<String, dynamic>>(ApiPaths.payLaterRepayWallet);
    return getPayLaterAccount();
  }

  /// Creates a Razorpay order for the current due. `amount` in the response is paise.
  Future<Map<String, dynamic>> startPayLaterRazorpayRepayment() async {
    final data = await _client.post<Map<String, dynamic>>(ApiPaths.payLaterRepayRazorpayStart);
    return data;
  }

  Future<PayLaterAccount> verifyPayLaterRazorpayRepayment({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await _client.post<Map<String, dynamic>>(
      ApiPaths.payLaterRepayRazorpayVerify,
      body: {
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    return getPayLaterAccount();
  }

  Future<CashbackHistory> getCashbackHistory({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.cashbackHistory,
      query: {'page': page, 'limit': limit},
    );
    return CashbackHistory.fromApi(data);
  }

  Future<RefundHistory> getRefundHistory({int page = 1, int limit = 20}) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.refundHistory,
      query: {'page': page, 'limit': limit},
    );
    return RefundHistory.fromApi(data);
  }

  /// No auth required, but the shared client attaches the token when a
  /// session exists — harmless either way.
  Future<CashbackSettings> getCashbackSettings() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.cashbackSettings, auth: false);
    return CashbackSettings.fromApi(data);
  }

  // ------------------------------------------------------------ referrals

  Future<ReferralDetails> getReferralDetails() async {
    final data = await _client.get<Map<String, dynamic>>(ApiPaths.referralDetails);
    return ReferralDetails.fromApi(data);
  }

  // -------------------------------------------------------- notifications

  Future<({List<AppNotification> items, int unreadCount, int totalPages})> getInbox({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _client.get<Map<String, dynamic>>(
      ApiPaths.notificationInbox,
      query: {'page': page, 'limit': limit},
    );
    final items = ((data['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => AppNotification.fromApi(e.cast<String, dynamic>()))
        .toList();
    // Notifications use `pagination`, unlike orders (`meta`) and restaurants
    // (flat `total`). Three envelopes exist across this API.
    final pagination = (data['pagination'] as Map?)?.cast<String, dynamic>() ?? const {};
    return (
      items: items,
      unreadCount: (data['unreadCount'] as num?)?.toInt() ?? 0,
      totalPages: (pagination['totalPages'] as num?)?.toInt() ?? 1,
    );
  }

  Future<void> markRead(String id) async {
    await _client.patch<dynamic>('${ApiPaths.notificationInbox.replaceAll('/inbox', '')}/$id/read');
  }

  Future<void> deleteNotification(String id) async {
    await _client.delete<dynamic>('${ApiPaths.notificationInbox.replaceAll('/inbox', '')}/$id');
  }

  Future<void> clearInbox() async {
    await _client.delete<dynamic>('${ApiPaths.notificationInbox}/all');
  }

  // ------------------------------------------------------------ fcm token

  /// Mobile variant — POST /api/v1/fcm-tokens/mobile/save
  Future<bool> saveFcmToken(String token, {UserModel? user}) async {
    final url = '${ApiConfig.baseUrl}${ApiPaths.fcmSaveMobile}';
    final jwt = await _tokens.accessToken;
    final bodyMap = {'token': token, 'platform': 'mobile'};
    final headersStr = 'Authorization: Bearer ${jwt ?? "NULL"}, Content-Type: application/json';
    final authHeaderStr = 'Bearer ${jwt ?? "NULL"}';

    // Step 4: Login details
    if (user != null) {
      debugPrint('''
[FCM] Logged In User Details:
User ID: ${user.id}
JWT Token: ${jwt ?? "NULL"}
Phone Number: ${user.phone}''');
    }

    // Step 5: Backend Request details
    debugPrint('''
[FCM] Sending token to backend...
Request URL: POST $url
Headers: $headersStr
Authorization Header: $authHeaderStr
Body: ${jsonEncode(bodyMap)}
Token: $token''');

    if (jwt == null || jwt.isEmpty) {
      debugPrint('[FCM] User not logged in yet. Token cached locally and will be synced upon login.');
      return false;
    }

    try {
      final res = await _client.raw.post<dynamic>(
        ApiPaths.fcmSaveMobile,
        data: bodyMap,
        options: Options(
          headers: {
            'Authorization': 'Bearer $jwt',
            'Content-Type': 'application/json',
          },
        ),
      );

      final statusCode = res.statusCode ?? 0;
      final responseBody = jsonEncode(res.data);
      final responseHeaders = res.headers.map;

      // Step 6: Backend Response
      debugPrint('''
[FCM] Backend Response:
Status Code: $statusCode
Response Body: $responseBody
Headers: $responseHeaders''');

      if (statusCode >= 200 && statusCode < 300) {
        // Step 9: Success log
        debugPrint('[FCM] FCM Token Saved Successfully');
        return true;
      } else {
        // Step 8: Authorization check
        if (statusCode == 401 || statusCode == 403) {
          debugPrint('''
[FCM] Authorization Failed
JWT Token: $jwt
Expiry: N/A
Current User: ${user?.id ?? "Guest"}''');
        }

        // Step 7: Request Failure log
        debugPrint('''
[FCM] ERROR Saving Token
Exception: HTTP $statusCode
StackTrace: N/A
Response Body: $responseBody
Status Code: $statusCode''');
        return false;
      }
    } catch (e, st) {
      // Step 7: Exception log
      debugPrint('''
[FCM] ERROR Saving Token
Exception: $e
StackTrace: $st
Response Body: N/A
Status Code: 500''');
      return false;
    }
  }

  Future<void> removeFcmToken(String token) async {
    await _client.delete<dynamic>(
      ApiPaths.fcmRemove,
      body: {'token': token, 'platform': 'mobile'},
    );
  }
}
