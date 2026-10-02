import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/src/food_user_application.dart';
import 'package:food_user_application/src/platform/notifications/push_service.dart';
import 'package:geolocator/geolocator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[APP] App Started');

  final firebaseOk = await ensureFirebaseInitialized();
  if (firebaseOk) {
    debugPrint('[APP] Firebase Initialized');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    debugPrint('[FCM] Background Handler Registered');
  } catch (e) {
    debugPrint('[FCM] Background Handler Registration failed: $e');
  }

  try {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    debugPrint('[APP] Location Permission Checked: $permission');
  } catch (e) {
    debugPrint('[APP] Location Permission check failed: $e');
  }

  runApp(const ProviderScope(child: FoodUserApplication()));
}
