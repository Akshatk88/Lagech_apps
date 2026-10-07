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
      ? "AIzaSyC4U6VCFm5e6QBfapSOmShoEg7lMGAfsak"
      : "ios firebase api key";

  static String firebaseAppId = (Platform.isAndroid)
      ? "1:853137767775:android:fa0e2bd8dc36290599caea"
      : "ios firebase app id";

  static String firebasemessagingSenderId = (Platform.isAndroid)
      ? "853137767775"
      : "ios firebase sender id";

  static String firebaseProjectId = (Platform.isAndroid)
      ? "pr-2602-048---lagech"
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
