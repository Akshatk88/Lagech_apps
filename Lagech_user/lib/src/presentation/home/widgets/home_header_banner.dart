import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/haptics.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/promo_banner_model.dart';
import '../viewmodels/banners_viewmodel.dart';
import '../../cart/viewmodels/cart_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../../common_widgets/smart_image.dart';
import '../../../di/location_providers.dart';
import '../viewmodels/home_viewmodel.dart';

class HomeHeaderBanner extends ConsumerStatefulWidget {
  const HomeHeaderBanner({super.key});

  @override
  ConsumerState<HomeHeaderBanner> createState() => _HomeHeaderBannerState();
}

class _HomeHeaderBannerState extends ConsumerState<HomeHeaderBanner> {
  static const _rotateEvery = Duration(seconds: 4);

  late final PageController _pageController;
  Timer? _timer;
  int _currentIndex = 0;
  bool _userInteracting = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncTimer(int bannerCount) {
    if (bannerCount < 2) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (_timer != null && _timer!.isActive) return;

    _timer = Timer.periodic(_rotateEvery, (_) {
      if (!mounted || _userInteracting || !_pageController.hasClients) return;
      final next = (_currentIndex + 1) % bannerCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _openBanner(PromoBannerModel banner) async {
    final destination = banner.destination;
    Haptics.light();

    if (destination == null || destination.trim().isEmpty) {
      if (mounted) context.push(RouteNames.allOffers);
      return;
    }

    if (destination.startsWith('/')) {
      if (mounted) context.push(destination);
      return;
    }

    try {
      await launchUrl(
        Uri.parse(destination),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      if (mounted) context.push(RouteNames.allOffers);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final promoAsync = ref.watch(promoBannersProvider);
    final banners = promoAsync.asData?.value ?? const [];

    _syncTimer(banners.length);

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFFC80A14), // Brand red fallback
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Dynamic Full-bleed Background Banner Carousel extending all the way to the top
          Positioned.fill(
            child: banners.isEmpty
                ? _buildFallbackBanner(context, isDark)
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n is ScrollStartNotification) _userInteracting = true;
                      if (n is ScrollEndNotification) _userInteracting = false;
                      return false;
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: banners.length,
                      onPageChanged: (i) {
                        if (mounted) setState(() => _currentIndex = i);
                      },
                      itemBuilder: (context, i) {
                        final banner = banners[i];
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openBanner(banner),
                          child: SmartImage(
                            url: banner.imageUrl,
                            category: ImageCategory.food,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        );
                      },
                    ),
                  ),
          ),

          // 2. High-contrast gradient scrim over the banner
          // Ensures the top bar (Location, Logo, Wallet/Cart) and Search capsule
          // are ultra-crisp, easy to read and interact with on top of any banner!
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.22, 0.45, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.65), // Top dark shade for status bar & address
                      Colors.black.withValues(alpha: 0.25), // Mid shade for search bar
                      Colors.transparent, // Clear window for promotional banner center
                      Colors.black.withValues(alpha: 0.35), // Base shade for indicator dots
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Foreground Controls & Layout
          SafeArea(
            bottom: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  child: _buildTopRow(context, ref, isDark),
                ),

                // Open interactive area showcasing the admin promotional banner artwork.
                // Wrapped in IgnorePointer so any tap/drag in this space passes directly
                // through to the banner PageView & GestureDetector underneath!
                IgnorePointer(
                  child: SizedBox(height: 168.h),
                ),

                // Overlaid indicator dots at the bottom of the banner
                if (banners.length > 1) ...[
                  _buildIndicatorDots(banners.length),
                  SizedBox(height: 6.h),
                ] else
                  SizedBox(height: 4.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackBanner(BuildContext context, bool isDark) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.light();
        context.push(RouteNames.allOffers);
      },
      child: Image.asset(
        'assets/images/home_banner.png',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD60E18),
                Color(0xFFC80A14),
                Color(0xFFB80610),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorDots(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == _currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsets.symmetric(horizontal: 3.w),
          width: active ? 18.w : 6.w,
          height: 6.h,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(3.r),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTopRow(BuildContext context, WidgetRef ref, bool isDark) {
    final activeLocation = ref.watch(activeLocationProvider);
    final addresses = ref.watch(addressViewModelProvider);
    final defaultAddress = addresses.cast<AddressModel?>().firstWhere(
      (a) => a?.isDefault == true,
      orElse: () => addresses.firstOrNull,
    );
    final cartItemCount = ref.watch(cartViewModelProvider).items.length;

    String locationTitle = 'Select Location';
    String locationSubtitle = 'Tap to choose address';

    // 1. If user explicitly entered/selected a location — including "Use current
    //    location" — show that. Background-detected GPS does not count: that one
    //    still yields to a saved default address below.
    if (activeLocation != null &&
        (activeLocation.isManual || activeLocation.isCurrentLocation) &&
        activeLocation.title.isNotEmpty) {
      locationTitle = activeLocation.title;
      locationSubtitle = activeLocation.subtitle;
    }
    // 2. If user has a saved default address, show that
    else if (defaultAddress != null) {
      locationTitle = defaultAddress.title.isNotEmpty
          ? defaultAddress.title
          : (defaultAddress.street.isNotEmpty
              ? defaultAddress.street
              : (defaultAddress.city.isNotEmpty ? defaultAddress.city : 'Delivery Address'));

      if (defaultAddress.fullAddress.isNotEmpty) {
        locationSubtitle = defaultAddress.fullAddress;
      } else {
        final parts = [defaultAddress.street, defaultAddress.city]
            .where((s) => s.isNotEmpty)
            .toList();
        locationSubtitle = parts.isNotEmpty ? parts.join(', ') : 'Saved Address';
      }
    }
    // 3. Fallback to auto-detected GPS
    else if (activeLocation != null && activeLocation.title.isNotEmpty) {
      locationTitle = activeLocation.title;
      locationSubtitle = activeLocation.subtitle;
    } else {
      locationTitle = 'Select location';
      locationSubtitle = '';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Location with Pin and Dropdown (Pure White)
        Expanded(
          flex: 4,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              Haptics.light();
              await context.push(RouteNames.selectLocation);
              if (context.mounted) {
                // activeLocationProvider is deliberately NOT invalidated: that
                // resets it to empty, wiping a "Use current location" choice
                // (only manual picks are restored from disk).
                ref.invalidate(addressViewModelProvider);
                ref.invalidate(homeViewModelProvider);
              }
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: 18.sp,
                ),
                SizedBox(width: 3.w),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              locationTitle,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13.5.sp,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 16.sp,
                          ),
                        ],
                      ),
                      Text(
                        locationSubtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Center: Lagech Logo (White stylized speed logo, clean without side lines)
        Expanded(
          flex: 5,
          child: Center(
            child: Image.asset(
              'assets/images/logo_text.png',
              height: 22.h,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Text(
                'LAGECH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
        ),

        // Right: Wallet & Cart Buttons (Circular translucent buttons)
        Expanded(
          flex: 4,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Wallet Button
              _buildTopActionButton(
                icon: Icons.account_balance_wallet_outlined,
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.wallet);
                },
              ),
              SizedBox(width: 6.w),

              // Cart Button
              _buildTopActionButton(
                icon: Icons.shopping_cart_outlined,
                badgeCount: cartItemCount,
                onTap: () {
                  Haptics.light();
                  context.push(RouteNames.cart);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopActionButton({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.22),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16.sp,
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: EdgeInsets.all(4.r),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    color: const Color(0xFFC80A14),
                    fontSize: 9.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

