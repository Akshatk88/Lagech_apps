import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens turn-by-turn directions to a point in Google Maps.
class MapLauncher {
  MapLauncher._();

  /// Tries, in order: the native navigation intent, the Maps web/app link, then a
  /// plain `geo:` pin. Returns whether any of them opened.
  ///
  /// `canLaunchUrl` is deliberately NOT used to gate the attempts. On Android 11+
  /// it answers `false` for any scheme not declared in the manifest `<queries>`
  /// block, which turned this button into a silent no-op. Each URL is simply
  /// tried and the failure caught.
  ///
  /// Pass [context] to show a message when nothing could be opened.
  static Future<bool> launchGoogleMaps(
    double lat,
    double lng, {
    BuildContext? context,
  }) async {
    // Taken before any await, so no BuildContext is used across an async gap.
    final messenger = context == null ? null : ScaffoldMessenger.maybeOf(context);

    final valid = lat.isFinite &&
        lng.isFinite &&
        lat.abs() <= 90 &&
        lng.abs() <= 180 &&
        !(lat == 0 && lng == 0);
    if (!valid) {
      _tell(messenger, 'This location is not available.');
      return false;
    }

    final attempts = <Uri>[
      if (Platform.isAndroid)
        // `mode=l` is two-wheeler, which is what riders are on.
        Uri.parse('google.navigation:q=$lat,$lng&mode=l'),
      if (Platform.isIOS)
        Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=driving'),
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=two_wheeler',
      ),
      if (Platform.isAndroid) Uri.parse('geo:$lat,$lng?q=$lat,$lng'),
    ];

    for (final uri in attempts) {
      try {
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return true;
        }
      } catch (_) {
        // Not handled on this device — try the next one.
      }
    }

    _tell(messenger, 'Could not open Google Maps.');
    return false;
  }

  static void _tell(ScaffoldMessengerState? messenger, String message) {
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}
