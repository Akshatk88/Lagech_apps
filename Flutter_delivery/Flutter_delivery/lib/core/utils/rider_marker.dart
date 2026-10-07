import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// The rider's own marker on the map: the top-down delivery bike
/// (`assets/image/bike.png`, front of the bike at the TOP of the picture, so it
/// points the right way once rotated by the heading).
///
/// One shared loader replaces three copies of the same decode code. They each
/// decoded to a fixed 80 *physical* pixels, which is a different on-screen size
/// on every phone and far too small on dense screens.
class RiderMarker {
  RiderMarker._();

  static const _asset = 'assets/image/bike.png';

  /// On-screen width in logical pixels. The picture is about 1 : 1.5 (w : h), so
  /// the bike is roughly 38 x 57 dp: clearly a bike, not a map-covering blob.
  static const double widthDp = 38;

  static BitmapDescriptor? _cached;
  static double? _cachedRatio;

  /// Rider vehicle types that get the motorbike picture. An unknown or empty
  /// type counts too: the large majority of riders are on two-wheelers, and
  /// showing nothing at all (the blue dot) is the worse default.
  static bool usesBike(String? vehicleType) {
    final v = (vehicleType ?? '').toLowerCase().trim();
    return v.isEmpty ||
        const {
          'bike',
          'two_wheeler',
          'two-wheeler',
          'motorbike',
          'motorcycle',
          'scooter',
          'scooty',
        }.contains(v);
  }

  /// Decodes the bike once per screen density and reuses it.
  static Future<BitmapDescriptor> load() async {
    final ratio =
        ui.PlatformDispatcher.instance.implicitView?.devicePixelRatio ?? 2.0;
    final cached = _cached;
    if (cached != null && _cachedRatio == ratio) return cached;

    final data = await rootBundle.load(_asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: (widthDp * ratio).round(),
    );
    final frame = await codec.getNextFrame();
    final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    final icon = BitmapDescriptor.bytes(
      png!.buffer.asUint8List(),
      imagePixelRatio: ratio,
    );
    _cached = icon;
    _cachedRatio = ratio;
    return icon;
  }

  /// A negative heading means "unknown" from the GPS; a marker must not be
  /// rotated by it.
  static double rotationFor(double heading) =>
      (heading.isFinite && heading >= 0) ? heading : 0;
}
