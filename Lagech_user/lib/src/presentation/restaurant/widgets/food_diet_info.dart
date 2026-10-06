import 'package:flutter/material.dart';

import '../../../data/models/food_model.dart';

/// Nutrition and allergen chips for a dish's detail view. Renders nothing
/// when the restaurant/admin has entered neither.
class FoodDietInfo extends StatelessWidget {
  final FoodModel food;
  final EdgeInsetsGeometry padding;

  const FoodDietInfo({
    super.key,
    required this.food,
    this.padding = const EdgeInsets.only(top: 10),
  });

  @override
  Widget build(BuildContext context) {
    if (food.nutrition.isEmpty && food.allergens.isEmpty) {
      return const SizedBox.shrink();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (food.nutrition.isNotEmpty)
            _group(
              label: 'Nutrition',
              icon: Icons.eco_outlined,
              color: const Color(0xFF008A45),
              values: food.nutrition,
              isDark: isDark,
            ),
          if (food.nutrition.isNotEmpty && food.allergens.isNotEmpty) const SizedBox(height: 8),
          if (food.allergens.isNotEmpty)
            _group(
              label: 'Allergens',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFD97706),
              values: food.allergens,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  Widget _group({
    required String label,
    required IconData icon,
    required Color color,
    required List<String> values,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: values
              .map(
                (v) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.18 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    v,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : color,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
