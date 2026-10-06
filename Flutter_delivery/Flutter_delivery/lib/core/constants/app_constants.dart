import 'dart:io';

import 'package:food_user_application/features/language/domain/models/language_listing_model.dart';

class AppConstants {
  static const String title = 'Lagech Delivery';
  static const String appFontFamily = 'Latin';

  /// Backend REST API host domain (staging/test server).
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://app.lagech.in',
  );

  /// Backend REST API base URL (all endpoints mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.lagech.in/api/v1',
  );

  /// Socket.IO server URL.
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: apiHost,
  );

  static String resolveMediaUrl(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return '';
    if (v.startsWith('http://') ||
        v.startsWith('https://') ||
        v.startsWith('data:')) {
      return v;
    }
    final path = v.startsWith('/') ? v : '/$v';
    return '$apiHost$path';
  }

  static String firbaseApiKey = (Platform.isAndroid)
      ? "AIzaSyDit5-NkEfNpibI4XB9NkJklSwkqcrLz6c"
      : "ios firebase api key";

  static String firebaseAppId = (Platform.isAndroid)
      ? "1:857925379912:android:0e09d76be8d8b80800357d"
      : "ios firebase app id";

  static String firebasemessagingSenderId = (Platform.isAndroid)
      ? "857925379912"
      : "ios firebase sender id";

  static String firebaseProjectId = (Platform.isAndroid)
      ? "lagech-6be7b"
      : "ios firebase project id";

  static String mapKey = (Platform.isAndroid)
      ? 'AIzaSyArBbII2fgAuVaycfkEAm1GcuyvKPTSWyc'
      : 'your ios map key';

  static const String stripPublishKey = '';

  static List<LocaleLanguageList> languageList = [
    LocaleLanguageList(name: 'English', lang: 'en'),
  ];

  static String packageName = 'com.lagech.delivery';
  static String signKey = '';

  static const String fontFamily = 'Latin';
}
