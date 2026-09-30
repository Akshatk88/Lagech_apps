import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../data/models/zone_model.dart';
import '../platform/location/location_service.dart';
import '../presentation/address/viewmodels/address_viewmodel.dart';
import '../presentation/home/viewmodels/zone_viewmodel.dart';
import 'catalog_providers.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class UserLocationInfo {
  final String title;
  final String subtitle;
  final double? latitude;
  final double? longitude;
  final bool isManual;

  const UserLocationInfo({
    required this.title,
    required this.subtitle,
    this.latitude,
    this.longitude,
    this.isManual = false,
  });
}

class ActiveLocationNotifier extends Notifier<UserLocationInfo?> {
  @override
  UserLocationInfo? build() => null;

  void setLocation(UserLocationInfo info) {
    state = info;
  }

  void clear() {
    state = null;
  }

  /// Automatically fetches current GPS location, reverse geocodes it,
  /// detects the zone, and updates the active location state.
  /// If [force] is true, overrides any previous manual selection.
  Future<bool> autoFetchGpsLocation({bool force = false}) async {
    // If user already manually selected location and we are not forcing, do not overwrite
    if (state != null && state!.isManual && !force) {
      return false;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return false;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      Position? position;
      // 1. Try to get last known position first for quick responsiveness
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
        }
      } catch (_) {}

      // 2. Fetch current accurate position
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        position ??= await Geolocator.getLastKnownPosition();
      }

      if (position == null) return false;

      final lat = position.latitude;
      final lng = position.longitude;

      // 3. Reverse geocode + detect zone in parallel
      final locationService = ref.read(locationServiceProvider);
      final catalogSource = ref.read(catalogRemoteDataSourceProvider);

      final geoFuture = locationService.reverseGeocode(lat, lng);
      final zoneFuture = catalogSource
          .detectZone(lat: lat, lng: lng)
          .catchError((_) => ZoneModel.unknown);

      final results = await Future.wait([geoFuture, zoneFuture]);
      final geo = results[0] as UserLocationResult;
      final zone = results[1] as ZoneModel;

      // 4. Extract clean title and subtitle
      String title = '';
      if (geo.area.isNotEmpty) {
        title = geo.area;
      } else if (zone.name != null && zone.name!.isNotEmpty) {
        title = zone.name!;
      } else if (geo.city.isNotEmpty) {
        title = geo.city;
      } else {
        title = 'Current Location';
      }

      if (title.contains(',')) {
        final parts = title
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) {
          title = parts.first;
        }
      }

      String subtitle = '';
      final subList = [
        if (geo.building.isNotEmpty && geo.building != 'Building') geo.building,
        if (geo.street.isNotEmpty && geo.street != geo.area) geo.street,
        if (geo.city.isNotEmpty) geo.city,
      ].where((s) => s.isNotEmpty).toSet().toList();

      if (subList.isNotEmpty) {
        subtitle = subList.join(', ');
      } else if (geo.fullAddress.isNotEmpty) {
        subtitle = geo.fullAddress;
      } else if (zone.name != null &&
          zone.name!.isNotEmpty &&
          zone.name != title) {
        subtitle = zone.name!;
      } else {
        subtitle = 'GPS Detected';
      }

      state = UserLocationInfo(
        title: title,
        subtitle: subtitle,
        latitude: lat,
        longitude: lng,
        isManual: false,
      );

      // Invalidate zone provider so products & restaurants update for new location
      ref.invalidate(zoneViewModelProvider);
      return true;
    } catch (e) {
      debugPrint('[LOCATION] autoFetchGpsLocation error: $e');
      return false;
    }
  }
}

final activeLocationProvider =
    NotifierProvider<ActiveLocationNotifier, UserLocationInfo?>(
        ActiveLocationNotifier.new);

/// Where the user is, for anything that only needs coordinates.
final userLatLngProvider =
    FutureProvider<({double lat, double lng})?>((ref) async {
  // Recompute when the selected location changes. Read-only, the first fix
  // stuck for the whole session: picking another address changed the zone but
  // distances and "nearby" kept using the old place.
  ref.watch(activeLocationProvider);
  try {
    return await _resolveLatLng(ref).timeout(const Duration(seconds: 6));
  } catch (_) {
    return null;
  }
});

Future<({double lat, double lng})?> _resolveLatLng(Ref ref) async {
  // 0. Explicit active location selected or detected
  final manual = ref.read(activeLocationProvider);
  if (manual != null && manual.latitude != null && manual.longitude != null) {
    return (lat: manual.latitude!, lng: manual.longitude!);
  }

  // 1. Saved default delivery address
  final addresses = ref.read(addressViewModelProvider.notifier);
  if (ref.read(addressViewModelProvider).isEmpty) {
    await addresses.load();
  }
  final saved = addresses.defaultAddress;
  if (saved?.latitude != null && saved?.longitude != null) {
    return (lat: saved!.latitude!, lng: saved.longitude!);
  }

  // 2. Check last known position for fastest response
  final here = await ref.read(locationServiceProvider).lastKnownLatLng();
  if (here != null) {
    ref.read(activeLocationProvider.notifier).autoFetchGpsLocation();
    return here;
  }

  // 3. Trigger auto fetch and return coordinates
  try {
    final live =
        await ref.read(locationServiceProvider).getCurrentLocationAndAddress();
    if (live.isSuccess && live.latitude != null && live.longitude != null) {
      ref.read(activeLocationProvider.notifier).autoFetchGpsLocation();
      return (lat: live.latitude!, lng: live.longitude!);
    }
  } catch (_) {}

  return null;
}
