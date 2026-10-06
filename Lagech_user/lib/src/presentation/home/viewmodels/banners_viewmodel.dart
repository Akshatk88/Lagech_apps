import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/campaign_model.dart';
import '../../../data/models/promo_banner_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';
import 'zone_viewmodel.dart';

/// Hero banner image URLs from `GET /food/hero-banners/public`.
///
/// Returns an empty list on failure so the header falls back to its video
/// slide rather than showing a broken carousel.
final heroBannersProvider = FutureProvider<List<String>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getHeroBannerImages();
  } catch (_) {
    return const [];
  }
});

/// Admin-uploaded promo banners for the home carousel.
///
/// Returns an empty list on failure, like the hero provider above: the section
/// hides itself when there is nothing to show, so a banner outage costs a strip
/// of the home screen rather than an error state in the middle of it.
final promoBannersProvider = FutureProvider<List<PromoBannerModel>>((ref) async {
  try {
    // Scoped to where the customer is, like the restaurant list: the admin
    // can target a banner at one zone. Re-fetched when the location changes.
    final zoneId = ref.watch(currentZoneIdProvider);
    final here = await ref.watch(userLatLngProvider.future);
    return await ref.watch(catalogRemoteDataSourceProvider).getPromoBanners(
          zoneId: zoneId,
          lat: here?.lat,
          lng: here?.lng,
        );
  } catch (_) {
    return const [];
  }
});

/// Running campaigns for the home strip. Empty on failure or when nothing is
/// running — the strip hides itself, never showing placeholders.
final campaignsProvider = FutureProvider<List<CampaignModel>>((ref) async {
  try {
    return await ref.watch(catalogRemoteDataSourceProvider).getCampaigns();
  } catch (_) {
    return const [];
  }
});
