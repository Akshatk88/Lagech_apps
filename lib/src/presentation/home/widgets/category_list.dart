import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../branding/app_colors.dart';
import '../../common_widgets/smart_image.dart';

class CategoryList extends StatefulWidget {
  final List<CategoryModel> categories;
  final ValueChanged<String>? onCategorySelected;
  final VoidCallback? onMealsUnder200Tap;
  final VoidCallback? onAllCategoriesTap;
  final String selectedCategoryName;

  const CategoryList({
    super.key,
    required this.categories,
    this.onCategorySelected,
    this.onMealsUnder200Tap,
    this.onAllCategoriesTap,
    this.selectedCategoryName = 'All',
  });

  @override
  State<CategoryList> createState() => _CategoryListState();
}

class _CategoryListState extends State<CategoryList> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final seenIds = <String>{};
    final seenNames = <String>{};
    final uniqueCategories = <CategoryModel>[];

    for (final c in widget.categories) {
      final idKey = c.id.trim();
      final nameKey = c.name.trim().toLowerCase();

      final isDuplicateId = idKey.isNotEmpty && seenIds.contains(idKey);
      final isDuplicateName = nameKey.isNotEmpty && seenNames.contains(nameKey);

      if (isDuplicateId || isDuplicateName) continue;

      if (idKey.isNotEmpty) seenIds.add(idKey);
      if (nameKey.isNotEmpty) seenNames.add(nameKey);
      uniqueCategories.add(c);
    }

    // Junk / Fast Food prioritized at the FRONT (Pizza, Burger, Sandwich, Momos first)
    const junkFoodPrefixes = [
      'pizza',
      'burger',
      'sandwich',
      'momo',
      'fries',
      'roll',
      'pasta',
      'maggi',
      'vadapav',
      'chinese',
      'biryani',
      'chicken',
      'starter',
      'kabab',
      'pav bhaji',
      'snack',
      'mutton',
      'shake',
      'ice cream',
      'dessert',
      'sweet',
      'mocktail',
      'coffee',
      'juice',
    ];

    // Healthy, traditional, staples, grocery & raw foods moved to the BACK
    const trailingPrefixes = [
      'south indian',
      'thali',
      'breakfast',
      'hotel',
      'main course',
      'rice',
      'roti',
      'egg',
      'sup',
      'soup',
      'salad',
      'diet',
      'upwas',
      'fast',
      'paan',
      'bakery',
      'toast',
      'frozen',
      'sauce',
    ];

    final firstItems = <CategoryModel>[];
    final lastItems = <CategoryModel>[];
    final middleItems = <CategoryModel>[];

    for (final prefix in junkFoodPrefixes) {
      final matches = uniqueCategories
          .where((c) =>
              c.name.toLowerCase().contains(prefix) &&
              !firstItems.contains(c))
          .toList();
      firstItems.addAll(matches);
    }

    for (final prefix in trailingPrefixes) {
      final matches = uniqueCategories
          .where((c) =>
              c.name.toLowerCase().contains(prefix) &&
              !firstItems.contains(c) &&
              !lastItems.contains(c))
          .toList();
      lastItems.addAll(matches);
    }

    for (final c in uniqueCategories) {
      if (!firstItems.contains(c) && !lastItems.contains(c)) {
        middleItems.add(c);
      }
    }

    final orderedCategories = [...firstItems, ...middleItems, ...lastItems];
    final items = orderedCategories
        .map((c) => {'name': c.name, 'imageUrl': c.imageUrl, 'category': c})
        .toList();

    return SizedBox(
      height: 76.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(left: 16.w, right: 8.w),
              itemCount: items.length,
        itemBuilder: (context, index) {
          // Circular Food Categories
          final cat = items[index];
          final name = cat['name'] as String;
          final isSelected = widget.selectedCategoryName.trim().isNotEmpty &&
              widget.selectedCategoryName.trim().toLowerCase() == name.trim().toLowerCase();

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Haptics.light();
              widget.onCategorySelected?.call(name);
            },
            child: Container(
              margin: EdgeInsets.only(right: 10.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.surfaceDark : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFC80A14) : Colors.transparent,
                        width: isSelected ? 2.5 : 0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFC80A14).withValues(alpha: 0.35),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    padding: EdgeInsets.all(isSelected ? 2.0 : 0.0),
                    child: ClipOval(
                      child: SmartImage(
                        url: cat['imageUrl'] as String,
                        category: ImageCategory.category,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: 3.h),
                  SizedBox(
                    width: 56.w,
                    child: Text(
                      name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFC80A14)
                            : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                        fontSize: 10.5.sp,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      margin: EdgeInsets.only(top: 1.5.h),
                      width: 14.w,
                      height: 2.h,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC80A14),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    )
                  else
                    SizedBox(height: 3.5.h),
                ],
              ),
            ),
          );
        },
      ),
    ),

    // Red tune icon on the right side - clicking opens all categories
    Padding(
      padding: EdgeInsets.only(right: 12.w, left: 2.w),
      child: InkWell(
        onTap: () {
          Haptics.light();
          widget.onAllCategoriesTap?.call();
        },
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          width: 34.w,
          height: 34.w,
          alignment: Alignment.center,
          child: Icon(
            Icons.tune_rounded,
            color: const Color(0xFFC80A14), // Red color
            size: 20.sp,
          ),
        ),
      ),
    ),
  ],
),
);
  }
}
