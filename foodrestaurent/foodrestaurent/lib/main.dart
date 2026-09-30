import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:food_user_application/app.dart';
import 'package:food_user_application/core/services/fcm_service.dart';
import 'package:food_user_application/core/services/local_notification_service.dart';
import 'config/constants/app_constants.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Surface framework-caught errors (widget build/layout/paint) instead of
    // letting them silently die, without taking the app down.
    FlutterError.onError = FlutterError.presentError;
    // Catches everything else (async errors outside a caught Future) so a
    // stray exception can't reach the platform embedder as a fatal crash.
    PlatformDispatcher.instance.onError = (error, stack) {
      if (kDebugMode) debugPrint('Uncaught error: $error\n$stack');
      return true;
    };

    try {
      if (!kIsWeb && Platform.isAndroid) {
        await Firebase.initializeApp();
      } else {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: AppConstants.firbaseApiKey,
            appId: AppConstants.firebaseAppId,
            messagingSenderId: AppConstants.firebasemessagingSenderId,
            projectId: AppConstants.firebaseProjectId,
          ),
        );
      }
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Pre-create notification channels and request permission at launch
      await LocalNotificationService.instance.initialize(
        onResponse: (_) {},
        requestPermission: true,
      );
    } catch (e, s) {
      // On devices with missing/outdated Google Play Services (common on
      // budget phones) this used to throw here, before runApp — killing the
      // app on launch with no UI shown at all. Push notifications simply
      // won't work if this fails; that beats a crash on every open.
      if (kDebugMode) debugPrint('Firebase init failed: $e\n$s');
    }

    runApp(const ProviderScope(child: FoodUserApplication()));
  }, (error, stack) {
    if (kDebugMode) debugPrint('Uncaught zone error: $error\n$stack');
  });
}
