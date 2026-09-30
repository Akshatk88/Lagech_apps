import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../data/models/zone_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';

import '../../address/viewmodels/address_viewmodel.dart';

/// Detects the serviceable zone for the user's location.
///
/// Zone gates the home screen: `zoneId` is passed to every listing and search
/// call so results are scoped to the area we actually deliver to. When location
/// is unavailable or the point is out of coverage, we fall back to unscoped
/// (national) listings rather than showing an empty app.
///
/// Priority: explicit selection via location picker > default saved address > GPS auto-detect.
final zoneViewModelProvider =
    AsyncNotifierProvider<ZoneViewModel, ZoneModel>(ZoneViewModel.new);

class ZoneViewModel extends AsyncNotifier<ZoneModel> {
  @override
  FutureOr<ZoneModel> build() => _detect();

  Future<ZoneModel> _detect() async {
    final repo = ref.read(catalogRemoteDataSourceProvider);

    // 1. If the user explicitly selected a location or address with coordinates,
    //    use those coordinates immediately rather than re-requesting GPS.
    final active = ref.read(activeLocationProvider);
    if (active != null &&
        active.latitude != null &&
        active.longitude != null) {
      try {
        return await repo.detectZone(
            lat: active.latitude!, lng: active.longitude!);
      } catch (_) {
        return ZoneModel.unknown;
      }
    }

    // 2. Check if user has a default saved address with coordinates.
    try {
      final addressesNotifier = ref.read(addressViewModelProvider.notifier);
      if (ref.read(addressViewModelProvider).isEmpty) {
        await addressesNotifier.load();
      }
      final saved = addressesNotifier.defaultAddress;
      if (saved?.latitude != null && saved?.longitude != null) {
        return await repo.detectZone(
            lat: saved!.latitude!, lng: saved.longitude!);
      }
    } catch (_) {}

    // 3. Fall back to GPS auto-detection.
    final position = await _currentPosition();
    if (position == null) return ZoneModel.unknown;

    try {
      return await repo.detectZone(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      // Zone detection must never hard-fail the app — unscoped listings are a
      // usable fallback.
      return ZoneModel.unknown;
    }
  }

  Future<Position?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _detect());
  }
}

/// The zone id to scope catalog calls with, or null when undetected.
final currentZoneIdProvider = Provider<String?>((ref) {
  return ref.watch(zoneViewModelProvider).value?.zoneId;
});
