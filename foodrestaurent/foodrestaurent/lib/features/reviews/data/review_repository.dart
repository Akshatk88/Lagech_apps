import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/reviews/domain/review_model.dart';

class ReviewRepository {
  ReviewRepository(this._dio);

  final Dio _dio;

  Future<ReviewsPage> list() async {
    final response = await _dio.get(
      '/food/restaurant/reviews',
      queryParameters: {'limit': 50},
    );
    return ReviewsPage.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  /// Saves (or edits) the reply to review [id]; an empty [text] removes it.
  /// Returns the stored reply text and time (empty / null once removed).
  Future<(String, DateTime?)> reply(String id, String text) async {
    final response = await _dio.put(
      '/food/restaurant/reviews/$id/reply',
      data: {'reply': text},
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final reply = data['reply'] is Map
        ? Map<String, dynamic>.from(data['reply'] as Map)
        : const <String, dynamic>{};
    return (
      (reply['text'] ?? '').toString(),
      DateTime.tryParse((reply['repliedAt'] ?? '').toString()),
    );
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository(ref.watch(dioProvider));
});
