import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/utils/haptics.dart';
import '../../core/services/review_service.dart';
import '../navigation/route_names.dart';
import '../branding/app_colors.dart';
import '../common_widgets/app_snackbar.dart';
import '../../data/models/user_model.dart';
import '../auth/viewmodels/auth_viewmodel.dart';
import '../wallet/viewmodels/wallet_viewmodel.dart';
import '../../core/utils/localizations.dart';
import '../branding/theme_provider.dart';
import '../home/viewmodels/veg_filter_provider.dart';
import '../../di/settings_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String _getThemeString(ThemeMode mode) {
    if (mode == ThemeMode.light) return 'Light';
    if (mode == ThemeMode.dark) return 'Dark';
    return 'System';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1E1E1E);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF6B7280);
    final cardColor = isDark ? AppColors.cardDark : Colors.white;

    final user = ref.watch(authViewModelProvider).value;
    final isLoggedIn = user != null;

    final walletState = isLoggedIn ? ref.watch(walletViewModelProvider) : null;
    final walletBalance = walletState?.wallet.balance ?? 0.0;
    final isVegOnly = ref.watch(vegFilterProvider);
    final currentTheme = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : const Color(0xFFF9FAFB),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: textColor,
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
                ],
              ),
            ),
          ),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 120,
        ),
        children: [
          // 1. User Profile Row (Screenshot 4)
          _buildUserProfileRow(user, isDark, textColor, secondaryColor),

          const SizedBox(height: 16),


          // 3. Lagech Money, in the same compact style as the other tiles
          _buildNavTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Lagech Money',
            trailing: Text(
              '₹${walletBalance.toStringAsFixed(0)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              ),
            ),
            onTap: () {
              Haptics.light();
              context.push(RouteNames.wallet);
            },
            isDark: isDark,
          ),

          // 4. Action Tiles (Screenshot 4)
          // Tile 1: Your cart
          _buildNavTile(
            icon: Icons.shopping_cart_outlined,
            title: 'Your cart',
            onTap: () {
              Haptics.light();
              context.push(RouteNames.cart);
            },
            isDark: isDark,
          ),

          // Tile 2: Your profile + 48% completed yellow badge
          _buildNavTile(
            icon: Icons.person_outline_rounded,
            title: 'Your profile',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '48% completed',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
            onTap: () {
              Haptics.light();
              if (isLoggedIn) {
                context.push(RouteNames.editProfile);
              } else {
                context.push(
                  '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.profile)}',
                );
              }
            },
            isDark: isDark,
          ),

          // Tile 3: Veg Mode + ON/OFF — only while the admin offers the toggle
          if (ref.watch(businessSettingsProvider.select((s) => s.vegNonVegToggle)))
          _buildNavTile(
            icon: Icons.eco_outlined,
            iconColor: const Color(0xFF008A45),
            title: 'Veg Mode',
            trailing: Text(
              isVegOnly ? 'ON' : 'OFF',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isVegOnly
                    ? const Color(0xFF008A45)
                    : const Color(0xFF6B7280),
              ),
            ),
            onTap: () {
              Haptics.light();
              ref.read(vegFilterProvider.notifier).toggle();
            },
            isDark: isDark,
          ),

          // Tile 4: Appearance + Theme
          _buildNavTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            trailing: Text(
              _getThemeString(currentTheme),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            onTap: () {
              Haptics.light();
              _showAppearanceModal();
            },
            isDark: isDark,
          ),

          // Tile 5: Your rating + -- ★
          _buildNavTile(
            icon: Icons.star_outline_rounded,
            title: 'Your rating',
            trailing: const Text(
              '-- ★',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B7280),
              ),
            ),
            onTap: () {
              Haptics.light();
              _showRateAppModal();
            },
            isDark: isDark,
          ),

          // 5. Sections with Green Accent Line (| Section) (Screenshot 5)
          // Section: Collections
          _buildSectionHeader('Collections', isDark: isDark),
          _buildNavTile(
            icon: Icons.bookmark_border_rounded,
            title: 'Your collections',
            onTap: () {
              Haptics.light();
              context.push(RouteNames.home);
            },
            isDark: isDark,
          ),

          // Section: Food Orders
          _buildSectionHeader('Food Orders', isDark: isDark),
          _buildNavTile(
            icon: Icons.storefront_outlined,
            title: 'Your orders',
            onTap: () {
              Haptics.light();
              context.push(RouteNames.orders);
            },
            isDark: isDark,
          ),
          if (isLoggedIn)
            _buildNavTile(
              icon: Icons.receipt_long_outlined,
              title: 'Refunds & reported issues',
              onTap: () {
                Haptics.light();
                context.push(RouteNames.orderHelpRequests);
              },
              isDark: isDark,
            ),
          _buildNavTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Hear from restaurants',
            onTap: () {
              Haptics.light();
              _showHearFromRestaurantsSheet(context);
            },
            isDark: isDark,
          ),

          // Section: Earnings (Screenshot 1)
          _buildSectionHeader('Earnings', isDark: isDark),
          _buildEarningsNavTile(
            icon: Icons.delivery_dining_rounded,
            title: 'Join as a Delivery Man',
            onTap: () {
              Haptics.light();
              _showJoinDeliveryManSheet(context);
            },
            isDark: isDark,
          ),
          _buildEarningsNavTile(
            icon: Icons.storefront_rounded,
            title: 'Join as a Vendor',
            onTap: () {
              Haptics.light();
              _showOpenVendorSheet(context);
            },
            isDark: isDark,
          ),

          // Section: More
          _buildSectionHeader('More', isDark: isDark),
          _buildNavTile(
            icon: Icons.info_outline_rounded,
            title: 'About',
            onTap: () {
              Haptics.light();
              _showAboutSheet(context);
            },
            isDark: isDark,
          ),
          _buildNavTile(
            icon: Icons.edit_note_rounded,
            title: 'Send feedback',
            onTap: () {
              Haptics.light();
              _showFeedbackSheet(context);
            },
            isDark: isDark,
          ),
          _buildNavTile(
            icon: Icons.warning_amber_rounded,
            title: 'Report a safety emergency',
            onTap: () {
              Haptics.light();
              _showSafetyEmergencySheet(context);
            },
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // Session actions
          if (isLoggedIn) ...[
            _buildLogoutButton(cardColor, isDark),
            const SizedBox(height: 12),
            _buildDeleteAccountButton(),
          ] else
            _buildLoginButton(cardColor),
        ],
      ),
    );
  }

  /// User Profile Row with circular avatar (Screenshot 4)
  Widget _buildUserProfileRow(
    UserModel? user,
    bool isDark,
    Color textColor,
    Color secondaryColor,
  ) {
    final name = (user != null && user.name.isNotEmpty) ? user.name : 'John Doe';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'J';
    final subtitle = (user != null && user.email.isNotEmpty)
        ? user.email
        : ((user?.phone ?? '').isNotEmpty ? user!.phone! : 'john@example.com');

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: const BoxDecoration(
            color: Color(0xFFE0F2FE),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0369A1),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
  /// Section Header with Green Accent Line (Screenshot 5)
  Widget _buildSectionHeader(String title, {bool isDark = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 15,
            decoration: BoxDecoration(
              color: const Color(0xFF008A45),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E1E1E),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigation Tile (Screenshot 4 & 5)
  Widget _buildNavTile({
    required IconData icon,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
    bool isDark = false,
    Color iconColor = const Color(0xFF1E1E1E),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isDark ? Colors.white70 : iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                if (trailing != null) ...[
                  trailing,
                  const SizedBox(width: 6),
                ],
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF9CA3AF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Earnings Nav Tile matching Screenshot 1 with soft red icon background
  Widget _buildEarningsNavTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEAEA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    icon,
                    size: 20,
                    color: const Color(0xFFC80A14),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF1E1E1E),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: isDark ? Colors.white54 : const Color(0xFF67B2FF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showJoinDeliveryManSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.delivery_dining_rounded,
                          color: Color(0xFFC80A14),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Join as a Delivery Partner',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• Earn competitive delivery fees on every order\n• Flexible working hours — work when you want\n• Fast weekly payouts directly to your account\n• Accidental insurance and on-road assistance',
                    style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppSnackbar.show(
                          context,
                          'Delivery partner application received! We will reach out shortly.',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC80A14),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Register as Delivery Partner',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showOpenVendorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEAEA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          color: Color(0xFFC80A14),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Partner with Lagech as Vendor',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '• Reach thousands of hungry customers in your locality\n• Real-time order alerts & live kitchen management\n• Transparent billing and timely settlements\n• In-app promotions to boost your restaurant sales',
                    style: TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF4B5563)),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        AppSnackbar.show(
                          context,
                          'Merchant registration initiated! Our onboarding executive will call you.',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC80A14),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Register Your Restaurant',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showHearFromRestaurantsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('Hear from Restaurants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text('Stay updated with kitchen preparation status, exclusive chef specials, and direct updates from restaurants you love.', style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF6B7280))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text('About LAGECH', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text('LAGECH Food Delivery v1.0.0\nConnecting food lovers with the best authentic kitchens and beloved culinary brands.\n\nMade with ❤️ in India.', style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF4B5563))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1D5DB),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Send Feedback', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Tell us how we can make your food ordering experience even better.', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    const SizedBox(height: 16),
                    TextField(
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Write your thoughts here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          AppSnackbar.success(context, 'Thank you for your valuable feedback!');
                        },
                        child: const Text('Submit Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSafetyEmergencySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                      SizedBox(width: 10),
                      Text('Safety Emergency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('For immediate medical or police emergencies, please call 112 directly.\n\nFor delivery partner safety concerns, our 24/7 dedicated safety response team is reachable at support@lagech.in.', style: TextStyle(fontSize: 14, height: 1.5, color: Color(0xFF374151))),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoutButton(Color cardColor, bool isDark) {
    return InkWell(
      onTap: () {
        Haptics.medium();
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.l10n.logOut),
            content: Text(context.l10n.logOutMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 226, 32, 32),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await ref.read(authViewModelProvider.notifier).logout();
                  if (mounted) {
                    AppSnackbar.success(
                      context,
                      'Logged out successfully',
                      duration: const Duration(seconds: 2),
                    );
                  }
                },
                child: const Text(
                  'Log Out',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: Color.fromARGB(255, 219, 32, 32),
              size: 20,
            ),
            SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(
                color: Color.fromARGB(255, 215, 21, 21),
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Log In Button
  Widget _buildLoginButton(Color cardColor) {
    return InkWell(
      onTap: () {
        Haptics.light();
        context.push(
          '${RouteNames.login}?from=${Uri.encodeComponent(RouteNames.profile)}',
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.login_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Text(
              'Log In to Account',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Delete Account Button — destructive action, requires typed confirmation.
  Widget _buildDeleteAccountButton() {
    return InkWell(
      onTap: () {
        Haptics.medium();
        _showDeleteAccountDialog();
      },
      borderRadius: BorderRadius.circular(16),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.delete_forever_outlined,
              color: Color.fromARGB(255, 250, 29, 29),
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              'Delete Account',
              style: TextStyle(
                color: Color.fromARGB(255, 220, 23, 23),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final canConfirm =
              confirmController.text.trim().toUpperCase() == 'DELETE';
          return AlertDialog(
            title: Text(context.l10n.deleteAccount),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.deleteAccountMessage),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.typeDeleteToConfirm,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(ctx).hintColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: confirmController,
                    autocorrect: false,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.l10n.cancel),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 241, 34, 34),
                ),
                onPressed: canConfirm
                    ? () async {
                        Navigator.pop(ctx);
                        final ok = await ref
                            .read(authViewModelProvider.notifier)
                            .deleteAccount();
                        if (!mounted) return;
                        if (ok) {
                          AppSnackbar.success(
                            context,
                            'Account deleted',
                            duration: const Duration(seconds: 2),
                          );
                        } else {
                          AppSnackbar.error(
                            context,
                            ref
                                    .read(authViewModelProvider.notifier)
                                    .lastError ??
                                'Could not delete account. Please try again.',
                          );
                        }
                      }
                    : null,
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==========================================
  // DYNAMIC INTERACTIVE MODALS & BOTTOM SHEETS
  // ==========================================

  void _showAppearanceModal() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const Text(
                    'Select Theme Appearance 🎨',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _themeOptionTile(
                    ctx,
                    'Light Mode',
                    'Light',
                    Icons.wb_sunny_outlined,
                  ),
                  _themeOptionTile(
                    ctx,
                    'Dark Mode',
                    'Dark',
                    Icons.dark_mode_outlined,
                  ),
                  _themeOptionTile(
                    ctx,
                    'System Default',
                    'System',
                    Icons.settings_brightness_outlined,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _themeOptionTile(
    BuildContext ctx,
    String title,
    String themeName,
    IconData icon,
  ) {
    final current = _getThemeString(ref.watch(themeProvider));
    final isSelected = current == themeName;

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.primary : Colors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : null,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: AppColors.primary)
          : null,
      onTap: () {
        Haptics.light();
        ref.read(themeProvider.notifier).setTheme(themeName);
        Navigator.pop(ctx);
      },
    );
  }

  void _showRateAppModal() {
    int rating = 5;
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD1D5DB),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const Text(
                        'Enjoying LAGECH? ⭐',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap a star to rate your experience',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          return IconButton(
                            icon: Icon(
                              index < rating
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              color: AppColors.primary,
                              size: 36,
                            ),
                            onPressed: () {
                              Haptics.light();
                              setSheetState(() => rating = index + 1);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryButton,
                          ),
                          onPressed: () {
                            Haptics.success();
                            Navigator.pop(ctx);
                            AppSnackbar.success(
                              context,
                              'Thank you for giving us $rating stars! ❤️',
                            );
                            ReviewService.requestReviewIfQualified(rating);
                          },
                          child: const Text(
                            'Submit Rating',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}