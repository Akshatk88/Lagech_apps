/// One customer review of this restaurant, from `GET /food/restaurant/reviews`.
/// [id] is the order the review was left on.
class ReviewModel {
  const ReviewModel({
    required this.id,
    required this.userName,
    required this.rating,
    required this.comment,
    this.ratedAt,
    this.dishName = '',
    this.reply = '',
    this.repliedAt,
  });

  final String id;
  final String userName;
  final int rating;
  final String comment;
  final DateTime? ratedAt;
  final String dishName;

  /// The restaurant's reply; empty when it has not replied.
  final String reply;
  final DateTime? repliedAt;

  bool get hasReply => reply.isNotEmpty;

  ReviewModel withReply(String text, DateTime? at) => ReviewModel(
    id: id,
    userName: userName,
    rating: rating,
    comment: comment,
    ratedAt: ratedAt,
    dishName: dishName,
    reply: text,
    repliedAt: at,
  );

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'] is Map
        ? Map<String, dynamic>.from(json['reply'] as Map)
        : const <String, dynamic>{};
    return ReviewModel(
      id: (json['id'] ?? '').toString(),
      userName: (json['userName'] ?? 'Customer').toString(),
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: (json['comment'] ?? '').toString(),
      ratedAt: DateTime.tryParse((json['ratedAt'] ?? '').toString()),
      dishName: (json['dishName'] ?? '').toString(),
      reply: (reply['text'] ?? '').toString(),
      repliedAt: DateTime.tryParse((reply['repliedAt'] ?? '').toString()),
    );
  }
}

/// The restaurant's reviews plus whether the admin lets it reply.
class ReviewsPage {
  const ReviewsPage({
    required this.reviews,
    required this.canReply,
    this.rating = 0,
    this.totalRatings = 0,
  });

  final List<ReviewModel> reviews;

  /// Business Settings "restaurant can reply to reviews".
  final bool canReply;
  final double rating;
  final int totalRatings;

  ReviewsPage copyWith({List<ReviewModel>? reviews}) => ReviewsPage(
    reviews: reviews ?? this.reviews,
    canReply: canReply,
    rating: rating,
    totalRatings: totalRatings,
  );

  factory ReviewsPage.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : const <String, dynamic>{};
    return ReviewsPage(
      reviews: (json['reviews'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => ReviewModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      canReply: json['canReply'] == true,
      rating: (summary['rating'] as num?)?.toDouble() ?? 0,
      totalRatings: (summary['totalRatings'] as num?)?.toInt() ?? 0,
    );
  }
}
