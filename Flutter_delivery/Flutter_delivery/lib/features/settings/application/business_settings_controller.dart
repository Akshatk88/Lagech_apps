import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/result.dart';
import '../data/business_settings_repository.dart';

/// Last-known rider business settings, persisted so they survive restarts and
/// are readable outside Riverpod (e.g. the FCM notification builders, which
/// may run in a background isolate with no ProviderScope).
class BusinessSettingsCache {
  BusinessSettingsCache._();

  static const _prefKey = 'rider_business_settings';

  /// In-memory copy for synchronous reads in the main isolate.
  static RiderBusinessSettings current = RiderBusinessSettings.defaults;

  static Future<RiderBusinessSettings> read() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey);
      if (raw == null || raw.isEmpty) return RiderBusinessSettings.defaults;
      final decoded = jsonDecode(raw);
      return RiderBusinessSettings.fromJson(
        decoded is Map<String, dynamic> ? decoded : null,
      );
    } catch (_) {
      return RiderBusinessSettings.defaults;
    }
  }

  static Future<void> write(RiderBusinessSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(settings.toJson()));
    } catch (_) {
      // Cache is best-effort; the in-memory value still applies this session.
    }
  }
}

/// Admin-controlled rider settings. Starts from the cached copy (or the
/// pre-settings defaults) and refreshes from the public endpoint on
/// [load]. A failed fetch keeps whatever we already had.
class BusinessSettingsController extends Notifier<RiderBusinessSettings> {
  Future<void>? _loadInFlight;
  bool _loadedFromNetwork = false;

  @override
  RiderBusinessSettings build() {
    unawaited(_restoreCached());
    return BusinessSettingsCache.current;
  }

  Future<void> _restoreCached() async {
    final cached = await BusinessSettingsCache.read();
    // Don't clobber a fresher network value that landed first.
    if (_loadedFromNetwork) return;
    BusinessSettingsCache.current = cached;
    if (cached != state) state = cached;
  }

  Future<void> load() {
    return _loadInFlight ??= _doLoad().whenComplete(() => _loadInFlight = null);
  }

  Future<void> _doLoad() async {
    final result = await ref.read(businessSettingsRepositoryProvider).getRiderSettings();
    result.when(
      success: (settings) {
        _loadedFromNetwork = true;
        BusinessSettingsCache.current = settings;
        unawaited(BusinessSettingsCache.write(settings));
        if (settings != state) state = settings;
      },
      failure: (error) {
        debugPrint('[BusinessSettings] load failed, keeping cached: ${error.message}');
      },
    );
  }
}

final businessSettingsControllerProvider =
    NotifierProvider<BusinessSettingsController, RiderBusinessSettings>(
  BusinessSettingsController.new,
);
