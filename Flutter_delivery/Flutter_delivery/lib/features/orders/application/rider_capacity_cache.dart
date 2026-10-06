import 'package:shared_preferences/shared_preferences.dart';

/// Last-known `canAcceptMore` from `/orders/current`, kept where the new-order
/// alerts can read it outside Riverpod: the foreground notification builder,
/// the background isolate, and the native Android overlay / notifier (which
/// read the same shared_preferences entry, `flutter.rider_can_accept_more`,
/// in RiderPrefs.kt).
///
/// `null` = unknown (older backend, or never loaded): offers alert as before.
class RiderCapacityCache {
  RiderCapacityCache._();

  static const _prefKey = 'rider_can_accept_more';

  /// In-memory copy for synchronous reads in the main isolate.
  static bool? current;

  /// True unless the rider is known to be at their order limit.
  static Future<bool> canAcceptMore() async {
    if (current != null) return current!;
    try {
      final prefs = await SharedPreferences.getInstance();
      // Another isolate (the app) may have written it since this one started.
      await prefs.reload();
      return prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> write(bool? canAcceptMore) async {
    current = canAcceptMore;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (canAcceptMore == null) {
        await prefs.remove(_prefKey);
      } else {
        await prefs.setBool(_prefKey, canAcceptMore);
      }
    } catch (_) {
      // Best-effort; the in-memory value still applies this session.
    }
  }
}
