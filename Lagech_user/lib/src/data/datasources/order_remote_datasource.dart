import 'package:flutter/foundation.dart';

import '../../core/config/api_config.dart';
import '../../core/error/failures.dart';
import '../../core/network/api_client.dart';
import '../models/cart_item_model.dart';
import '../models/food_model.dart';
import '../models/order_model.dart';
import '../models/order_pricing.dart';

/// Transport for cart sync and the order lifecycle.
class OrderRemoteDataSource {
  final ApiClient _client;

  const OrderRemoteDataSource(this._client);

  /// The server id of the variant the cart line named.
  ///
  /// Falls back to the name when the dish has no matching variant — the server
  /// will reject it either way, and a wrong id is no worse than the name that
  /// was being sent before, whereas an empty string would silently check out at
  /// the base price.
  static String _variantIdFor(FoodModel food, String variantName) {
    for (final v in food.variants) {
      if (v.name == variantName || v.id == variantName || v.serverId == variantName) {
        return v.id;
      }
    }
    return variantName;
  }

  /// Item payload shared by `/calculate` and `POST /orders`.
  ///
  /// `price` is the unit price *including* the chosen variant and add-ons, so
  /// the server's subtotal matches what the user was shown. Variant identity
  /// travels separately in `variantName` / `variantPrice`, which the order
  /// schema records on the line.
  static Map<String, dynamic> itemPayload(CartItemModel item) {
    final variantName =
        (item.selectedVariant != null && item.selectedVariant!.isNotEmpty)
            ? item.selectedVariant!
            : null;
    final hasVariant = variantName != null && variantName.isNotEmpty;
    final variantPrice = hasVariant
        ? (item.selectedVariantPrice > 0
            ? (item.food.price + item.selectedVariantPrice)
            : item.food.price)
        : item.food.price;

    final resolvedVariantId = hasVariant ? _variantIdFor(item.food, variantName) : null;

    return {
      'itemId': item.food.id,
      'name': item.food.name,
      // The unit price the user was actually shown/charged: base + variant +
      // add-ons. Sending the bare base price here was the bug — the server
      // bills off this field, so a base-only price silently dropped every
      // variant/add-on charge from the order regardless of what `variantPrice`
      // / `addons` below recorded for display.
      'price': item.unitPrice,
      'quantity': item.quantity,
      'itemTotal': item.totalPrice,
      'isVeg': item.food.isVeg,
      'image': item.food.imageUrl,
      if (hasVariant) ...{
        'variantId': resolvedVariantId,
        'variantName': variantName,
        'variantPrice': variantPrice,
      },
      if (item.selectedAddons.isNotEmpty) ...{
        'addons': item.selectedAddons,
        'addonsPrice': item.selectedAddonsPrice,
      },
      if (item.specialInstructions?.isNotEmpty ?? false)
        'notes': item.specialInstructions,
    };
  }

  /// `POST /food/orders/calculate` — the only source of truth for the bill.
  Future<OrderCalculation> calculate({
    required List<CartItemModel> items,
    required String restaurantId,
    String? deliveryAddressId,
    String? zoneId,
    String? couponCode,
    String deliveryMode = 'basic',
    DateTime? scheduledAt,
  }) async {
    final payload = {
      'items': items.map(itemPayload).toList(),
      'restaurantId': restaurantId,
      'deliveryAddressId': ?deliveryAddressId,
      'zoneId': ?zoneId,
      'couponCode': ?couponCode,
      'deliveryMode': deliveryMode,
      'scheduledAt': ?scheduledAt?.toUtc().toIso8601String(),
    };

    // Print Calculate API Request Payload
    // ignore: avoid_print
    print('[CALCULATE API REQUEST] URL: ${ApiPaths.orderCalculate}');
    // ignore: avoid_print
    print('[CART PAYLOAD] $payload');

    try {
      final data = await _client.post<Map<String, dynamic>>(
        ApiPaths.orderCalculate,
        body: payload,
      );
      // ignore: avoid_print
      print('[CALCULATE API RESPONSE] Status: 200/201 SUCCESS');
      // ignore: avoid_print
      print('[CART RESPONSE] $data');
      return OrderCalculation.fromApi(data);
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[CALCULATE API ERROR] order_remote_datasource.dart:L46 Error: $e');
      // ignore: avoid_print
      print('[CALCULATE API STACKTRACE] $stackTrace');
      rethrow;
    }
  }

