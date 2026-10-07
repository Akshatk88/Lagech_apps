import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/collect_payment.dart';
import 'models/delivery_order.dart';

class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  Future<Result<List<DeliveryOrder>, AppError>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.ordersAvailable,
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = res.data['data'];
      final list = (data is Map<String, dynamic> ? data['data'] : data)
          as List<dynamic>?;
      final orders = (list ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DeliveryOrder.fromJson)
          .toList();
      return Result.success(orders);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// `GET /orders/current`. Newer backends also return `activeOrders` (every
  /// delivery the rider holds, most recently updated first), `orderLimit`
  /// and `canAcceptMore`; older ones only `activeOrder`, in which case the
  /// list falls back to `[activeOrder]` and the capacity fields stay null.
  Future<Result<CurrentTrip, AppError>> getCurrentTrip() async {
    try {
      final res = await _dio.get(ApiEndpoints.ordersCurrent);
      final data = res.data['data'] as Map<String, dynamic>?;
      final rawActive = data?['activeOrder'];
      final activeOrder = rawActive is Map<String, dynamic>
          ? DeliveryOrder.fromJson(rawActive)
          : null;

      final rawList = data?['activeOrders'];
      final List<DeliveryOrder> activeOrders;
      if (rawList is List) {
        activeOrders = rawList
            .whereType<Map<String, dynamic>>()
            .map(DeliveryOrder.fromJson)
            .toList();
        // Defensive: never lose the order the old field reports.
        if (activeOrder != null &&
            !activeOrders.any((o) => o.id == activeOrder.id)) {
          activeOrders.insert(0, activeOrder);
        }
      } else {
        activeOrders = activeOrder != null ? [activeOrder] : <DeliveryOrder>[];
      }

      final canAcceptMore = data?['canAcceptMore'];
      return Result.success(
        CurrentTrip(
          activeOrder: activeOrder,
          activeOrders: activeOrders,
          orderLimit: (data?['orderLimit'] as num?)?.toInt(),
          canAcceptMore: canAcceptMore is bool ? canAcceptMore : null,
        ),
      );
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> getOrderDetails(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.orderDetails(orderId));
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> accept(String orderId) =>
      _patchOrder(ApiEndpoints.orderAccept(orderId));

  /// Declines an offer, or cancels an accepted delivery (admin-permitted,
  /// before pickup only). [reason] is sent only when given, so declining an
  /// offer still sends no body.
  Future<Result<DeliveryOrder, AppError>> reject(
    String orderId, {
    String? reason,
  }) => _patchOrder(
    ApiEndpoints.orderReject(orderId),
    data: reason != null ? {'reason': reason} : null,
  );

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _patchOrder(
    ApiEndpoints.orderConfirmPickup(orderId),
    data: billImageUrl != null ? {'billImageUrl': billImageUrl} : null,
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.orderVerifyDropOtp(orderId),
        data: {'otp': otp},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> complete(String orderId) =>
      _patchOrder(ApiEndpoints.orderComplete(orderId));

  Future<Result<Map<String, dynamic>, AppError>> collectQr(
    String orderId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.collectQr(orderId),
        data: {
          'name': ?name,
          'email': ?email,
          'phone': ?phone,
        },
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> paymentStatus(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.paymentStatus(orderId));
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> getRoute(
    String orderId, {
    required double lat,
    required double lng,
    required String target,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.orderRoute(orderId),
        queryParameters: {'lat': lat, 'lng': lng, 'target': target},
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const Result.success(<String, dynamic>{
          'polyline': '',
          'durationMins': 0,
        });
      }
      return Result.failure(_mapError(e));
    }
  }

  /// `POST /orders/:id/collect/qr`: a Razorpay QR for what the customer owes
  /// at the door (an open one is handed back rather than a second raised).
  Future<Result<CollectQr, AppError>> createCollectQr(String orderId) async {
    try {
      final res = await _dio.post(ApiEndpoints.collectQr(orderId));
      final data = res.data['data'];
      if (data is! Map<String, dynamic>) {
        return Result.failure(NetworkError('Could not create the QR. Please try again.'));
      }
      return Result.success(CollectQr.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// `GET /orders/:id/payment-status`. Safe to poll every few seconds.
  Future<Result<CollectPaymentStatus, AppError>> getPaymentStatus(String orderId) async {
    try {
      final res = await _dio.get(ApiEndpoints.paymentStatus(orderId));
      final data = res.data['data'];
      if (data is! Map<String, dynamic>) {
        return Result.failure(NetworkError('Could not read the payment status.'));
      }
      return Result.success(CollectPaymentStatus.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<bool, AppError>> collectCash(String orderId) async {
    try {
      final res = await _dio.post(ApiEndpoints.collectCash(orderId));
      final data = res.data['data'] as Map<String, dynamic>?;
      return Result.success(data?['success'] as bool? ?? true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Backend completes and locks cash orders during /complete endpoint
        return const Result.success(true);
      }
      return Result.failure(_mapError(e));
    } catch (e) {
      return const Result.success(true);
    }
  }

  Future<Result<bool, AppError>> rateCustomer(
    String orderId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.orderRateCustomer(orderId),
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return Result.success(res.data['success'] as bool? ?? true);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 ||
          e.response?.statusCode == 405 ||
          e.response?.statusCode == 501) {
        // Backend doesn't support customer rating from driver - treat gracefully as success
        return const Result.success(true);
      }
      return Result.failure(_mapError(e));
    } catch (_) {
      return const Result.success(true);
    }
  }

  Future<Result<DeliveryOrder, AppError>> _patchOrder(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      final body = res.data['data'] as Map<String, dynamic>;
      final order = body['order'] ?? body;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    if (responseData is Map<String, dynamic>) {
      final message = responseData['message'] as String? ??
          responseData['error'] as String?;
      if (message != null && message.trim().isNotEmpty) {
        return NetworkError(message);
      }
    }
    if (e.response?.statusCode == 404) {
      return NetworkError('Not found');
    }
    return NetworkError('Something went wrong. Please try again.');
  }
}

/// Parsed `GET /orders/current` response.
class CurrentTrip {
  const CurrentTrip({
    required this.activeOrder,
    required this.activeOrders,
    this.orderLimit,
    this.canAcceptMore,
  });

  /// Most recent active delivery (legacy single-order field).
  final DeliveryOrder? activeOrder;

  /// Every delivery the rider currently holds, most recently updated first.
  final List<DeliveryOrder> activeOrders;

  /// Admin's live "Maximum assigned order limit"; null on older backends.
  final int? orderLimit;

  /// Whether the rider may take another order; null on older backends.
  final bool? canAcceptMore;
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.read(dioProvider));
});
