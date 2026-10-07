import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:food_user_application/config/constants/app_constants.dart';
import 'package:food_user_application/features/auth/domain/restaurant_model.dart';
import 'package:food_user_application/features/restaurant_profile/data/restaurant_repository.dart';

/// Single cached source of the restaurant's own profile — every Explore
/// screen that needs restaurant data (outlet info, status, delivery
/// settings, bank details, zone setup) watches this instead of fetching on
/// its own.
class RestaurantProfileController extends AsyncNotifier<RestaurantModel> {
  @override
  Future<RestaurantModel> build() {
    return ref.read(restaurantRepositoryProvider).getCurrent();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(restaurantRepositoryProvider).getCurrent(),
    );
  }

  /// Throws on failure — callers should catch and surface the message,
  /// rather than have it silently swallowed into an error state.
  Future<void> updateProfile(Map<String, dynamic> patch) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateProfile(patch);
    state = AsyncValue.data(updated);
  }

  Future<void> updateAvailability(bool isAcceptingOrders) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateAvailability(isAcceptingOrders);
    state = AsyncValue.data(updated);
  }

  Future<void> updateTakeawayEnabled(bool takeawayEnabled) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updateTakeawaySettings(takeawayEnabled);
    state = AsyncValue.data(updated);
  }

  Future<void> updatePackagingSettings({
    bool? enabled,
    double? amount,
    bool? required,
  }) async {
    final updated = await ref
        .read(restaurantRepositoryProvider)
        .updatePackagingSettings(
          enabled: enabled,
          amount: amount,
          required: required,
        );
    state = AsyncValue.data(updated);
  }

  /// Uploads a new logo and shows it straight away.
  ///
  /// Two things used to make a successful change look like it had not happened:
  ///  - Every logo is a `CachedNetworkImage` keyed by its URL. If the server
  ///    stores the new file at the same URL the old picture stayed cached on
  ///    screen, so both URLs are evicted before the profile is re-read.
  ///  - Re-reading went through [refresh], which flips the state to `loading`
  ///    first — a full-screen spinner on Outlet info and a blank logo on
  ///    Orders/Explore. The profile is now swapped in place instead.
  Future<void> uploadProfileImage(XFile file) async {
    final repo = ref.read(restaurantRepositoryProvider);
    final oldUrl = state.value?.profileImage ?? '';
    final uploadedUrl = AppConstants.resolveMediaUrl(
      await repo.uploadProfileImage(file),
    );

    for (final url in {oldUrl, uploadedUrl}) {
      if (url.isEmpty) continue;
      try {
        await CachedNetworkImage.evictFromCache(url);
      } catch (_) {
        // Worst case the old picture lingers until the cache entry expires.
      }
    }

    state = AsyncValue.data(await repo.getCurrent());
  }
}

final restaurantProfileControllerProvider =
    AsyncNotifierProvider<RestaurantProfileController, RestaurantModel>(
      RestaurantProfileController.new,
    );
