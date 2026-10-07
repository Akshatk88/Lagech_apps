import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/config/theme/app_colors.dart';
import 'package:food_user_application/core/network/api_exception.dart';
import 'package:food_user_application/core/widgets/app_refresh_indicator.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/registration/presentation/widgets/image_picker_tile.dart';
import 'package:food_user_application/features/registration/presentation/widgets/labeled_text_field.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_media_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/controllers/restaurant_profile_controller.dart';
import 'package:food_user_application/features/restaurant_profile/presentation/widgets/edit_field_sheet.dart';

class OutletInfoScreen extends ConsumerWidget {
  const OutletInfoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantAsync = ref.watch(restaurantProfileControllerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,

        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            }
          },
        ),

        titleSpacing: 0,

        title: Row(
          children: [
            Expanded(
              child: Text(
                'Outlet info',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),

            if (restaurantAsync.value != null) ...[
              const SizedBox(width: 8),

              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(
                    'ID: ${_restaurantId(restaurantAsync.value!)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),

      body: restaurantAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.primary)),

        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              apiErrorMessage(error, 'Failed to load outlet info.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
        ),

        data: (restaurant) => AppRefreshIndicator(
          onRefresh: () {
            return ref
                .read(restaurantProfileControllerProvider.notifier)
                .refresh();
          },

          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBanner(context, restaurant),

                _buildLogoCard(context, ref, restaurant),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restaurant Information',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),

                                const SizedBox(height: 3),

                                Text(
                                  'All onboarding and profile details at one place.',
                                  softWrap: true,
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontSize: 12,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      _buildRestaurantNameCard(context, ref, restaurant),

                      const SizedBox(height: 16),

                      _buildBasicDetailsCard(context, ref, restaurant),

                      const SizedBox(height: 16),

                      _buildAddressCard(context, restaurant),

                      const SizedBox(height: 16),

                      _buildComplianceCard(context, ref, restaurant),

                      const SizedBox(height: 16),

                      _buildBankDetailsCard(context, ref, restaurant),

                      const SizedBox(height: 16),

                      _buildMediaCard(context, ref, restaurant),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _restaurantId(RestaurantModel restaurant) {
    if (restaurant.restaurantId.isNotEmpty) {
      return restaurant.restaurantId;
    }

    if (restaurant.id.isEmpty) {
      return '—';
    }

    return restaurant.id.substring(0, restaurant.id.length.clamp(0, 6));
  }

  // ===========================================================================
  // BANNER
  // ===========================================================================

  Widget _buildBanner(BuildContext context, RestaurantModel restaurant) {
    if (restaurant.isApproved) {
      return const SizedBox.shrink();
    }

    final message = restaurant.isRejected
        ? (restaurant.rejectionReason.isNotEmpty
              ? restaurant.rejectionReason
              : 'Your application was rejected. Please contact support.')
        : "Your restaurant is still under review — customers can't order from you yet.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF43305D), Color(0xFF704478)],
        ),
      ),
      child: Column(
        children: [
          Text(
            restaurant.isRejected
                ? 'Application Rejected'
                : "We'll be there soon - hang tight!",
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            message,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOGO CARD
  // ===========================================================================

  Widget _buildLogoCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return Transform.translate(
      offset: restaurant.isApproved ? Offset.zero : const Offset(0, -20),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),

        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primaryTintStrong, AppColors.primaryTint],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),

          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -16,
                bottom: -16,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.15,
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 130,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ----------------------------------------------------------------
                  // TOP LOGO + NAME + CHANGE BUTTON
                  // ----------------------------------------------------------------

                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isSmall = constraints.maxWidth < 390;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: restaurant.profileImage.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: restaurant.profileImage,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, _, _) {
                                          return _logoPlaceholder();
                                        },
                                      )
                                    : _logoPlaceholder(),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      restaurant.restaurantName.isNotEmpty
                                          ? restaurant.restaurantName
                                          : '—',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),

                                    const SizedBox(height: 6),

                                    if (restaurant.isApproved)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle,
                                              color: Colors.green.shade600,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 4),
                                            const Flexible(
                                              child: Text(
                                                'Verified',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),

                              if (!isSmall) ...[
                                const SizedBox(width: 8),
                                _buildChangeLogoButton(
                                  context,
                                  ref,
                                  restaurant,
                                ),
                              ],
                            ],
                          ),

                          // On small phones button goes below.
                          if (isSmall) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: _buildChangeLogoButton(
                                context,
                                ref,
                                restaurant,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ----------------------------------------------------------------
                  // RATING ROW - OVERFLOW SAFE
                  // ----------------------------------------------------------------
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.deepOrange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              restaurant.totalRatings > 0
                                  ? restaurant.rating.toStringAsFixed(1)
                                  : 'New',
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            if (restaurant.totalRatings > 0) ...[
                              const SizedBox(width: 2),
                              const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 12,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          '${restaurant.totalRatings} Ratings',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      const Text(
                        '|',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Be the first to review!',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChangeLogoButton(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return GestureDetector(
      onTap: () async {
        // A logo change applies directly: no admin review and no pause in
        // ordering, so there is nothing to warn about any more. (The server must
        // not reset the approval status on a logo upload.)
        final file = await pickImageWithSourceSheet(context);

        if (file == null) {
          return;
        }

        try {
          await ref
              .read(restaurantProfileControllerProvider.notifier)
              .uploadProfileImage(file);

          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Logo updated.')));
          }
        } catch (e) {
          if (context.mounted) {
            _showError(context, e);
          }
        }
      },

      child: Container(
        constraints: const BoxConstraints(minHeight: 38),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 16, color: Colors.black87),
            SizedBox(width: 4),
            Text(
              'Change logo',
              maxLines: 1,
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      width: 64,
      height: 64,
      color: const Color(0xFF5B3B68),
      child: const Center(child: Icon(Icons.storefront, color: Colors.white70)),
    );
  }

  // ===========================================================================
  // RESTAURANT NAME
  // ===========================================================================

  Widget _buildRestaurantNameCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Restaurant name',
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit restaurant name',
          fields: [
            EditFieldSpec(
              key: 'restaurantName',
              label: 'Restaurant name',
              initialValue: restaurant.restaurantName,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        // The sheet above can outlive this screen; do not use its context after that.
        if (!context.mounted) return;
        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Restaurant Name',
          restaurant.restaurantName,
          icon: Icons.storefront_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  // ===========================================================================
  // BASIC DETAILS
  // ===========================================================================

  Widget _buildBasicDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Basic details',
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit basic details',
          fields: [
            EditFieldSpec(
              key: 'ownerName',
              label: 'Owner name',
              initialValue: restaurant.ownerName,
            ),
            EditFieldSpec(
              key: 'primaryContactNumber',
              label: 'Primary contact',
              initialValue: restaurant.primaryContactNumber,
              keyboardType: TextInputType.phone,
            ),
            EditFieldSpec(
              key: 'ownerEmail',
              label: 'Email',
              initialValue: restaurant.ownerEmail,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        // The sheet above can outlive this screen; do not use its context after that.
        if (!context.mounted) return;
        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Owner name',
          restaurant.ownerName,
          icon: Icons.person_outline,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Primary contact',
          restaurant.primaryContactNumber,
          icon: Icons.phone_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Email',
          restaurant.ownerEmail.isEmpty ? 'Not set' : restaurant.ownerEmail,
          icon: Icons.mail_outline,
          showDivider: false,
        ),
      ],
    );
  }

  // ===========================================================================
  // ADDRESS
  // ===========================================================================

  Widget _buildAddressCard(BuildContext context, RestaurantModel restaurant) {
    return _buildInfoCard(
      context: context,
      title: 'Address and location',
      showApprovedBadge: false,
      hideEdit: true,

      children: [
        _buildDetailRow(
          context,
          'Full address',
          restaurant.fullAddress.isNotEmpty
              ? restaurant.fullAddress
              : 'Not set yet',
          isVertical: true,
        ),

        if (restaurant.hasPendingLocationUpdate) ...[
          const SizedBox(height: 16),

          Text(
            'A location update is pending admin review.',
            softWrap: true,
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],

        const SizedBox(height: 16),

        GestureDetector(
          onTap: () => context.push('/zone-setup'),

          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.my_location, color: AppColors.primary, size: 18),

                SizedBox(width: 8),

                Flexible(
                  child: Text(
                    'Update via Zone Setup',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),

                SizedBox(width: 4),

                Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // COMPLIANCE
  // ===========================================================================

  Widget _buildComplianceCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Compliance details',
      showApprovedBadge: restaurant.isApproved,

      onEdit: () => _openComplianceSheet(context, ref, restaurant),

      children: [
        _buildDetailRow(
          context,
          'PAN number',
          restaurant.panNumber.isEmpty ? 'Not set' : restaurant.panNumber,
          icon: Icons.credit_card_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'GST registered',
          restaurant.gstRegistered ? 'Yes' : 'No',
          icon: Icons.receipt_long_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'FSSAI number',
          restaurant.fssaiNumber.isEmpty ? 'Not set' : restaurant.fssaiNumber,
          icon: Icons.shield_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'FSSAI expiry',
          restaurant.fssaiExpiry.isEmpty ? 'Not set' : restaurant.fssaiExpiry,
          icon: Icons.event_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  // ===========================================================================
  // BANK
  // ===========================================================================

  Widget _buildBankDetailsCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return _buildInfoCard(
      context: context,
      title: 'Bank and UPI details',
      showApprovedBadge: restaurant.isApproved,

      onEdit: () async {
        final result = await showEditFieldSheet(
          context: context,
          title: 'Edit bank & UPI details',

          fields: [
            EditFieldSpec(
              key: 'accountHolderName',
              label: 'Account holder',
              initialValue: restaurant.accountHolderName,
            ),

            EditFieldSpec(
              key: 'accountNumber',
              label: 'Account number',
              initialValue: restaurant.accountNumber,
              keyboardType: TextInputType.number,
            ),

            EditFieldSpec(
              key: 'ifscCode',
              label: 'IFSC code',
              initialValue: restaurant.ifscCode,
            ),

            EditFieldSpec(
              key: 'upiId',
              label: 'UPI ID',
              initialValue: restaurant.upiId,
            ),
          ],
        );

        if (result == null) {
          return;
        }

        // The sheet above can outlive this screen; do not use its context after that.
        if (!context.mounted) return;
        await _saveProfile(context, ref, result);
      },

      children: [
        _buildDetailRow(
          context,
          'Account holder',
          restaurant.accountHolderName.isEmpty
              ? 'Not set'
              : restaurant.accountHolderName,
          icon: Icons.person_outline,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'Account number',
          _maskAccount(restaurant.accountNumber),
          icon: Icons.account_balance_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'IFSC code',
          restaurant.ifscCode.isEmpty ? 'Not set' : restaurant.ifscCode,
          icon: Icons.pin_outlined,
        ),

        const SizedBox(height: 12),

        _buildDetailRow(
          context,
          'UPI ID',
          restaurant.upiId.isEmpty ? 'Not set' : restaurant.upiId,
          icon: Icons.qr_code_outlined,
          showDivider: false,
        ),
      ],
    );
  }

  String _maskAccount(String accountNumber) {
    if (accountNumber.isEmpty) {
      return 'Not set';
    }

    if (accountNumber.length <= 4) {
      return accountNumber;
    }

    return '•••• •••• ${accountNumber.substring(accountNumber.length - 4)}';
  }

  // ===========================================================================
  // SAVE PROFILE
  // ===========================================================================

  Future<void> _saveProfile(
    BuildContext context,
    WidgetRef ref,
    Map<String, String> patch,
  ) async {
    try {
      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved.')));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  // ===========================================================================
  // ERROR
  // ===========================================================================

  void _showError(BuildContext context, Object error) {
    final message = apiErrorMessage(error, 'Something went wrong. Please try again.');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ===========================================================================
  // COMPLIANCE SHEET
  // ===========================================================================

  Future<void> _openComplianceSheet(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ComplianceEditSheet(restaurant: restaurant);
      },
    );
  }

  // ===========================================================================
  // MEDIA URL
  // ===========================================================================

  String _resolveMediaUrl(String path) {
    return AppConstants.resolveMediaUrl(path);
  }

  // ===========================================================================
  // MEDIA CARD
  // ===========================================================================

  Widget _buildMediaCard(
    BuildContext context,
    WidgetRef ref,
    RestaurantModel restaurant,
  ) {
    final mediaState = ref.watch(restaurantMediaControllerProvider);

    return _buildInfoCard(
      context: context,
      title: 'Restaurant media',
      showApprovedBadge: false,
      hideEdit: true,

      children: [
        mediaState.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          ),

          error: (err, _) => Text(
            'Failed to load media: $err',
            softWrap: true,
            style: const TextStyle(color: Colors.red),
          ),

          data: (media) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cover Image',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: () async {
                    final file = await pickImageWithSourceSheet(context);

                    if (file == null) {
                      return;
                    }

                    try {
                      await ref
                          .read(restaurantMediaControllerProvider.notifier)
                          .uploadCoverImage(file);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cover image updated.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        _showError(context, e);
                      }
                    }
                  },

                  child: Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    clipBehavior: Clip.hardEdge,

                    child: media.coverImage.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: _resolveMediaUrl(media.coverImage),
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) {
                              return const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 32,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Add Cover Image',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Gallery Images',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      '${media.galleryImages.length}/${media.maxGalleryImages}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in media.galleryImages)
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            clipBehavior: Clip.hardEdge,
                            child: CachedNetworkImage(
                              imageUrl: _resolveMediaUrl(url),
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            ),
                          ),

                          Positioned(
                            top: -8,
                            right: -8,
                            child: IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) {
                                    return AlertDialog(
                                      title: const Text('Delete Image?'),
                                      content: const Text(
                                        'Are you sure you want to delete this image?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(c, true),
                                          child: const Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );

                                if (confirm != true) {
                                  return;
                                }

                                try {
                                  await ref
                                      .read(
                                        restaurantMediaControllerProvider
                                            .notifier,
                                      )
                                      .deleteGalleryImage(url);
                                } catch (e) {
                                  if (context.mounted) {
                                    _showError(context, e);
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),

                    if (media.galleryImages.length < media.maxGalleryImages)
                      GestureDetector(
                        onTap: () async {
                          final ImagePicker picker = ImagePicker();

                          final List<XFile> images = await picker
                              .pickMultiImage(
                                limit:
                                    media.maxGalleryImages -
                                    media.galleryImages.length,
                              );

                          if (images.isEmpty) {
                            return;
                          }

                          try {
                            await ref
                                .read(
                                  restaurantMediaControllerProvider.notifier,
                                )
                                .uploadGalleryImages(images);

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Gallery images uploaded.'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showError(context, e);
                            }
                          }
                        },

                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ===========================================================================
  // COMMON INFO CARD
  // ===========================================================================

  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    IconData? titleIcon,
    required bool showApprovedBadge,
    required List<Widget> children,
    bool hideEdit = false,
    VoidCallback? onEdit,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (titleIcon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(titleIcon, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
              ],

              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),

              if (showApprovedBadge) ...[
                const SizedBox(width: 6),

                Container(
                  constraints: const BoxConstraints(maxWidth: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Approved',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],

              if (!hideEdit) ...[
                const SizedBox(width: 6),

                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit, size: 14, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          'Edit',
                          maxLines: 1,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          ...children,
        ],
      ),
    );
  }

  // ===========================================================================
  // DETAIL ROW - FULL OVERFLOW SAFE
  // ===========================================================================

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value, {
    IconData? icon,
    bool isVertical = false,
    bool showDivider = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            softWrap: true,
            style: TextStyle(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 5),

          SizedBox(
            width: double.infinity,
            child: Text(
              value.isEmpty ? 'Not set' : value,
              softWrap: true,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                height: 1.35,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, size: 16, color: Colors.grey.shade500),
              ),

              const SizedBox(width: 10),
            ],

            // LABEL
            Expanded(
              flex: 4,
              child: Text(
                label,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 13,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(width: 10),

            // VALUE
            Expanded(
              flex: 6,
              child: Text(
                value.isEmpty ? 'Not set' : value,
                textAlign: TextAlign.right,
                softWrap: true,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  height: 1.3,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),

        if (showDivider) ...[
          const SizedBox(height: 12),

          Divider(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            height: 1,
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// COMPLIANCE EDIT SHEET
// =============================================================================

class _ComplianceEditSheet extends ConsumerStatefulWidget {
  const _ComplianceEditSheet({required this.restaurant});

  final RestaurantModel restaurant;

  @override
  ConsumerState<_ComplianceEditSheet> createState() =>
      _ComplianceEditSheetState();
}

class _ComplianceEditSheetState extends ConsumerState<_ComplianceEditSheet> {
  late final TextEditingController _panNumber = TextEditingController(
    text: widget.restaurant.panNumber,
  );

  late final TextEditingController _nameOnPan = TextEditingController(
    text: widget.restaurant.nameOnPan,
  );

  late final TextEditingController _gstNumber = TextEditingController(
    text: widget.restaurant.gstNumber,
  );

  late final TextEditingController _fssaiNumber = TextEditingController(
    text: widget.restaurant.fssaiNumber,
  );

  late bool _gstRegistered = widget.restaurant.gstRegistered;

  XFile? _panImage;
  XFile? _gstImage;
  XFile? _fssaiImage;

  bool _isSaving = false;

  @override
  void dispose() {
    _panNumber.dispose();
    _nameOnPan.dispose();
    _gstNumber.dispose();
    _fssaiNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(restaurantRepositoryProvider);

      final patch = <String, dynamic>{
        'panNumber': _panNumber.text.trim(),
        'nameOnPan': _nameOnPan.text.trim(),
        'gstRegistered': _gstRegistered,
        'gstNumber': _gstNumber.text.trim(),
        'fssaiNumber': _fssaiNumber.text.trim(),
      };

      if (_panImage != null) {
        patch['panImage'] = await repository.uploadAttachment(
          _panImage!,
          folder: 'pan',
        );
      }

      if (_gstImage != null) {
        patch['gstImage'] = await repository.uploadAttachment(
          _gstImage!,
          folder: 'gst',
        );
      }

      if (_fssaiImage != null) {
        patch['fssaiImage'] = await repository.uploadAttachment(
          _fssaiImage!,
          folder: 'fssai',
        );
      }

      await ref
          .read(restaurantProfileControllerProvider.notifier)
          .updateProfile(patch);

      if (!mounted) {
        return;
      }

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compliance details saved.')),
      );
    } catch (e) {
      final message = apiErrorMessage(e, 'Something went wrong. Please try again.');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.92),

      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),

      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),

      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,

        physics: const BouncingScrollPhysics(),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Edit compliance details',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),

                const SizedBox(width: 8),

                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 8),

            LabeledTextField(label: 'PAN number', controller: _panNumber),

            const SizedBox(height: 16),

            LabeledTextField(label: 'Name on PAN', controller: _nameOnPan),

            const SizedBox(height: 16),

            ImagePickerTile(
              label: 'PAN card image',
              image: _panImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);

                if (file != null && mounted) {
                  setState(() {
                    _panImage = file;
                  });
                }
              },
              onRemove: () {
                setState(() {
                  _panImage = null;
                });
              },
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registered for GST?',
                    softWrap: true,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),

                Switch(
                  value: _gstRegistered,
                  activeThumbColor: AppColors.primary,
                  onChanged: (value) {
                    setState(() {
                      _gstRegistered = value;
                    });
                  },
                ),
              ],
            ),

            if (_gstRegistered) ...[
              const SizedBox(height: 12),

              LabeledTextField(label: 'GST number', controller: _gstNumber),

              const SizedBox(height: 16),

              ImagePickerTile(
                label: 'GST certificate image',
                image: _gstImage,
                height: 100,
                onPick: () async {
                  final file = await pickImageWithSourceSheet(context);

                  if (file != null && mounted) {
                    setState(() {
                      _gstImage = file;
                    });
                  }
                },
                onRemove: () {
                  setState(() {
                    _gstImage = null;
                  });
                },
              ),
            ],

            const SizedBox(height: 20),

            LabeledTextField(
              label: 'FSSAI number',
              controller: _fssaiNumber,
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 16),

            ImagePickerTile(
              label: 'FSSAI license image',
              image: _fssaiImage,
              height: 100,
              onPick: () async {
                final file = await pickImageWithSourceSheet(context);

                if (file != null && mounted) {
                  setState(() {
                    _fssaiImage = file;
                  });
                }
              },
              onRemove: () {
                setState(() {
                  _fssaiImage = null;
                });
              },
            ),

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,

                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(
                    alpha: 0.5,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),

                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save',
                        maxLines: 1,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
