import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/failures.dart';
import '../../../data/models/order_model.dart';
import '../../../data/models/order_options_model.dart';
import '../../../data/models/order_pricing.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';
import '../../../di/order_providers.dart';
import '../../../di/payment_providers.dart';
import '../../../di/settings_providers.dart';
import '../../../platform/payment/payment_gateway.dart';
import '../../auth/viewmodels/auth_viewmodel.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../home/viewmodels/zone_viewmodel.dart';

import '../../orders/viewmodels/active_order_viewmodel.dart';
import '../../orders/viewmodels/orders_viewmodel.dart';
import '../../wallet/viewmodels/pay_later_viewmodel.dart';
import '../../wallet/viewmodels/wallet_viewmodel.dart';

class CheckoutState {
  final OrderCalculation? calculation;
  final bool isCalculating;
  final String? error;

  /// Coupon the user typed. Echoed back by the server even when rejected, so
  /// [OrderPricing.hasCouponApplied] is what decides whether it actually landed.
  final String? couponCode;
  final String deliveryMode;
  final String? addressId;
  final bool priceChangesAccepted;

  /// `delivery` (default) or `takeaway`.
  final String orderType;

  /// The slot picked under "Schedule"; null means "Now".
  final ScheduleSlot? scheduledSlot;

  /// Tip for the delivery partner in rupees; 0 for none. Delivery only.
  final double riderTip;

  const CheckoutState({
    this.calculation,
    this.isCalculating = false,
    this.error,
    this.couponCode,
    this.deliveryMode = 'basic',
    this.addressId,
    this.priceChangesAccepted = false,
    this.orderType = 'delivery',
    this.scheduledSlot,
    this.riderTip = 0,
  });

  OrderPricing? get pricing => calculation?.pricing;

  bool get isTakeaway => orderType == 'takeaway';

  /// Blocks order submission until the user acknowledges menu price drift.
  bool get needsPriceConfirmation =>
      (calculation?.hasPriceChanges ?? false) && !priceChangesAccepted;

  bool get couponRejected =>
      (couponCode?.isNotEmpty ?? false) && !(pricing?.hasCouponApplied ?? false);

  CheckoutState copyWith({
    OrderCalculation? calculation,
    bool? isCalculating,
    String? error,
    String? couponCode,
    String? deliveryMode,
    String? addressId,
    bool? priceChangesAccepted,
    String? orderType,
    ScheduleSlot? scheduledSlot,
    double? riderTip,
    bool clearError = false,
    bool clearCoupon = false,
    bool clearSchedule = false,
  }) {
    return CheckoutState(
      calculation: calculation ?? this.calculation,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      deliveryMode: deliveryMode ?? this.deliveryMode,
      addressId: addressId ?? this.addressId,
      priceChangesAccepted: priceChangesAccepted ?? this.priceChangesAccepted,
      orderType: orderType ?? this.orderType,
      scheduledSlot:
          clearSchedule ? null : (scheduledSlot ?? this.scheduledSlot),
      riderTip: riderTip ?? this.riderTip,
    );
  }
}

final checkoutViewModelProvider =
    NotifierProvider<CheckoutViewModel, CheckoutState>(CheckoutViewModel.new);

