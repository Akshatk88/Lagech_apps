import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  static const String title = 'Lagech Restaurant';

  /// Backend REST API host domain (staging/test server).
  static const String apiHost = String.fromEnvironment(
    'API_HOST',
    defaultValue: 'https://app.lagech.in',
  );

  /// Backend REST API base URL (all endpoints are mounted under `/api/v1`).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://app.lagech.in/api/v1',
  );

  /// Socket.IO server base (same host, root path — see `Backend/socket-server.js`).
  static const String socketUrl = String.fromEnvironment(
    'SOCKET_URL',
    defaultValue: apiHost,
  );

  /// Resolves relative media paths (`/uploads/...`) against [apiHost].
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

  static String firbaseApiKey = (kIsWeb || Platform.isAndroid)
      ? "AIzaSyC4U6VCFm5e6QBfapSOmShoEg7lMGAfsak"
      : "ios firebase api key";
  static String firebaseAppId = (kIsWeb || Platform.isAndroid)
      ? "1:853137767775:android:f6bb83f241cf619d99caea"
      : "ios firebase app id";
  static String firebasemessagingSenderId = (kIsWeb || Platform.isAndroid)
      ? "853137767775"
      : "ios firebase sender id";
  static String firebaseProjectId = (kIsWeb || Platform.isAndroid)
      ? "pr-2602-048---lagech"
      : "ios firebase project id";

  /// Google Maps API key (Maps SDK for Android/iOS + Geocoding API enabled).
  static String mapKey = 'AIzaSyCLHQKJg5shpKs0uNiDHiZJTtBUMKl21ak';

  static const String stripPublishKey = '';

  static String packageName = 'com.lagech.restaurant';
  static String signKey = '';
}
