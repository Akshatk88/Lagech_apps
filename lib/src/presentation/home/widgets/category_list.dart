import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
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
  static String _resolveCategoryFallback(String name) {
    final n = name.toLowerCase().trim();
    if (n.contains('pizza')) {
      return 'https://images.unsplash.com/photo-1513104890138-7c749659a591?w=300&auto=format&fit=crop';
    }
    if (n.contains('biryani') || n.contains('rice')) {
      return 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?w=300&auto=format&fit=crop';
    }
    if (n.contains('burger')) {
      return 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300&auto=format&fit=crop';
    }
    if (n.contains('chicken')) {
      return 'https://images.unsplash.com/photo-1598515214211-89d3c73ae83b?w=300&auto=format&fit=crop';
    }
    if (n.contains('roll') || n.contains('wrap') || n.contains('shawarma') || n.contains('kathi')) {
      return 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46?w=300&auto=format&fit=crop';
    }
    if (n.contains('pasta') || n.contains('spaghetti') || n.contains('macaroni')) {
      return 'https://images.unsplash.com/photo-1621996346565-e3d5d6281691?w=300&auto=format&fit=crop';
    }
    if (n.contains('sandwich') || n.contains('toast')) {
      return 'https://images.unsplash.com/photo-1528735602780-2552fd46c7af?w=300&auto=format&fit=crop';
    }
    if (n.contains('momo') || n.contains('dumpling')) {
      return 'https://images.unsplash.com/photo-1625246333195-78d9c38ad449?w=300&auto=format&fit=crop';
    }
    if (n.contains('fries')) {
      return 'https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=300&auto=format&fit=crop';
    }
    return '';
  }

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

    // Junk / Fast Food prioritized at the FRONT matching reference screenshot:
    // 1. Pizza, 2. Biryani, 3. Burger, 4. Chicken, 5. Rolls, 6. Pasta...
    const junkFoodPrefixes = [
      'pizza',
      'biryani',
      'burger',
      'chicken',
      'roll',
      'pasta',
      'sandwich',
      'momo',
      'fries',
      'vadapav',
      'chinese',
      'maggi',
      'kabab',
      'shawarma',
      'starter',
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
        .map((c) => {
              'name': c.name,
              'imageUrl': c.imageUrl.isNotEmpty ? c.imageUrl : _resolveCategoryFallback(c.name),
              'category': c,
            })
        .toList();

    return SizedBox(
      height: 82.h,
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
                // Uniform circular food dish presentation
                final cat = items[index];
                final name = cat['name'] as String;
                final imgUrl = cat['imageUrl'] as String;
                final isSelected = widget.selectedCategoryName.trim().isNotEmpty &&
                    widget.selectedCategoryName.trim().toLowerCase() == name.trim().toLowerCase();

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Haptics.light();
                    widget.onCategorySelected?.call(name);
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: 14.w),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Uniform circle — no visible border, no background color.
                        // ClipOval + BoxFit.cover ensures every image (jpeg/webp/png)
                        // is cropped into an identical circle shape.
                        SizedBox(
                          width: 52.w,
                          height: 52.w,
                          child: ClipOval(
                            child: SmartImage(
                              url: imgUrl,
                              width: 52.w,
                              height: 52.w,
                              category: ImageCategory.category,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        SizedBox(height: 5.h),
                        // Category Label Text
                        SizedBox(
                          width: 62.w,
                          child: Text(
                            name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? const Color(0xFFC80A14)
                                  : (isDark ? Colors.white : const Color(0xFF111827)),
                              fontSize: 11.5.sp,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            margin: EdgeInsets.only(top: 2.h),
                            width: 14.w,
                            height: 2.h,
                            decoration: BoxDecoration(
                              color: const Color(0xFFC80A14),
                              borderRadius: BorderRadius.circular(2.r),
                            ),
                          )
                        else
                          SizedBox(height: 4.h),
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
                  color: const Color(0xFFC80A14),
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