/// Owns the bill.
///
/// Every figure shown at checkout comes from `POST /food/orders/calculate` —
/// nothing is summed client-side. Recalculates whenever the cart, coupon,
/// address or delivery mode changes.
class CheckoutViewModel extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Any cart mutation invalidates the server bill.
    ref.listen(cartViewModelProvider, (previous, next) {
      if (previous?.items.length != next.items.length ||
          previous?.totalQuantity != next.totalQuantity) {
        unawaited(recalculate());
      }
    });

    // Schedule initial recalculation on build if cart is not empty.
    Future.microtask(() {
      final cart = ref.read(cartViewModelProvider);
      if (cart.items.isNotEmpty) {
        unawaited(recalculate());
      }
    });

    return const CheckoutState();
  }

  Future<void> setAddress(String? addressId) async {
    state = state.copyWith(addressId: addressId);
    await recalculate();
  }

  Future<void> setDeliveryMode(String mode) async {
    state = state.copyWith(deliveryMode: mode);
    await recalculate();
  }

  /// Delivery or takeaway. Takeaway carries no rider tip.
  Future<void> setOrderType(String type) async {
    if (type == state.orderType) return;
    state = state.copyWith(
      orderType: type,
      riderTip: type == 'takeaway' ? 0 : null,
    );
    await recalculate();
  }

  /// A slot from the restaurant's order options, or null for "Now".
  Future<void> setScheduledSlot(ScheduleSlot? slot) async {
    if (slot?.scheduledAt == state.scheduledSlot?.scheduledAt) return;
    state = slot == null
        ? state.copyWith(clearSchedule: true)
        : state.copyWith(scheduledSlot: slot);
    await recalculate();
  }

  Future<void> setRiderTip(double tip) async {
    if (tip == state.riderTip) return;
    state = state.copyWith(riderTip: tip < 0 ? 0 : tip);
    await recalculate();
  }

  /// Keeps the order type, slot and tip within what the restaurant's order
  /// options allow: takeaway is preselected when it is the only type, and a
  /// choice that is no longer offered falls back to the default.
  Future<void> applyOrderOptions(RestaurantOrderOptions options) async {
    var type = state.orderType;
    if (options.takeawayOnly) {
      type = 'takeaway';
    } else if (type == 'takeaway' && !options.takeaway) {
      type = 'delivery';
    }
    final slot = state.scheduledSlot;
    final keepSlot = slot != null &&
        options.schedule.enabled &&
        options.schedule.offers(slot.scheduledAt);
    var tip = state.riderTip;
    if (type == 'takeaway' || !options.tips.usable) {
      tip = 0;
    } else if (tip > options.tips.max) {
      tip = options.tips.max;
    }
    if (type == state.orderType &&
        (keepSlot || slot == null) &&
        tip == state.riderTip) {
      return;
    }
    state = state.copyWith(
      orderType: type,
      riderTip: tip,
      clearSchedule: !keepSlot,
    );
    await recalculate();
  }

  Future<void> applyCoupon(String code) async {
    state = state.copyWith(couponCode: code.trim().toUpperCase());
    await recalculate();
    // ignore: avoid_print
    print(
      '[COUPON] code=${state.couponCode} '
      'applied=${state.pricing?.hasCouponApplied} '
      'discount=${state.pricing?.discount} '
      'total=${state.pricing?.total}',
    );
  }

  Future<void> removeCoupon() async {
    state = state.copyWith(clearCoupon: true);
    await recalculate();
    // ignore: avoid_print
    print('[COUPON] removed, total=${state.pricing?.total}');
  }

  /// Re-fetches the server bill for the current cart and options.
  Future<void> recalculate() async {
    final cart = ref.read(cartViewModelProvider);
    if (cart.items.isEmpty) {
      // A new cart starts from the defaults: delivery, now, no tip.
      state = state.copyWith(
        calculation: null,
        isCalculating: false,
        clearError: true,
        orderType: 'delivery',
        riderTip: 0,
        clearSchedule: true,
      );
      return;
    }

    final restaurantId = cart.items.first.food.restaurantId;
    if (restaurantId.isEmpty) {
      state = state.copyWith(
        isCalculating: false,
        error: 'This item is missing its restaurant. Please re-add it to the cart.',
      );
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final calculation = await ref.read(orderRemoteDataSourceProvider).calculate(
            items: cart.items,
            restaurantId: restaurantId,
            deliveryAddressId: state.addressId,
            zoneId: ref.read(currentZoneIdProvider),
            couponCode: state.couponCode,
            deliveryMode: state.deliveryMode,
            scheduledAt: state.scheduledSlot?.scheduledAt,
            orderType: state.orderType,
            riderTip: state.isTakeaway ? 0 : state.riderTip,
          );
      var priced = calculation;
      // An older backend does not send paymentOptions with the quote; ask the
      // zone directly. Failing that, nothing is hidden (today's behaviour) and
      // the server's own 400 explains a refused method.
      if (priced.paymentOptions == null) {
        try {
          final options = await ref
              .read(settingsRemoteDataSourceProvider)
              .getZonePaymentOptions(restaurantId: restaurantId);
          priced = priced.withPaymentOptions(options);
        } catch (_) {}
      }
      state = state.copyWith(
        calculation: priced,
        isCalculating: false,
        priceChangesAccepted: false,
      );
    } on Failure catch (f) {
      state = state.copyWith(isCalculating: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isCalculating: false, error: 'Could not calculate your bill.');
    }
  }

  /// Accepts updated prices after the user confirms.
  Future<void> acceptPriceChanges() async {
    state = state.copyWith(priceChangesAccepted: true);
  }

  /// Places the order. Returns `{ order, razorpay }` on success.
  ///
  /// Refuses to submit while price drift is unacknowledged.
  Future<({Map<String, dynamic>? result, String? error})> placeOrder({
    required Map<String, dynamic>? address,
    required String customerName,
    required String customerPhone,
    required String restaurantName,
    String paymentMethod = 'razorpay',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
    Map<String, dynamic>? offlinePayment,
    double? partialWalletAmount,
  }) async {
    final cart = ref.read(cartViewModelProvider);
    final pricing = state.pricing;

    if (cart.items.isEmpty) return (result: null, error: 'Your cart is empty.');

    try {
      final restaurantId = cart.items.first.food.restaurantId;
      final here = await ref.read(userLatLngProvider.future);
      final restaurant = await ref.read(catalogRemoteDataSourceProvider).getRestaurantById(
            restaurantId,
            lat: here?.lat,
            lng: here?.lng,
            forceRefresh: true,
          );
      if (restaurant != null && !restaurant.isOpen) {
        return (
          result: null,
          error: '${restaurant.name} is currently closed and not accepting orders.',
        );
      }
    } catch (_) {}

    if (pricing == null) return (result: null, error: 'Bill not ready. Please try again.');
    if (state.needsPriceConfirmation) {
      return (result: null, error: 'Item prices changed. Please review before ordering.');
    }

    try {
      final result = await ref.read(orderRemoteDataSourceProvider).placeOrder(
            items: cart.items,
            restaurantId: cart.items.first.food.restaurantId,
            restaurantName: restaurantName,
            address: address,
            // Echo the server's own pricing object back verbatim.
            pricing: pricing.raw,
            customerName: customerName,
            customerPhone: customerPhone,
            paymentMethod: paymentMethod,
            deliveryMode: state.deliveryMode,
            note: note,
            deliveryInstructions: deliveryInstructions,
            sendCutlery: sendCutlery,
            zoneId: ref.read(currentZoneIdProvider),
            offlinePayment: offlinePayment,
            partialWalletAmount: partialWalletAmount,
            orderType: state.orderType,
            scheduledAt: state.scheduledSlot?.scheduledAt,
            riderTip: state.isTakeaway ? 0 : state.riderTip,
          );
      return (result: result, error: null);
    } on Failure catch (f) {
      // A refusal can come from a switch the admin just flipped (maintenance,
      // a payment method or a zone's COD/online switch): reload the settings
      // and the quote so the screen catches up with what the server said.
      if (f is ValidationFailure) {
        unawaited(ref.read(businessSettingsProvider.notifier).refresh());
        // ...and the restaurant's order options: a slot may have closed.
        ref.invalidate(
          restaurantOrderOptionsProvider(cart.items.first.food.restaurantId),
        );
        unawaited(recalculate());
      }
      return (result: null, error: f.message);
    } catch (_) {
      return (result: null, error: 'Could not place your order. Please try again.');
    }
  }

  /// Places the order and drives payment to completion in one call.
  ///
  /// This is the whole checkout tail: `POST /orders` → Razorpay sheet →
  /// `verify-payment`. There is no intermediate in-app payment page; Razorpay's
  /// own sheet is the single payment surface, so it is opened directly from
  /// "Proceed to Payment".
  ///
  /// Clears the cart only once the payment has actually settled (success or
  /// webhook-pending), never on a cancellation or a hard failure.
  ///
  /// [partialWalletAmount] pays that much from the wallet and the rest with
  /// [paymentMethod] (`razorpay` or `cash`); the Razorpay sheet then charges
  /// only the rest. Abandoning the sheet discards the order and the server
  /// puts the wallet part back.
  Future<PaymentFlowResult> payAndPlaceOrder({
    // Null only for a takeaway order with no saved address.
    required Map<String, dynamic>? address,
    required String restaurantName,
    String paymentMethod = 'razorpay',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
    Map<String, dynamic>? offlinePayment,
    double? partialWalletAmount,
  }) async {
    final user = ref.read(authViewModelProvider).value;
    final customerName = user?.displayName ?? 'Customer';
    final customerPhone = user?.phone ?? '';

    final placed = await placeOrder(
      address: address,
      customerName: customerName,
      customerPhone: customerPhone,
      restaurantName: restaurantName,
      paymentMethod: paymentMethod,
      note: note,
      deliveryInstructions: deliveryInstructions,
      sendCutlery: sendCutlery,
      offlinePayment: offlinePayment,
      partialWalletAmount: partialWalletAmount,
    );

    // A partial payment took (or, refused, did not take) the wallet part:
    // show the balance the server now holds.
    if (partialWalletAmount != null) _refreshWallet();

    if (placed.error != null) {
      return PaymentFlowResult(outcome: PaymentOutcome.failed, message: placed.error!);
    }

    Map<String, dynamic>? orderMap;
    if (placed.result is Map) {
      final res = placed.result!;
      if (res['order'] is Map) {
        orderMap = (res['order'] as Map).cast<String, dynamic>();
      } else if (res['data'] is Map) {
        final inner = (res['data'] as Map).cast<String, dynamic>();
        if (inner['order'] is Map) {
          orderMap = (inner['order'] as Map).cast<String, dynamic>();
        } else {
          orderMap = inner;
        }
      } else {
        orderMap = res;
      }
    }
    final orderId = (orderMap?['_id'] ?? orderMap?['id'] ?? orderMap?['orderId'] ?? orderMap?['orderMongoId'] ?? '').toString();

    OrderModel? createdOrderModel;
    if (orderMap != null && orderMap.isNotEmpty) {
      try {
        createdOrderModel = OrderModel.fromApi(orderMap);
      } catch (_) {}
    }

    // For non-gateway payment methods (Cash on Delivery, LAGECH Wallet, Pay
    // Later and offline payment — the last waits for the admin to verify it)
    if (paymentMethod == 'cash' ||
        paymentMethod == 'wallet' ||
        paymentMethod == 'pay_later' ||
        paymentMethod == 'offline') {
      ref.read(cartViewModelProvider.notifier).clearCart();
      if (createdOrderModel != null && createdOrderModel.id.isNotEmpty) {
        ref.read(activeOrderViewModelProvider.notifier).setActiveOrderDirectly(createdOrderModel);
        ref.read(ordersViewModelProvider.notifier).prependOrderDirectly(createdOrderModel);
      }
      unawaited(
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true),
      );
      unawaited(
        ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true),
      );
      // The due amount just changed server-side — refresh so the payment
      // sheet's remaining-credit figure isn't stale on the next checkout.
      if (paymentMethod == 'pay_later') {
        unawaited(ref.read(payLaterViewModelProvider.notifier).refresh());
      }
      return PaymentFlowResult(
        outcome: PaymentOutcome.success,
        message: switch (paymentMethod) {
          'cash' when partialWalletAmount != null =>
            'Order placed: ₹${partialWalletAmount.toStringAsFixed(0)} from your wallet, the rest in cash 🎉',
          'cash' => 'Order placed with Cash on Delivery 🎉',
          'pay_later' => 'Order placed on Pay Later 🎉',
          'offline' => 'Order placed. Your payment is being verified.',
          _ => 'Order paid successfully using LAGECH Wallet 🎉',
        },
        orderId: orderId,
      );
    }

    final razorpay = placed.result?['razorpay'] as Map<String, dynamic>?;

    final payment = await ref.read(paymentGatewayProvider).payForOrder(
          orderId: orderId,
          razorpay: razorpay,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: user?.email,
        );

    final settled = payment.isSuccess || payment.outcome == PaymentOutcome.pending;
    if (settled) {
      ref.read(cartViewModelProvider.notifier).clearCart();
      OrderModel? paidOrder = createdOrderModel;
      if (payment.order != null) {
        try {
          final fromVerified = OrderModel.fromApi(payment.order!);
          if (fromVerified.id.isNotEmpty) {
            paidOrder = fromVerified;
          }
        } catch (_) {}
      }
      if (paidOrder != null && paidOrder.id.isNotEmpty) {
        ref.read(activeOrderViewModelProvider.notifier).setActiveOrderDirectly(paidOrder);
        ref.read(ordersViewModelProvider.notifier).prependOrderDirectly(paidOrder);
      }
      unawaited(
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true),
      );
      unawaited(
        ref.read(ordersViewModelProvider.notifier).refresh(isRefresh: true),
      );
    } else if (payment.outcome == PaymentOutcome.cancelled && orderId.isNotEmpty) {
      // Don't leave a ghost `pending_payment` order behind when the user backs
      // out of the sheet.
      // The server puts a partial payment's wallet part back as it discards.
      unawaited(
        ref
            .read(orderRemoteDataSourceProvider)
            .discardPendingPayment(orderId)
            .catchError((_) {})
            .whenComplete(() {
              if (partialWalletAmount != null) _refreshWallet();
            }),
      );
    }

    return PaymentFlowResult(
      outcome: payment.outcome,
      message: payment.message,
      orderId: orderId,
    );
  }

  void _refreshWallet() {
    unawaited(ref.read(walletViewModelProvider.notifier).loadWallet(isRefresh: true));
  }
}

/// Outcome of the combined place-order + pay sequence.
class PaymentFlowResult {
  final PaymentOutcome outcome;
  final String message;
  final String? orderId;

  const PaymentFlowResult({
    required this.outcome,
    required this.message,
    this.orderId,
  });

  /// True when the order exists and payment either succeeded or is awaiting the
  /// webhook — both cases should land the user on order tracking.
  bool get isPlaced =>
      outcome == PaymentOutcome.success || outcome == PaymentOutcome.pending;

  bool get isCancelled => outcome == PaymentOutcome.cancelled;
}
