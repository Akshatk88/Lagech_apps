import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A place the user previously chose as their location.
class RecentLocation {
  const RecentLocation({
    required this.title,
    required this.subtitle,
    required this.latitude,
    required this.longitude,
  });

  final String title;
  final String subtitle;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle,
        'lat': latitude,
        'lng': longitude,
      };

  static RecentLocation? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = (raw['lat'] as num?)?.toDouble();
    final lng = (raw['lng'] as num?)?.toDouble();
    final title = (raw['title'] ?? '').toString();
    if (lat == null || lng == null || title.isEmpty) return null;
    return RecentLocation(
      title: title,
      subtitle: (raw['subtitle'] ?? '').toString(),
      latitude: lat,
      longitude: lng,
    );
  }
}

/// The last few locations the user picked, newest first, kept on the device.
///
/// Per device rather than per account on purpose: it is a convenience list, and
/// it should work for a guest who has no saved addresses at all.
class RecentLocationsNotifier extends Notifier<List<RecentLocation>> {
  static const _prefKey = 'recent_locations_v1';
  static const _max = 5;

  /// Two picks closer than this are the same place.
  static const _sameSpotMeters = 60.0;

  @override
  List<RecentLocation> build() {
    _load();
    return const [];
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      state = decoded
          .map(RecentLocation.fromJson)
          .whereType<RecentLocation>()
          .take(_max)
          .toList();
    } catch (_) {
      // A corrupt list is only a lost convenience.
    }
  }

  Future<void> add(RecentLocation location) async {
    final next = <RecentLocation>[
      location,
      ...state.where((r) {
        final sameName = r.title.toLowerCase() == location.title.toLowerCase();
        final meters = Geolocator.distanceBetween(
          r.latitude,
          r.longitude,
          location.latitude,
          location.longitude,
        );
        return !(sameName || meters < _sameSpotMeters);
      }),
    ].take(_max).toList();
    state = next;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefKey,
        jsonEncode(next.map((r) => r.toJson()).toList()),
      );
    } catch (_) {}
  }
}

final recentLocationsProvider =
    NotifierProvider<RecentLocationsNotifier, List<RecentLocation>>(
  RecentLocationsNotifier.new,
);
