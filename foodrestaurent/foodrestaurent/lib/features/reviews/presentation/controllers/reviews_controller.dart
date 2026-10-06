import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/reviews/data/review_repository.dart';
import 'package:food_user_application/features/reviews/domain/review_model.dart';

class ReviewsController extends AsyncNotifier<ReviewsPage> {
  @override
  Future<ReviewsPage> build() {
    return ref.read(reviewRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(reviewRepositoryProvider).list(),
    );
  }

  /// Saves the reply to review [id] and updates that review in place.
  /// Throws on failure so the caller can show the server's message.
  Future<void> reply(String id, String text) async {
    final (saved, at) = await ref
        .read(reviewRepositoryProvider)
        .reply(id, text.trim());
    final page = state.value;
    if (page == null) return;
    state = AsyncValue.data(
      page.copyWith(
        reviews: [
          for (final r in page.reviews) r.id == id ? r.withReply(saved, at) : r,
        ],
      ),
    );
  }
}

final reviewsControllerProvider =
    AsyncNotifierProvider<ReviewsController, ReviewsPage>(
      ReviewsController.new,
    );
