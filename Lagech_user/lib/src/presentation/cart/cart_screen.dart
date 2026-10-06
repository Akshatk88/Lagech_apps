import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../../data/models/cart_item_model.dart';
import '../../data/models/order_pricing.dart';
import '../../data/models/restaurant_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../address/viewmodels/address_viewmodel.dart';
import '../../data/models/address_model.dart';
import '../../di/catalog_providers.dart';
import '../../di/location_providers.dart';
import 'viewmodels/cart_viewmodel.dart';
import '../checkout/viewmodels/checkout_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../wallet/viewmodels/pay_later_viewmodel.dart';
import '../restaurant/widgets/food_detail_sheet.dart';
import 'widgets/cart_recommendations_section.dart';
import 'widgets/coupon_sheet.dart';
import 'widgets/empty_cart_view.dart';
import '../../../generated/l10n/app_localizations.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final GlobalKey _cartItemsCardKey = GlobalKey();

  // State for interactive UI elements
  String? _cookingRequest;
  bool _isBillExpanded = false;
  bool _isProcessing = false;
  bool _noCutlery = false;
  // Values are the API's own payment method strings, so they can be sent as-is.
  // This used to be 'cod', which the backend never accepted -- the enum is
  // razorpay | razorpay_qr | card | wallet | cash -- so the COD button always failed.
  String _selectedPaymentMethod = 'razorpay'; // 'razorpay' | 'cash' | 'wallet'
  String? _selectedAddressId;

  @override
  void initState() {
    super.initState();
    // Freshly check restaurant availability when opening the cart screen
    Future.microtask(() {
      final items = ref.read(cartViewModelProvider).items;
      if (items.isNotEmpty) {
        final rid = items.first.food.restaurantId;
        ref.invalidate(restaurantByIdProvider(rid));
      }
    });
  }

  AddressModel? _resolveSelectedAddress() {
    final addresses = ref.read(addressViewModelProvider);
    if (addresses.isEmpty) return null;
    if (_selectedAddressId != null) {
      for (final a in addresses) {
        if (a.id == _selectedAddressId) return a;
      }
    }
    for (final a in addresses) {
      if (a.isDefault) return a;
    }
    return addresses.first;
  }

  String get _customerName =>
      ref.read(authViewModelProvider).value?.displayName ?? 'Customer';
  String get _customerPhone => ref.read(authViewModelProvider).value?.phone ?? '';

  Future<String> _restaurantNameForCart(List<CartItemModel> items) async {
    if (items.isEmpty) return '';
    final id = items.first.food.restaurantId;
    final restaurant = await ref.read(restaurantByIdProvider(id).future);
    return restaurant?.name ?? '';
  }

  Future<void> _proceedToPayment() async {
    // Guard set immediately (before any await) so a fast double-tap can't
    // launch a second overlapping submission while the first is still
    // resolving address/pricing — that race left a stale `context` behind
    // for the error SnackBar and crashed with "deactivated widget's ancestor".
    if (_isProcessing) return;
    Haptics.light();
    setState(() => _isProcessing = true);
    try {
      final isLoggedIn = ref.read(authViewModelProvider).value != null;
      if (!isLoggedIn) {
        context.push(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.cart)}',
        );
        return;
      }

      // Guard against placing orders for closed / offline restaurants
      final cartItems = ref.read(cartViewModelProvider).items;
      if (cartItems.isNotEmpty) {
        final restaurantId = cartItems.first.food.restaurantId;
        final here = await ref.read(userLatLngProvider.future);
        final restaurant = await ref.read(catalogRemoteDataSourceProvider).getRestaurantById(
          restaurantId,
          lat: here?.lat,
          lng: here?.lng,
          forceRefresh: true,
        );
        if (restaurant != null && !restaurant.isOpen) {
          if (!mounted) return;
          AppSnackbar.error(
            context,
            '${restaurant.name} is currently closed and not accepting orders.',
          );
          return;
        }
      }

      var address = _resolveSelectedAddress();
      if (address == null) {
        // Empty could mean "genuinely no saved address" or "the last load
        // attempt failed" (e.g. a timeout) — retry once so a transient
        // failure doesn't get mistaken for having no address at all.
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        if (addressNotifier.error != null) {
          await addressNotifier.load();
          address = _resolveSelectedAddress();
        }
      }
      if (address == null) {
        final addressNotifier = ref.read(addressViewModelProvider.notifier);
        final loadFailed = addressNotifier.error != null;
        final hasSavedAddress = ref.read(addressViewModelProvider).isNotEmpty;
        if (!mounted) return;
        AppSnackbar.error(
          context,
          loadFailed
              ? AppLocalizations.of(context)!.couldNotLoadAddress
              : hasSavedAddress
              ? AppLocalizations.of(context)!.pleaseSelectDeliveryAddress
              : AppLocalizations.of(context)!.addDeliveryAddressToProceed,
        );
        // With nothing saved, the picker would just be an empty list.
        if (!loadFailed && !hasSavedAddress) {
          unawaited(_openAddAddressScreen());
        } else {
          _showAddressSelectionBottomSheet(context);
        }
        return;
      }

      var checkoutState = ref.read(checkoutViewModelProvider);
      if (checkoutState.addressId != address.id) {
        await ref
            .read(checkoutViewModelProvider.notifier)
            .setAddress(address.id);
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      if (checkoutState.pricing == null || checkoutState.isCalculating) {
        await ref.read(checkoutViewModelProvider.notifier).recalculate();
        checkoutState = ref.read(checkoutViewModelProvider);
      }

      final pricing = checkoutState.pricing;
      if (pricing == null) {
        if (!mounted) return;
        AppSnackbar.error(
          context,
          checkoutState.error ??
              AppLocalizations.of(context)!.couldNotCalculateBill,
        );
        return;
      }

      if (checkoutState.needsPriceConfirmation) {
        await ref.read(checkoutViewModelProvider.notifier).acceptPriceChanges();
      }

      // LAGECH Wallet balance validation
      if (_selectedPaymentMethod == 'wallet') {
        final walletState = ref.read(walletViewModelProvider);
        final walletBalance = walletState.wallet.balance;
        final totalToPay = pricing.total;
        if (walletBalance < totalToPay) {
          if (!mounted) return;
          AppSnackbar.warning(
            context,
            AppLocalizations.of(context)!.insufficientWalletBalance(
              '₹${walletBalance.toStringAsFixed(2)}',
              '₹${totalToPay.toStringAsFixed(2)}',
            ),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.addMoney,
              textColor: Colors.white,
              onPressed: () {
                context.push(RouteNames.wallet);
              },
            ),
          );
          return;
        }
      }

      if (cartItems.isEmpty) return;

      final result = await ref
          .read(checkoutViewModelProvider.notifier)
          .payAndPlaceOrder(
            address: address.toOrderPayload(customerName: _customerName),
            restaurantName: await _restaurantNameForCart(cartItems),
            paymentMethod: _selectedPaymentMethod,
            // The cooking request was collected and shown, but never left the
            // screen — so the kitchen never saw it and it was absent from order
            // history. The payload, the API and OrderModel all already carried
            // `note`; only this hand-off was missing.
            note: _cookingRequest,
          );

      if (!mounted) return;

      if (result.isPlaced) {
        Haptics.success();
        final orderId = result.orderId;
        if (orderId != null && orderId.isNotEmpty) {
          context.go('/orders/success/$orderId');
        } else {
          context.push(RouteNames.orders);
        }
        return;
      }

      AppSnackbar.error(context, result.message);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showCookingRequestDialog(BuildContext context) {
    final textController = TextEditingController(text: _cookingRequest ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.cardDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.cookingRequests,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.white
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  autofocus: true,
                  style: TextStyle(
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.cookingRequestHint,
                    hintStyle: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _cookingRequest = textController.text.trim().isEmpty
                            ? null
                            : textController.text.trim();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(
                      AppLocalizations.of(context)!.saveRequest,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    if (cartState.items.isEmpty) {
      return const EmptyCartView();
    }

    // Group cart items by restaurant
    final groupOrder = <String>[];
    final groups = <String, List<CartItemModel>>{};
    for (final item in cartState.items) {
      final rid = item.food.restaurantId;
      groups
          .putIfAbsent(rid, () {
            groupOrder.add(rid);
            return [];
          })
          .add(item);
    }

    final cartRestaurant = groupOrder.isNotEmpty
        ? ref.watch(restaurantByIdProvider(groupOrder.first)).asData?.value
        : null;

    // Fees and the payable total come from POST /food/orders/calculate.
    final checkoutState = ref.watch(checkoutViewModelProvider);
    final pricing = checkoutState.pricing;
    final totalDeliveryFee = pricing?.deliveryFee ?? 0.0;
    final platformFee = pricing?.platformFee ?? 0.0;
    final itemTotal = pricing?.subtotal ?? cartState.subtotal;
    // Only a real discount (coupon or offer) from the server is a discount.
    // The gap between a dish's price and its "price on other apps" is not: it
    // is shown in the banner and never enters the bill, or the bill stops
    // adding up.
    final savings = pricing?.discount ?? 0.0;
    final otherAppsSaving = cartState.totalSavings;
    final toPay = pricing?.total ?? cartState.subtotal;
    final billReady = pricing != null;
    final packingCharges = pricing?.packagingFee ?? 0.0;

    final pageBgColor = isDark
        ? AppColors.backgroundDark
        : const Color(0xFFF4F5F7);

        final resolvedAddress = _resolveSelectedAddress();
    final addressDisplay = resolvedAddress != null
        ? '${resolvedAddress.title} (${resolvedAddress.fullAddress})'
        : 'Select delivery address';

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(62),
        child: _buildHeader(context, cartRestaurant, addressDisplay, isDark),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          // Closed restaurant alert banner
          if (cartRestaurant != null && !cartRestaurant.isOpen)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF5C2626) : const Color(0xFFFECACA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.store_mall_directory_outlined,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${cartRestaurant.name} is Currently Closed',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'This restaurant is not accepting orders at the moment. You cannot place an order right now.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF7F1D1D),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Savings banner (Screenshot 1)
          if (otherAppsSaving > 0)
            _buildSavingsBanner(otherAppsSaving, isDark),


          // Card 1: Cart Items & Action Chips (Screenshot 1)
          _buildCartItemsCard(
            cartState,
            textColor,
            secondaryColor,
            isDark,
          ),

          const SizedBox(height: 12),

          // Recommendation Section: Complete your meal with
          CartRecommendationsSection(
            restaurantId: groupOrder.isNotEmpty ? groupOrder.first : '1',
            targetCartKey: _cartItemsCardKey,
          ),

          const SizedBox(height: 12),

          // Coupon Card (Screenshot 1)
          _buildPaymentOffersCard(
            pricing,
            checkoutState.couponCode,
            textColor,
            secondaryColor,
            isDark,
          ),

          const SizedBox(height: 12),

          if (!billReady)
            _buildBillNotReadyNotice(checkoutState, isDark),

          // Delivery Details & Total Bill Card (Screenshot 2)
          _buildDeliveryDetailsCard(
            itemTotal: itemTotal,
            totalDeliveryFee: totalDeliveryFee,
            platformFee: platformFee,
            packingCharges: packingCharges,
            savings: savings,
            couponApplied: pricing?.hasCouponApplied ?? false,
            toPay: toPay,
            textColor: textColor,
            secondaryColor: secondaryColor,
            isDark: isDark,
            pricing: pricing,
            resolvedAddress: resolvedAddress,
          ),

          const SizedBox(height: 12),

          // Cancellation Policy Section
          _buildCancellationPolicy(secondaryColor),

          const SizedBox(height: 16),
        ],
      ),
      bottomNavigationBar: _buildBottomDeliveryFooter(
        context,
        billReady ? toPay : null,
        isDark,
        textColor,
        cartRestaurant: cartRestaurant,
      ),
    );
  }

  /// Header with Back Button, Restaurant Name, Delivery Time subtitle, and Share Button (Screenshot 1)
  Widget _buildHeader(
    BuildContext context,
    RestaurantModel? restaurant,
    String addressDisplay,
    bool isDark,
  ) {
    final restaurantName = restaurant?.name ?? '';
    final bgColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Container(
      color: bgColor,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  size: 24,
                ),
                onPressed: () {
                  Haptics.light();
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(RouteNames.home);
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      restaurantName,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                        fontSize: 17.5,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _deliveryLine(restaurant?.deliveryTime ?? '', addressDisplay),
                      style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF6B7280),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                  size: 22,
                ),
                onPressed: () {
                  Haptics.light();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "30 mins to Home, Indore" — or just the prompt while no address is chosen.
  /// Delivery times are stored as "30" as well as "25-30 mins", so a bare
  /// number gets its unit here.
  String _deliveryLine(String deliveryTime, String addressDisplay) {
    final noAddress = addressDisplay == 'Select delivery address';
    final raw = deliveryTime.trim();
    final time = RegExp(r'^[0-9]+([-–][0-9]+)?$').hasMatch(raw) ? '$raw mins' : raw;
    if (noAddress) return time.isEmpty ? addressDisplay : '$time · $addressDisplay';
    return time.isEmpty ? 'Deliver to $addressDisplay' : '$time to $addressDisplay';
  }

  /// Savings banner below app bar (Screenshot 1)
  Widget _buildSavingsBanner(double savings, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
      ),
      child: Row(
        children: [
          const Text('🎉', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "You're saving ₹${savings.toStringAsFixed(0)} compared to other apps",
              style: const TextStyle(
                color: Color(0xFF1D4ED8),
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Card 1: Items list with Veg indicator, edit, red stepper, price, and Action Chips (Screenshot 1)
  Widget _buildCartItemsCard(
    CartState cartState,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    return Container(
      key: _cartItemsCardKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Items List
          for (int i = 0; i < cartState.items.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  height: 20,
                  thickness: 1,
                  color: isDark
                      ? AppColors.borderDark
                      : const Color(0xFFF3F4F6),
                ),
              ),
            _buildCartItemRow(
              cartState.items[i],
              textColor,
              secondaryColor,
              isDark,
            ),
          ],

          // + Add more items row
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 10),
            child: InkWell(
              onTap: () {
                Haptics.light();
                if (cartState.items.isNotEmpty) {
                  final restaurantId =
                      cartState.items.first.food.restaurantId;
                  if (restaurantId.isNotEmpty) {
                    context.push(
                      '${RouteNames.restaurantDetail}/$restaurantId',
                    );
                    return;
                  }
                }
                context.go(RouteNames.home);
              },
              child: Row(
                children: [
                  Icon(Icons.add_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Add more items',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Divider(
            height: 16,
            thickness: 1,
            color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
          ),

          const SizedBox(height: 8),

          // Action Chips Row (Add a note for restaurant + Don't send cutlery) (Screenshot 1)
          Row(
            children: [
              Expanded(
                child: _buildActionChip(
                  icon: Icons.edit_note_rounded,
                  label: _cookingRequest == null
                      ? 'Add a note for the restaurant'
                      : 'Edit restaurant note',
                  isDark: isDark,
                  isSelected: _cookingRequest != null,
                  onTap: () {
                    Haptics.light();
                    _showCookingRequestDialog(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionChip(
                  icon: Icons.restaurant_outlined,
                  label: "Don't send cutlery",
                  isDark: isDark,
                  isSelected: _noCutlery,
                  onTap: () {
                    Haptics.light();
                    setState(() => _noCutlery = !_noCutlery);
                  },
                ),
              ),
            ],
          ),

          if (_cookingRequest != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.10)
                    : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                'Note: $_cookingRequest',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.primary : AppColors.primaryDeep,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Cart Item Row (Screenshot 1: Veg indicator, dish name, Edit >, crisp red stepper, bold price)
  Widget _buildCartItemRow(
    CartItemModel item,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final food = item.food;
    final isVeg = food.isVeg;
    final vegColor = isVeg ? const Color(0xFF008A45) : const Color(0xFF8B2500);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Veg / Non-veg square badge
          Padding(
            padding: const EdgeInsets.only(top: 3, right: 8),
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                border: Border.all(color: vegColor, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: vegColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Dish name and Edit button underneath
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    Haptics.light();
                    FoodDetailSheet.show(context, food, existingCartItem: item);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Crisp Red Outlined Stepper: [ - 1 + ]
          Container(
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(8),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity - 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      '−',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                InkWell(
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(8),
                  ),
                  onTap: () {
                    Haptics.light();
                    ref
                        .read(cartViewModelProvider.notifier)
                        .updateQuantity(item.id, item.quantity + 1);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: Text(
                      '+',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 14),

          // Item total price
          Text(
            '₹${item.totalPrice.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    final chipBg = isSelected
        ? (isDark
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.primaryTint)
        : (isDark ? const Color(0xFF222222) : Colors.white);
    final chipBorder = isSelected
        ? AppColors.primary
        : (isDark ? const Color(0xFF333333) : const Color(0xFFE5E7EB));
    final chipColor = isSelected
        ? AppColors.primary
        : (isDark ? Colors.white70 : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: chipBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: chipBorder, width: 1.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: chipColor),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: chipColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Card 3: Coupon & Payment Offers Card (Screenshot 1: Pink/red container)
  Widget _buildPaymentOffersCard(
    OrderPricing? pricing,
    String? couponCode,
    Color textColor,
    Color secondaryColor,
    bool isDark,
  ) {
    final applied = pricing?.hasCouponApplied ?? false;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECDD3), width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.local_offer_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  applied ? "'$couponCode' applied" : 'Payment offers & more',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 2),
                if (applied)
                  Text(
                    'You saved ₹${pricing!.discount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF008A45),
                    ),
                  )
                else
                  const Text(
                    'View all restaurant coupons',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
          if (applied)
            TextButton(
              onPressed: () {
                Haptics.light();
                ref.read(checkoutViewModelProvider.notifier).removeCoupon();
              },
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                'Remove',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            )
          else
            InkWell(
              onTap: () {
                Haptics.light();
                CouponSheet.show(context);
              },
              child: Row(
                children: [
                  Text(
                    'View all',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Delivery Details & Total Bill Card (Screenshot 2)
  Widget _buildDeliveryDetailsCard({
    required double itemTotal,
    required double totalDeliveryFee,
    required double platformFee,
    required double packingCharges,
    required double savings,
    required bool couponApplied,
    required double toPay,
    required Color textColor,
    required Color secondaryColor,
    required bool isDark,
    required OrderPricing? pricing,
    required AddressModel? resolvedAddress,
  }) {
    final customerName = _customerName;
    final customerPhone = _customerPhone;
    final hasSavedAddress = ref.watch(addressViewModelProvider).isNotEmpty;
    final addressDisplay = resolvedAddress != null
        ? resolvedAddress.fullAddress
        : (hasSavedAddress
            ? 'Select a delivery address'
            : 'Add a delivery address to proceed');

    void openAddressPicker() {
      Haptics.light();
      if (hasSavedAddress) {
        _showAddressSelectionBottomSheet(context);
      } else {
        unawaited(_openAddAddressScreen());
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // 1. Delivery time row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: Color(0xFF1E1E1E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Delivery',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E1E1E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Want this later? Schedule it',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),


          // 3. Delivery address row
          InkWell(
            onTap: openAddressPicker,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 20,
                    color: Color(0xFF1E1E1E),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Delivery at ${resolvedAddress?.title ?? "Home"}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E1E1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          addressDisplay,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFF6B7280),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Add instructions for delivery partner',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF6B7280),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),

          // 4. Customer contact row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_outlined,
                  size: 20,
                  color: Color(0xFF1E1E1E),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    customerPhone.isNotEmpty
                        ? '$customerName, $customerPhone'
                        : customerName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E1E1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6B7280),
                  size: 22,
                ),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),

          // 5. Total Bill row (Collapsible)
          InkWell(
            onTap: () {
              Haptics.light();
              setState(() => _isBillExpanded = !_isBillExpanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 20,
                    color: Color(0xFF1E1E1E),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Total Bill',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (savings > 0) ...[
                              Text(
                                '₹${(toPay + savings).toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '₹${toPay.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          runSpacing: 2,
                          children: [
                            if (savings > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF008A45).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'You saved ₹${savings.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF008A45),
                                  ),
                                ),
                              ),
                            const Text(
                              'Incl. taxes and charges',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isBillExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6B7280),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Bill breakdown
          if (_isBillExpanded) ...[
            Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildBillRow(
                    AppLocalizations.of(context)!.itemTotal,
                    '₹${itemTotal.toStringAsFixed(0)}',
                    secondaryColor,
                    textColor,
                  ),
                  const SizedBox(height: 10),
                  _buildBillRow(
                    AppLocalizations.of(context)!.deliveryFee,
                    totalDeliveryFee == 0
                        ? AppLocalizations.of(context)!.pillFreeCaps
                        : '₹${totalDeliveryFee.toStringAsFixed(0)}',
                    secondaryColor,
                    totalDeliveryFee == 0 ? const Color(0xFF059669) : textColor,
                  ),
                  const SizedBox(height: 10),
                  _buildBillRow(
                    AppLocalizations.of(context)!.platformFee,
                    '₹${platformFee.toStringAsFixed(0)}',
                    secondaryColor,
                    textColor,
                  ),
                  if (packingCharges > 0) ...[
                    const SizedBox(height: 10),
                    _buildBillRow(
                      AppLocalizations.of(context)!.packingCharges,
                      '₹${packingCharges.toStringAsFixed(0)}',
                      secondaryColor,
                      textColor,
                    ),
                  ],
                  if ((pricing?.tax ?? 0) > 0) ...[
                    const SizedBox(height: 10),
                    _buildBillRow(
                      'GST',
                      '₹${pricing!.tax.toStringAsFixed(2)}',
                      secondaryColor,
                      textColor,
                    ),
                  ],
                  if (savings > 0) ...[
                    const SizedBox(height: 10),
                    _buildBillRow(
                      couponApplied
                          ? AppLocalizations.of(context)!.couponDiscount
                          : AppLocalizations.of(context)!.discount,
                      '−₹${savings.toStringAsFixed(0)}',
                      const Color(0xFF059669),
                      const Color(0xFF059669),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLocalizations.of(context)!.grandTotal,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '₹${toPay.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBillRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor, {
    String? originalAmount,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            if (originalAmount != null) ...[
              Text(
                originalAmount,
                style: TextStyle(
                  fontSize: 11.5,
                  color: labelColor.withValues(alpha: 0.6),
                  decoration: TextDecoration.lineThrough,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Cancellation Policy Text Section
  Widget _buildCancellationPolicy(Color secondaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cancellation policy:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: secondaryColor.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Please double-check your order and address details. Orders are non-refundable once placed.',
            style: TextStyle(
              fontSize: 11.5,
              color: secondaryColor.withValues(alpha: 0.8),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }


  /// Opens the add-address screen and selects whatever it saved.
  ///
  /// AddAddressScreen already persists through addressViewModelProvider before
  /// popping, so the newly appended entry is the one to select.
  Future<void> _openAddAddressScreen() async {
    final result = await context.push<dynamic>(RouteNames.addAddress);
    if (result == null || !mounted) return;

    final saved = ref.read(addressViewModelProvider);
    if (saved.isEmpty) return;
    setState(() => _selectedAddressId = saved.last.id);
    Haptics.medium();
    // The bill is priced against the chosen address, so it is now stale.
    unawaited(
      ref.read(checkoutViewModelProvider.notifier).setAddress(saved.last.id),
    );
  }

  void _showAddressSelectionBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : AppColors.textPrimaryLight;
        final secondaryColor = isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight;

        // Consumer so the list rebuilds itself once addAddress/deleteAddress
        // updates the real backend-driven addressViewModelProvider state.
        return Consumer(
          builder: (context, ref, _) {
            final addresses = ref.watch(addressViewModelProvider);
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Choose a delivery address + Close Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Choose a delivery address',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(sheetContext),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF2E2E2E)
                                : const Color(0xFFF2F4F7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 12),

                  // Item 1: Add new Address
                  InkWell(
                    onTap: () {
                      Haptics.light();
                      Navigator.pop(sheetContext);
                      unawaited(_openAddAddressScreen());
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [
                          // Square Primary Theme Box with + Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.primary
                                    : const Color(0xFFD0D5DD),
                                width: 1,
                              ),
                            ),
                            child: Icon(
                              Icons.add,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Add new Address',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.dividerLight,
                  ),
                  const SizedBox(height: 8),

                  // Dynamic Saved Addresses List — sourced from the real,
                  // backend-driven addressViewModelProvider.
                  if (addresses.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No saved addresses yet. Add one to continue.',
                        style: TextStyle(fontSize: 13.5, color: secondaryColor),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        separatorBuilder: (context, index) => Column(
                          children: [
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.borderDark
                                  : AppColors.dividerLight,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                        itemBuilder: (context, index) {
                          final addr = addresses[index];
                          final resolvedId =
                              _selectedAddressId ??
                              (addresses.firstWhere(
                                (a) => a.isDefault,
                                orElse: () => addresses.first,
                              )).id;
                          final isSelected = addr.id == resolvedId;

                          IconData icon = Icons.navigation_outlined;
                          if (addr.type == 'Home' ||
                              addr.title.toLowerCase().contains('home')) {
                            icon = Icons.home_outlined;
                          } else if (addr.type == 'Office' ||
                              addr.title.toLowerCase().contains('office')) {
                            icon = Icons.work_outline;
                          }

                          return _buildSavedAddressTile(
                            sheetContext: sheetContext,
                            addressId: addr.id,
                            title: addr.title,
                            address: addr.fullAddress,
                            icon: icon,
                            isSelected: isSelected,
                            isDark: isDark,
                            textColor: textColor,
                            secondaryColor: secondaryColor,
                            onDelete: () {
                              _showDeleteConfirmationDialog(
                                context: sheetContext,
                                title: addr.title,
                                onConfirm: () async {
                                  Haptics.medium();
                                  final deleted = await ref
                                      .read(addressViewModelProvider.notifier)
                                      .deleteAddress(addr.id);
                                  if (!deleted) return;
                                  if (_selectedAddressId == addr.id) {
                                    setState(() => _selectedAddressId = null);
                                  }
                                  if (!context.mounted) return;
                                  AppSnackbar.success(
                                    context,
                                    '"${addr.title}" deleted',
                                    duration: const Duration(seconds: 2),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Address',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: Text(
            'Are you sure you want to delete "$title"?',
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                onConfirm();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSavedAddressTile({
    required BuildContext sheetContext,
    required String addressId,
    required String title,
    required String address,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color textColor,
    required Color secondaryColor,
    required VoidCallback onDelete,
  }) {
    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _selectedAddressId = addressId);
        Navigator.pop(sheetContext);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Container
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1)
                    : (isDark
                          ? const Color(0xFF2A2A2A)
                          : const Color(0xFFF2F4F7)),
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: AppColors.primary, width: 1.2)
                    : null,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white : Colors.black87),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : textColor,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Delete Icon Button
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: 'Delete address',
            ),
          ],
        ),
      ),
    );
  }

  /// [toPay] is null until the server has priced the order; the button then
  /// shows no amount, and pressing it retries the calculation.
  String _getPaymentButtonLabel(double? toPay) {
    final amount = toPay == null ? '' : ' (₹${toPay.toStringAsFixed(0)})';
    switch (_selectedPaymentMethod) {
      case 'cash':
        return 'PLACE COD ORDER$amount';
      case 'wallet':
        return 'PAY WITH WALLET$amount';
      case 'razorpay':
      default:
        return 'PROCEED TO PAYMENT$amount';
    }
  }

  /// Shown above the bill while it is still the cart's own estimate, so the
  /// customer never reads unconfirmed numbers as final.
  Widget _buildBillNotReadyNotice(CheckoutState checkout, bool isDark) {
    final failed = !checkout.isCalculating && checkout.error != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: failed ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: failed ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          if (failed)
            const Icon(Icons.error_outline, size: 18, color: Color(0xFFB91C1C))
          else
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              failed
                  ? "${checkout.error ?? "Couldn't load the final bill."} The amounts below are estimates."
                  : 'Calculating your final bill…',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: failed ? const Color(0xFFB91C1C) : const Color(0xFF475569),
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: () =>
                  ref.read(checkoutViewModelProvider.notifier).recalculate(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  /// Card 5: Delivery Address Selection Card
  void _showPaymentMethodBottomSheet(
    BuildContext context,
    double toPay,
    double walletBalance,
    bool isDark,
  ) {
    // walletViewModelProvider only fetches once, on first creation. If that
    // fetch lost a race with auth (e.g. it ran while a session had just
    // expired), it fails once and never retries — leaving the balance stuck
    // at 0, which then falsely flags LOW BALANCE here for good. Refresh right
    // as the sheet that actually depends on this number opens.
    ref.read(walletViewModelProvider.notifier).loadWallet(isRefresh: true);
    unawaited(ref.read(payLaterViewModelProvider.notifier).refresh());
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentUser = ref.read(authViewModelProvider).value;
            final isCodAllowed = currentUser?.isCodAllowed ?? true;
            if (!isCodAllowed && _selectedPaymentMethod == 'cash') {
              _selectedPaymentMethod = 'razorpay';
            }

            final modalTextColor = isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight;
            final modalSecondaryColor = isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight;

            return SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.borderDark
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)!.selectPaymentMethod,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: modalTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(
                          context,
                        )!.totalPayableAmount('₹${toPay.toStringAsFixed(2)}'),
                        style: TextStyle(
                          fontSize: 13,
                          color: modalSecondaryColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Option 1: Online Payment (Razorpay / UPI / Cards)
                      _paymentOptionTile(
                        ctx: modalCtx,
                        methodKey: 'razorpay',
                        icon: Icons.credit_card_rounded,
                        title: AppLocalizations.of(context)!.onlinePayment,
                        subtitle: AppLocalizations.of(
                          context,
                        )!.paySecurelyRazorpay,
                        isDark: isDark,
                        modalTextColor: modalTextColor,
                        modalSecondaryColor: modalSecondaryColor,
                      ),

                      // Option 2: Cash on Delivery (COD) — only shown if admin has allowed COD for this user
                      if (isCodAllowed) ...[
                        _paymentOptionTile(
                          ctx: modalCtx,
                          methodKey: 'cash',
                          icon: Icons.payments_outlined,
                          title: AppLocalizations.of(context)!.cashOnDelivery,
                          subtitle: AppLocalizations.of(
                            context,
                          )!.payInCashOnDelivery,
                          isDark: isDark,
                          modalTextColor: modalTextColor,
                          modalSecondaryColor: modalSecondaryColor,
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Flagged only when the wallet is the chosen method: see
                      // the subtitle note below.
                      // Option 3: LAGECH Wallet — watches the provider directly
                      // rather than the `walletBalance` captured when the sheet
                      // was opened, so the refresh triggered above actually
                      // reaches this tile once it resolves.
                      Consumer(
                        builder: (context, consumerRef, _) {
                          final liveBalance = consumerRef
                              .watch(walletViewModelProvider)
                              .wallet
                              .balance;
                          final isLow =
                              _selectedPaymentMethod == 'wallet' &&
                              liveBalance < toPay;
                          return _paymentOptionTile(
                            ctx: modalCtx,
                            methodKey: 'wallet',
                            icon: Icons.account_balance_wallet_outlined,
                            title: AppLocalizations.of(context)!.fudronWallet,
                            // The shortfall only matters once the user is
                            // actually paying by wallet. Flagging LOW BALANCE
                            // while they are paying by card or cash is noise
                            // about a balance that has no bearing on the order.
                            // The badge already says "insufficient" — the
                            // subtitle just states the balance once, not the
                            // same fact twice.
                            subtitle:
                                'Available balance: ₹${liveBalance.toStringAsFixed(2)}',
                            badgeText: isLow ? 'LOW BALANCE' : 'INSTANT',
                            badgeColor: isLow
                                ? AppColors.error
                                : AppColors.success,
                            isDark: isDark,
                            modalTextColor: modalTextColor,
                            modalSecondaryColor: modalSecondaryColor,
                          );
                        },
                      ),

                      // Option 4: Pay Later — only shown once eligibility is
                      // earned (3+ delivered orders, no bad COD history). An
                      // outstanding due blocks every payment method at checkout
                      // (order.service.js asserts this server-side too), so a
                      // due here routes to the repay screen instead of letting
                      // the user pick a method that will just get rejected.
                      Consumer(
                        builder: (context, consumerRef, _) {
                          final payLater = consumerRef
                              .watch(payLaterViewModelProvider)
                              .account;
                          if (!payLater.eligible) {
                            return const SizedBox.shrink();
                          }
                          final hasDue = payLater.amountDue > 0;

                          return Column(
                            children: [
                              const SizedBox(height: 10),
                              if (hasDue)
                                InkWell(
                                  onTap: () {
                                    Haptics.light();
                                    Navigator.pop(modalCtx);
                                    context.push(RouteNames.payLater);
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.06,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppColors.error.withValues(
                                          alpha: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.credit_score_outlined,
                                          color: AppColors.error,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.payLater,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  color: modalTextColor,
                                                ),
                                              ),
                                              Text(
                                                AppLocalizations.of(
                                                  context,
                                                )!.clearDueToUseAgain(
                                                  '₹${payLater.amountDue.toStringAsFixed(2)}',
                                                ),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: AppColors.error,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: modalSecondaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                _paymentOptionTile(
                                  ctx: modalCtx,
                                  methodKey: 'pay_later',
                                  icon: Icons.credit_score_outlined,
                                  title: AppLocalizations.of(context)!.payLater,
                                  subtitle: AppLocalizations.of(context)!
                                      .availableCreditPayNextTime(
                                        '₹${payLater.availableCredit.toStringAsFixed(2)}',
                                      ),
                                  isDark: isDark,
                                  modalTextColor: modalTextColor,
                                  modalSecondaryColor: modalSecondaryColor,
                                ),
                            ],
                          );
                        },
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _paymentOptionTile({
    required BuildContext ctx,
    required String methodKey,
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeColor,
    required bool isDark,
    required Color modalTextColor,
    required Color modalSecondaryColor,
  }) {
    final isSelected = _selectedPaymentMethod == methodKey;

    return InkWell(
      onTap: () {
        Haptics.light();
        setState(() => _selectedPaymentMethod = methodKey);
        Navigator.pop(ctx);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.cardDark : AppColors.secondarySurfaceLight),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: modalTextColor,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (badgeColor ?? AppColors.primary).withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: badgeColor ?? AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: modalSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : modalSecondaryColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom Delivery / Payment Sticky Bar Footer
  Widget _buildBottomDeliveryFooter(
    BuildContext context,
    double? toPay,
    bool isDark,
    Color textColor, {
    RestaurantModel? cartRestaurant,
  }) {
    final walletState = ref.watch(walletViewModelProvider);
    final walletBalance = walletState.wallet.balance;
    final currentUser = ref.watch(authViewModelProvider).value;
    final isCodAllowed = currentUser?.isCodAllowed ?? true;
    if (!isCodAllowed && _selectedPaymentMethod == 'cash') {
      _selectedPaymentMethod = 'razorpay';
    }

    IconData paymentIcon;
    String paymentDisplay;

    switch (_selectedPaymentMethod) {
      case 'cash':
        paymentIcon = Icons.payments_outlined;
        paymentDisplay = 'Cash on Delivery (COD)';
        break;
      case 'wallet':
        paymentIcon = Icons.account_balance_wallet_outlined;
        paymentDisplay = 'LAGECH Wallet (₹${walletBalance.toStringAsFixed(0)})';
        break;
      case 'razorpay':
      default:
        paymentIcon = Icons.credit_card_rounded;
        paymentDisplay = 'Online Payment (UPI/Cards)';
        break;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : const Color(0xFFF3F4F6),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Payment Method row — tapping opens payment method bottom sheet
            InkWell(
              onTap: () {
                Haptics.light();
                _showPaymentMethodBottomSheet(
                  context,
                  // Until the server has priced the order, the cart's own
                  // subtotal is the best estimate for the wallet check.
                  toPay ?? ref.read(cartViewModelProvider).subtotal,
                  walletBalance,
                  isDark,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF262626)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? AppColors.borderDark
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        paymentIcon,
                        color: AppColors.primary,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        paymentDisplay,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.change,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Proceed to Payment Button
            Builder(builder: (context) {
              final isClosed = cartRestaurant != null && !cartRestaurant.isOpen;

              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClosed ? Colors.grey.shade500 : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: isClosed ? 0 : 4,
                    shadowColor: isClosed
                        ? Colors.transparent
                        : AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: isClosed
                      ? () {
                          AppSnackbar.warning(
                            context,
                            '${cartRestaurant.name} is currently closed and not accepting orders.',
                          );
                        }
                      : (_isProcessing ? null : _proceedToPayment),
                  child: isClosed
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.store_mall_directory_outlined, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Restaurant Currently Closed',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        )
                      : (_isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _getPaymentButtonLabel(toPay),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ],
                            )),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}