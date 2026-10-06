import 'package:dio/dio.dart';

/// The server's own message for a failed request, else [fallback].
///
/// Requests made through Dio fail with a [DioException] that CARRIES the
/// [ApiException] (as `error`) — checking `e is ApiException` alone never matches
/// them, and the server's reason was replaced by a generic message.
String apiErrorMessage(Object error, String fallback) {
  if (error is ApiException) return error.message;
  if (error is DioException) {
    final inner = error.error;
    if (inner is ApiException && inner.message.isNotEmpty) return inner.message;
  }
  return fallback;
}

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() => message;
}
