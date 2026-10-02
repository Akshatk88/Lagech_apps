import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../common_widgets/smart_image.dart';
import '../viewmodels/cart_viewmodel.dart';

class FloatingViewCartBar extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final double bottomOffset;

  const FloatingViewCartBar({
    super.key,
    required this.onTap,
    this.bottomOffset = 16.0,
  });

  @override
  ConsumerState<FloatingViewCartBar> createState() => FloatingViewCartBarState();
}

class FloatingViewCartBarState extends ConsumerState<FloatingViewCartBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _bumpController;
  late Animation<double> _scaleAnimation;

  final GlobalKey _flightAnchorKey = GlobalKey();
  GlobalKey get flightAnchorKey => _flightAnchorKey;

  @override
  void initState() {
    super.initState();
    _bumpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.06).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 60),
    ]).animate(_bumpController);
  }

  @override
  void dispose() {
    _bumpController.dispose();
    super.dispose();
  }

  void bump() => _bumpController.forward(from: 0.0);

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartViewModelProvider);

    ref.listen(cartViewModelProvider, (previous, next) {
      final prevQty = previous?.totalQuantity ?? 0;
      if (next.totalQuantity > prevQty) {
        _bumpController.forward(from: 0.0);
      }
    });

    final shouldShow = cartState.items.isNotEmpty;
    final items = cartState.items;

    // Get first item's restaurant info for display
    final firstItem = items.isNotEmpty ? items.first : null;
    final restaurantName = firstItem?.food.restaurantName ?? '';
    final restaurantImage = firstItem?.food.imageUrl ?? '';
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);

    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final effectiveBottom = widget.bottomOffset + bottomInset;

    return Positioned.fill(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Stable invisible flight anchor
          Positioned(
            left: 16,
            right: 16,
            bottom: effectiveBottom,
            height: 64,
            child: IgnorePointer(
              child: SizedBox.expand(key: _flightAnchorKey),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutCubic,
            bottom: shouldShow ? effectiveBottom : -120.0,
            left: 16,
            right: 16,
            child: IgnorePointer(
              ignoring: !shouldShow,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: shouldShow ? 1.0 : 0.0,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _ZomatoCartBar(
                    restaurantName: restaurantName,
                    restaurantImage: restaurantImage,
                    itemCount: itemCount,
                    subtotal: cartState.subtotal,
                    onTap: widget.onTap,
                    onClearCart: () {
                      ref.read(cartViewModelProvider.notifier).clearCart();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Zomato-style floating cart bar:
/// [RestaurantImage] [RestaurantName / View Menu ▶] [View Cart N items] [×]
class _ZomatoCartBar extends StatelessWidget {
  final String restaurantName;
  final String restaurantImage;
  final int itemCount;
  final double subtotal;
  final VoidCallback onTap;
  final VoidCallback onClearCart;

  const _ZomatoCartBar({
    required this.restaurantName,
    required this.restaurantImage,
    required this.itemCount,
    required this.subtotal,
    required this.onTap,
    required this.onClearCart,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Left: Restaurant Thumbnail ──
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(left: Radius.circular(16)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                  child: restaurantImage.isNotEmpty
                      ? SmartImage(
                          url: restaurantImage,
                          category: ImageCategory.restaurant,
                          fit: BoxFit.cover,
                          width: 66,
                          height: 66,
                        )
                      : Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(
                            Icons.restaurant_rounded,
                            color: Color(0xFF9CA3AF),
                            size: 28,
                          ),
                        ),
                ),
              ),
            ),

            // ── Middle: Restaurant Name + View Menu ──
            Expanded(
              child: GestureDetector(
                onTap: onTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurantName.isNotEmpty ? restaurantName : 'Your Cart',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'View Menu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.play_arrow_rounded,
                            size: 14,
                            color: Color(0xFF6B7280),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Right: Green "View Cart" button ──
            GestureDetector(
              onTap: onTap,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F8A43),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F8A43).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'View Cart',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$itemCount item${itemCount != 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Far Right: × Clear Cart ──
            GestureDetector(
              onTap: onClearCart,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 36,
                height: 66,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.horizontal(right: Radius.circular(16)),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