  /// `POST /food/orders`. Echo back the exact `pricing` object `/calculate`
  /// returned — the server re-validates it.
  ///
  /// Returns `{ order, razorpay }`; `razorpay` is null for non-gateway methods.
  Future<Map<String, dynamic>> placeOrder({
    required List<CartItemModel> items,
    required String restaurantId,
    required String restaurantName,
    required Map<String, dynamic> address,
    required Map<String, dynamic> pricing,
    required String customerName,
    required String customerPhone,
    String paymentMethod = 'razorpay',
    String deliveryMode = 'basic',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
    String? zoneId,
  }) async {
    final payload = {
      'items': items.map(itemPayload).toList(),
      'address': address,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pricing': pricing,
      'paymentMethod': paymentMethod,
      'deliveryMode': deliveryMode,
      'note': ?note,
      'deliveryInstructions': ?deliveryInstructions,
      'sendCutlery': sendCutlery,
      'zoneId': ?zoneId,
    };

    // ignore: avoid_print
    print('[CHECKOUT PAYLOAD] $payload');

    try {
      final res = await _client.post<Map<String, dynamic>>(
        ApiPaths.orders,
        body: payload,
      );
      // ignore: avoid_print
      print('[CHECKOUT RESPONSE] $res');
      return res;
    } catch (e, stackTrace) {
      // ignore: avoid_print
      print('[CHECKOUT PLACE ORDER ERROR] Error: $e');
      // ignore: avoid_print
      print('[CHECKOUT PLACE ORDER STACKTRACE] $stackTrace');
      rethrow;
    }
  }

