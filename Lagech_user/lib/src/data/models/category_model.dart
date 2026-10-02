import '../../core/config/api_config.dart';

class CategoryModel {
  final String id;
  final String name;
  final String imageUrl;
  final String slug;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.slug,
  });

  /// Maps a backend category (`/food/restaurant/categories/public`) or an
  /// explore icon (`/food/explore-icons/public`, which uses `iconUrl`/`label`).
  factory CategoryModel.fromApi(Map<String, dynamic> json) {
    final name = (json['name'] ?? json['label'] ?? '').toString();
    return CategoryModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: name,
      imageUrl: ApiConfig.resolveMedia((json['image'] ?? json['iconUrl']) as String?),
      slug: (json['slug']?.toString()) ?? name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
    );
  }

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      imageUrl: json['imageUrl'] as String,
      slug: json['slug'] as String? ?? json['name'].toString().toLowerCase().replaceAll(RegExp(r'\s+'), '-'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'slug': slug,
    };
  }
}
