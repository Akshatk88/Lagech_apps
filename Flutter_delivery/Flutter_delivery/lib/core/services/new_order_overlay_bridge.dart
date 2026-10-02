import 'dart:io';
import 'package:flutter/services.dart';

/// Bridge between Flutter and the native Android WindowManager overlay.
/// Handles:
/// - Consuming order handoff from native launch intent (Accept from overlay)
/// - Flushing pending rejections recorded by the overlay or notification
/// - Checking and requesting SYSTEM_ALERT_WINDOW permission
/// - Dismissing overlay on in-app response or withdrawal
class NewOrderOverlayBridge {
  static const MethodChannel _channel = MethodChannel(
    'com.lagech.delivery/new_order_overlay',
  );

  /// Consumes the order passed when the driver clicks ACCEPT on the native overlay.
  /// Returns a map with `orderId` and `autoAccept` if present, clearing it from the intent.
  static Future<Map<String, dynamic>?> consumeLaunchOrder() async {
    if (!Platform.isAndroid) return null;
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'consumeLaunchOrder',
      );
      if (res != null) {
        return res.cast<String, dynamic>();
      }
    } catch (_) {
      // Ignored (e.g. background isolate or unsupported platform)
    }
    return null;
  }

  /// Retrieves and clears any order IDs the rider declined via the native overlay or notification
  /// while the Flutter engine was paused or backgrounded.
  static Future<List<String>> takePendingRejections() async {
    if (!Platform.isAndroid) return const [];
    try {
      final res = await _channel.invokeMethod<List<dynamic>>(
        'takePendingRejections',
      );
      if (res != null) {
        return res.cast<String>();
      }
    } catch (_) {
      // Ignored
    }
    return const [];
  }

  /// Checks whether the app has SYSTEM_ALERT_WINDOW permission.
  static Future<bool> hasOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system settings screen for granting SYSTEM_ALERT_WINDOW.
  static Future<bool> requestOverlayPermission() async {
    if (!Platform.isAndroid) return false;
    try {
      final res = await _channel.invokeMethod<bool>('requestOverlayPermission');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Dismisses any active native overlay.
  static Future<void> dismissOverlay() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('dismissOverlay');
    } catch (_) {
      // Ignored
    }
  }
}