  /// `POST /food/orders/verify-payment` — all four fields required.
  ///
  /// Idempotent: an already-paid order returns success without reprocessing.
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return _client.post<Map<String, dynamic>>(
      ApiPaths.verifyPayment,
      body: {
        'orderId': orderId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
  }

  /// Call when the user dismisses the Razorpay sheet, so abandoned checkouts
  /// don't linger as ghost orders. Only valid while `pending_payment`.
  Future<void> discardPendingPayment(String orderId) async {
    await _client.delete<dynamic>(
      '${ApiPaths.orderById(orderId)}/pending-payment',
    );
  }

  Future<Map<String, dynamic>> getOrder(String orderId) =>
      _client.get<Map<String, dynamic>>(ApiPaths.orderById(orderId));

  /// Typed single order. `GET /food/orders/:orderId` → `{ order }`.
  Future<OrderModel> getOrderModel(String orderId) async {
    final cleanId = orderId.replaceFirst('#', '').trim();
    if (cleanId.isEmpty || cleanId == 'null' || cleanId == 'undefined') {
      final listResult = await getOrderModels(page: 1, limit: 1);
      if (listResult.orders.isNotEmpty) {
        return listResult.orders.first;
      }
      throw const NotFoundFailure('Order not found');
    }

    try {
      final data = await getOrder(cleanId);
      final parsed = OrderModel.fromApi(data);
      if (parsed.id.isNotEmpty) {
        return parsed;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GET ORDER MODEL DIRECT FAILED] ID $cleanId: $e');
    }

    // Fallback: search in user's recent orders list if direct fetch failed or gave empty id
    try {
      final listResult = await getOrderModels(page: 1, limit: 50);
      final match = listResult.orders.cast<OrderModel?>().firstWhere(
        (o) => o != null && (
          o.id == cleanId ||
          o.orderNumber == cleanId ||
          (o.orderNumber.isNotEmpty && cleanId.contains(o.orderNumber)) ||
          (cleanId.isNotEmpty && o.orderNumber.contains(cleanId))
        ),
        orElse: () => null,
      );
      if (match != null) {
        if (match.id.isNotEmpty && match.id != cleanId) {
          try {
            final directData = await getOrder(match.id);
            final directParsed = OrderModel.fromApi(directData);
            if (directParsed.id.isNotEmpty) return directParsed;
          } catch (_) {}
        }
        return match;
      }
      if (listResult.orders.isNotEmpty) {
        return listResult.orders.first;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[GET ORDER MODEL LIST FALLBACK FAILED] $e');
    }

    throw const NotFoundFailure('Order not found');
  }

  /// Live route for the tracking map: `GET /food/orders/:orderId/route`.
  ///
  /// Returns `{ polyline, distanceKm, durationMins, target, origin, destination }`.
  /// The origin is the rider's last known position, resolved server-side — this
  /// endpoint takes no coordinates from us. `target` is derived from the order
  /// phase ('restaurant' before pickup, 'customer' after), so the polyline is
  /// always the leg the rider is actually on.
  Future<Map<String, dynamic>> getRoute(String orderId) =>
      _client.get<Map<String, dynamic>>('${ApiPaths.orderById(orderId)}/route');

  /// Handover OTP the customer reads to the rider at the door.
  Future<String?> getDropOtp(String orderId) async {
    final data = await _client.get<Map<String, dynamic>>(
      '${ApiPaths.orderById(orderId)}/drop-otp',
    );
    return data['otp']?.toString();
  }

  /// `PATCH /food/orders/:orderId/ratings` — restaurantRating is required 1-5.
  Future<void> rateOrder({
    required String orderId,
    required int restaurantRating,
    int? deliveryPartnerRating,
    String? restaurantComment,
    String? deliveryPartnerComment,
    List<Map<String, dynamic>>? itemRatings,
  }) async {
    await _client.patch<dynamic>(
      '${ApiPaths.orderById(orderId)}/ratings',
      body: {
        'restaurantRating': restaurantRating,
        'deliveryPartnerRating': ?deliveryPartnerRating,
        'restaurantComment': ?restaurantComment,
        'deliveryPartnerComment': ?deliveryPartnerComment,
        if (itemRatings != null && itemRatings.isNotEmpty)
          'itemRatings': itemRatings,
      },
    );
  }

  /// `GET /food/orders` — `{ data: [...], meta: {...} }`
  Future<({List<OrderModel> orders, int totalPages, int totalOrders, int? activeCount, int? pastCount})> getOrderModels({
    int page = 1,
    int limit = 50,
  }) async {
    final result = await getOrders(page: page, limit: limit);
    final parsedOrders = <OrderModel>[];
    for (final raw in result.orders) {
      try {
        final order = OrderModel.fromApi(raw);
        if (order.id.isNotEmpty) {
          parsedOrders.add(order);
        }
      } catch (e, stack) {
        if (kDebugMode) debugPrint('[PARSE ORDER ERROR] $e\n$stack');
      }
    }
    return (
      orders: parsedOrders,
      totalPages: result.totalPages,
      totalOrders: result.totalOrders,
      activeCount: result.activeCount,
      pastCount: result.pastCount,
    );
  }

  Future<({List<Map<String, dynamic>> orders, int totalPages, int totalOrders, int? activeCount, int? pastCount})> getOrders({
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _client.get<dynamic>(
      ApiPaths.orders,
      query: {'page': page, 'limit': limit},
    );
    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      return (
        orders: list,
        totalPages: 1,
        totalOrders: list.length,
        activeCount: null,
        pastCount: null,
      );
    }
    final map = (data as Map).cast<String, dynamic>();

    List<Map<String, dynamic>> list = const [];
    if (map['data'] is List) {
      list = (map['data'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (map['orders'] is List) {
      list = (map['orders'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (map['items'] is List) {
      list = (map['items'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (map['results'] is List) {
      list = (map['results'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (map['docs'] is List) {
      list = (map['docs'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } else if (map['data'] is Map) {
      final inner = (map['data'] as Map).cast<String, dynamic>();
      if (inner['data'] is List) {
        list = (inner['data'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      } else if (inner['orders'] is List) {
        list = (inner['orders'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      } else if (inner['items'] is List) {
        list = (inner['items'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      } else if (inner['results'] is List) {
        list = (inner['results'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      } else if (inner['docs'] is List) {
        list = (inner['docs'] as List).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
      }
    }

    if (list.isEmpty) {
      for (final val in map.values) {
        if (val is List && val.isNotEmpty && val.first is Map) {
          list = val.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
          break;
        }
      }
    }

    final meta = (map['meta'] is Map ? (map['meta'] as Map).cast<String, dynamic>() : null) ??
        ((map['data'] is Map && (map['data'] as Map)['meta'] is Map)
            ? ((map['data'] as Map)['meta'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{});

    final totalOrders = (meta['total'] as num?)?.toInt() ??
        (meta['totalOrders'] as num?)?.toInt() ??
        (meta['count'] as num?)?.toInt() ??
        (map['total'] as num?)?.toInt() ??
        list.length;
    final activeCount = (meta['activeCount'] as num?)?.toInt();
    final pastCount = (meta['pastCount'] as num?)?.toInt();
    final totalPages = (meta['totalPages'] as num?)?.toInt() ?? (meta['pages'] as num?)?.toInt() ?? 1;

    return (
      orders: list,
      totalPages: totalPages,
      totalOrders: totalOrders,
      activeCount: activeCount,
      pastCount: pastCount,
    );
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _client.patch<dynamic>(
      '${ApiPaths.orderById(orderId)}/cancel',
      body: {'reason': ?reason},
    );
  }

  /// Cross-device cart continuity only — checkout reads the cart you send it,
  /// not this. Best-effort by design.
  Future<void> syncCart({
    required List<CartItemModel> items,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await _client.put<dynamic>(
      ApiPaths.cart,
      body: {
        'items': items
            .map(
              (i) => {
                'itemId': i.food.id,
                'name': i.food.name,
                'price': i.food.price,
                'quantity': i.quantity,
                'restaurantId': i.food.restaurantId,
              },
            )
            .toList(),
        'restaurantId': ?restaurantId,
        'restaurantName': ?restaurantName,
      },
    );
  }
}
