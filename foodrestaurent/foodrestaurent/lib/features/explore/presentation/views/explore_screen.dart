import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/features/auth/presentation/controllers/auth_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/config/theme/theme_mode_provider.dart';

/// True while an account-deletion request is in flight (see the delete card).
bool _deletingAccount = false;

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          _buildBackgroundDecoration(context),

          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(context, ref),

                const SizedBox(height: 32),

                _buildSectionTitle(context, 'MANAGE OUTLET'),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet info',
                      subtitle: 'View and edit outlet\ninformation',
                      icon: Icons.info,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-info'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Outlet timings',
                      subtitle: 'Manage your outlet\nopening hours',
                      icon: Icons.access_time_filled,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/outlet-timings'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Menu categories',
                      subtitle: 'Add & manage\nmenu categories',
                      icon: Icons.restaurant,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/menu-categories'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Offers & Coupons',
                      subtitle: 'Create & manage offers\nand coupons',
                      icon: Icons.local_offer,
                      iconBgColor: AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3) * 1.6,
                      onTap: () => context.push('/offers'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionTitle(context, 'SETTINGS'),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Delivery settings',
                      subtitle: 'Manage delivery\npreferences',
                      icon: Icons.delivery_dining_rounded,
                      iconBgColor: isDark ? AppColors.primaryTintDarkStrong : AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/delivery-settings'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Zone Setup',
                      subtitle: 'Manage delivery\nzones & areas',
                      icon: Icons.map_rounded,
                      iconBgColor: isDark
                          ? AppColors.primaryTintDarkStrong
                          : AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/zone-setup'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Appearance',
                      subtitle: 'Theme settings\nLight & Dark',
                      icon: Icons.palette_outlined,
                      iconBgColor: isDark
                          ? AppColors.primaryTintDarkStrong
                          : AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3),
                      onTap: () => _showAppearanceSheet(context),
                    ),

                    // Delivery on/off and the weekly schedule. This used to be
                    // reachable from the side drawer's "Profile Settings".
                    _buildVerticalCard(
                      context: context,
                      title: 'Restaurant status',
                      subtitle: 'Delivery on/off &\nweekly schedule',
                      icon: Icons.storefront_rounded,
                      iconBgColor: isDark
                          ? AppColors.primaryTintDarkStrong
                          : AppColors.primaryTint,
                      iconColor: AppColors.primary,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/restaurant-status'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionTitle(context, 'ORDERS'),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Order history',
                      subtitle: 'View past orders',
                      icon: Icons.assignment,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/order-history'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Complaints',
                      subtitle: 'Manage issues',
                      icon: Icons.chat_bubble,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/complaints'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Reviews',
                      subtitle: 'Customer reviews',
                      icon: Icons.star,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.warningSoft,
                      width: _getCardWidth(context, 3),
                      onTap: () =>
                          context.push('/complaints', extra: 'reviews'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionTitle(context, 'HELP'),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Support',
                      subtitle: 'Get help and support',
                      icon: Icons.support,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/support'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Feedback',
                      subtitle: 'Share your feedback',
                      icon: Icons.edit_note,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/feedback'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionTitle(context, 'FINANCE'),

                const SizedBox(height: 16),

                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _buildVerticalCard(
                      context: context,
                      title: 'Payout',
                      subtitle: 'View payout details',
                      icon: Icons.currency_rupee,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'payouts'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Invoices',
                      subtitle: 'View your invoices',
                      icon: Icons.receipt_long,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/payouts', extra: 'invoices'),
                    ),

                    _buildVerticalCard(
                      context: context,
                      title: 'Bank details',
                      subtitle: 'Manage bank details',
                      icon: Icons.account_balance,
                      iconColor: AppColors.primary,
                      iconBgColor: AppColors.primaryTint,
                      width: _getCardWidth(context, 3),
                      onTap: () => context.push('/bank-details'),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildLogoutCard(context, ref),

                const SizedBox(height: 16),

                _buildDeleteAccountCard(context, ref),

                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // APPEARANCE BOTTOM SHEET
  // ==============================================================

  void _showAppearanceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final currentMode = ref.watch(themeModeProvider);
            final theme = Theme.of(context);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appearance',
                      style: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    _buildAppearanceOption(
                      ref: ref,
                      sheetContext: sheetContext,
                      title: 'System Default',
                      icon: Icons.brightness_auto,
                      value: ThemeMode.system,
                      groupValue: currentMode,
                    ),

                    _buildAppearanceOption(
                      ref: ref,
                      sheetContext: sheetContext,
                      title: 'Light',
                      icon: Icons.light_mode,
                      value: ThemeMode.light,
                      groupValue: currentMode,
                    ),

                    _buildAppearanceOption(
                      ref: ref,
                      sheetContext: sheetContext,
                      title: 'Dark',
                      icon: Icons.dark_mode,
                      value: ThemeMode.dark,
                      groupValue: currentMode,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==============================================================
  // APPEARANCE OPTION
  // ==============================================================

  Widget _buildAppearanceOption({
    required WidgetRef ref,
    required BuildContext sheetContext,
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
  }) {
    final isSelected = value == groupValue;
    final theme = Theme.of(sheetContext);

    return ListTile(
      leading: Icon(
        icon,
        color: isSelected
            ? AppColors.primary
            : theme.colorScheme.onSurface.withValues(alpha: 0.55),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.primary : theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : Icon(
              Icons.circle_outlined,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(value);
        Navigator.pop(sheetContext);
      },
    );
  }

  // ==============================================================
  // APP BAR
  // ==============================================================

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      leadingWidth: 70,

      leading: Center(
        child: Container(
          width: 44,
          height: 44,
          margin: const EdgeInsets.only(left: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: theme.colorScheme.onSurface,
              size: 20,
            ),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/orders');
              }
            },
          ),
        ),
      ),

      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),

          Text(
            'Manage your outlet & grow your business',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),

      actions: [
        Center(
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                Icons.search,
                color: theme.colorScheme.onSurface,
                size: 20,
              ),
              onPressed: () => context.push('/order-history'),
            ),
          ),
        ),

        const SizedBox(width: 12),

        Center(
          child: Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => context.push('/outlet-info'),
              child: CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.person, size: 24, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // HEADER CARD - FIXED RESPONSIVE VERSION
  // ==============================================================

  Widget _buildHeaderCard(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => context.push('/outlet-info'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.primaryTintDarkStrong, AppColors.primaryTintDark]
                : AppColors.brandGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // ========================================================
            // MAIN CONTENT
            // ========================================================

            Padding(
              padding: const EdgeInsets.only(right: 92),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ====================================================
                  // RESTAURANT IMAGE
                  // ====================================================

                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDeep,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child:
                        restaurantAsync.value?.profileImage.isNotEmpty == true
                        ? CachedNetworkImage(
                            imageUrl: restaurantAsync.value!.profileImage,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) {
                              return const Icon(
                                Icons.storefront,
                                color: Colors.white,
                                size: 30,
                              );
                            },
                          )
                        : const Icon(
                            Icons.storefront,
                            color: Colors.white,
                            size: 30,
                          ),
                  ),

                  const SizedBox(width: 12),

                  // ====================================================
                  // RESTAURANT DETAILS
                  // ====================================================
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Restaurant name
                        Text(
                          restaurantAsync.value?.restaurantName ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 7),

                        // ==================================================
                        // ACTIVE + RATING
                        // ==================================================
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            // ACTIVE
                            _buildHeaderBadge(
                              icon: Icons.check_circle,
                              text: 'Active',
                            ),

                            // RATING
                            if (restaurantAsync.value != null &&
                                restaurantAsync.value!.rating > 0)
                              _buildHeaderBadge(
                                icon: Icons.star,
                                text:
                                    '${restaurantAsync.value!.rating.toStringAsFixed(1)} (${restaurantAsync.value!.totalRatings})',
                              ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // ADDRESS
                        // ==================================================
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white,
                              size: 15,
                            ),

                            const SizedBox(width: 4),

                            Expanded(
                              child: Text(
                                restaurantAsync.value?.fullAddress.isNotEmpty ==
                                        true
                                    ? restaurantAsync.value!.fullAddress
                                    : 'Address not set yet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 11.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ========================================================
            // CHEVRON
            // ========================================================
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // HEADER BADGE
  // ==============================================================

  Widget _buildHeaderBadge({required IconData icon, required String text}) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),

          const SizedBox(width: 4),

          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // SECTION TITLE
  // ==============================================================

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        const SizedBox(width: 8),

        Text(
          title,
          style: TextStyle(
            color: theme.brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // ==============================================================
  // CARD WIDTH
  // ==============================================================

  double _getCardWidth(BuildContext context, int count) {
    final screenWidth = MediaQuery.of(context).size.width;

    return (screenWidth - 32 - (16 * (count - 1))) / count;
  }

  // ==============================================================
  // VERTICAL CARD
  // ==============================================================

  Widget _buildVerticalCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    IconData? icon,
    String? imageAsset,
    required double width,
    Color? iconBgColor,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    final effectiveIconColor = iconColor ?? AppColors.primary;

    final effectiveIconBg =
        iconBgColor ??
        (theme.brightness == Brightness.dark
            ? AppColors.primaryTintDark
            : AppColors.primaryTint);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: imageAsset != null
                      ? Image.asset(
                          imageAsset,
                          width: 24,
                          height: 24,
                          fit: BoxFit.contain,
                        )
                      : Icon(icon, color: effectiveIconColor, size: 24),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 9,
                  height: 1.3,
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: effectiveIconColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: effectiveIconColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // LOGOUT CARD
  // ==============================================================

  Widget _buildLogoutCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Logout?'),
              content: const Text(
                'You will need to verify your phone number again to log back in.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );

          if (confirmed == true) {
            await ref.read(authControllerProvider.notifier).logout();
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.logout, color: AppColors.primary),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Logout',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Tap to sign out from this device',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // DELETE ACCOUNT CARD
  // ==============================================================

  Widget _buildDeleteAccountCard(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete Account?'),
              content: const Text(
                'Are you sure you want to delete your account? This will permanently delete your restaurant profile, menu items, order history, and account data. This action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete Account',
                    style: TextStyle(
                      color: AppColors.errorDeep,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );

          // A second tap while the request is running would send it twice.
          if (confirmed == true && context.mounted && !_deletingAccount) {
            _deletingAccount = true;
            try {
              await ref.read(authControllerProvider.notifier).deleteAccount();
            } catch (e) {
              if (context.mounted) {
                final message = apiErrorMessage(
                  e,
                  'Failed to delete account. Please try again.',
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            } finally {
              _deletingAccount = false;
            }
          }
        },
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: AppColors.primary,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delete Account',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'Permanently delete your account',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.primary.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.arrow_forward_ios,
                color: AppColors.primary.withValues(alpha: 0.5),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // BACKGROUND DECORATION
  // ==============================================================

  Widget _buildBackgroundDecoration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned(
          top: 350,
          right: -100,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(
                  alpha: isDark ? 0.12 : 0.08,
                ),
                width: 1.5,
              ),
            ),
          ),
        ),

        Positioned(
          top: 400,
          right: 20,
          child: SizedBox(
            width: 50,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: List.generate(
                16,
                (index) => Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(
                      alpha: isDark ? 0.15 : 0.08,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
