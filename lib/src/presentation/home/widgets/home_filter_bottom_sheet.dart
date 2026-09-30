import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/restaurant_model.dart';
import '../../branding/app_colors.dart';

/// Complete criteria for food delivery filters matching Zomato / Swiggy standards.
class RestaurantFilterCriteria {
  final String sortBy; // 'relevance', 'rating_high', 'delivery_fast', 'cost_low', 'cost_high'
  final String deliveryTime; // 'any', '30mins', '45mins'
  final String rating; // 'any', '4.0', '4.5'
  final String distance; // 'any', '1km', '3km', '5km'
  final String costForOne; // 'any', 'under_200', '200_to_500', 'above_500'
  final Set<String> selectedCuisines; // Category / cuisine names
  final bool pureVegOnly;
  final bool freeDeliveryOnly;
  final bool hasOffersOnly;

  const RestaurantFilterCriteria({
    this.sortBy = 'relevance',
    this.deliveryTime = 'any',
    this.rating = 'any',
    this.distance = 'any',
    this.costForOne = 'any',
    this.selectedCuisines = const {},
    this.pureVegOnly = false,
    this.freeDeliveryOnly = false,
    this.hasOffersOnly = false,
  });

  bool get isDefault =>
      sortBy == 'relevance' &&
      deliveryTime == 'any' &&
      rating == 'any' &&
      distance == 'any' &&
      costForOne == 'any' &&
      selectedCuisines.isEmpty &&
      !pureVegOnly &&
      !freeDeliveryOnly &&
      !hasOffersOnly;

  int get activeFiltersCount {
    int count = 0;
    if (sortBy != 'relevance') count++;
    if (deliveryTime != 'any') count++;
    if (rating != 'any') count++;
    if (distance != 'any') count++;
    if (costForOne != 'any') count++;
    count += selectedCuisines.length;
    if (pureVegOnly) count++;
    if (freeDeliveryOnly) count++;
    if (hasOffersOnly) count++;
    return count;
  }

  RestaurantFilterCriteria copyWith({
    String? sortBy,
    String? deliveryTime,
    String? rating,
    String? distance,
    String? costForOne,
    Set<String>? selectedCuisines,
    bool? pureVegOnly,
    bool? freeDeliveryOnly,
    bool? hasOffersOnly,
  }) {
    return RestaurantFilterCriteria(
      sortBy: sortBy ?? this.sortBy,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      rating: rating ?? this.rating,
      distance: distance ?? this.distance,
      costForOne: costForOne ?? this.costForOne,
      selectedCuisines: selectedCuisines ?? this.selectedCuisines,
      pureVegOnly: pureVegOnly ?? this.pureVegOnly,
      freeDeliveryOnly: freeDeliveryOnly ?? this.freeDeliveryOnly,
      hasOffersOnly: hasOffersOnly ?? this.hasOffersOnly,
    );
  }

  static List<RestaurantModel> apply({
    required List<RestaurantModel> restaurants,
    required RestaurantFilterCriteria criteria,
    bool isGlobalVegMode = false,
    String selectedCategory = 'All',
  }) {
    var list = List<RestaurantModel>.from(restaurants);

    // 1. Veg Mode
    if (isGlobalVegMode || criteria.pureVegOnly) {
      list = list.where((r) => r.isPureVeg).toList();
    }

    // 2. Delivery Time
    if (criteria.deliveryTime == '30mins') {
      list = list.where((r) => _parseMinutes(r.deliveryTime) <= 30).toList();
    } else if (criteria.deliveryTime == '45mins') {
      list = list.where((r) => _parseMinutes(r.deliveryTime) <= 45).toList();
    }

    // 3. Rating
    if (criteria.rating == '4.0') {
      list = list.where((r) => r.rating >= 4.0).toList();
    } else if (criteria.rating == '4.5') {
      list = list.where((r) => r.rating >= 4.5).toList();
    }

    // 4. Distance
    if (criteria.distance == '1km') {
      list = list.where((r) => r.distanceKm <= 1.5).toList();
    } else if (criteria.distance == '3km') {
      list = list.where((r) => r.distanceKm <= 3.0).toList();
    } else if (criteria.distance == '5km') {
      list = list.where((r) => r.distanceKm <= 5.0).toList();
    }

    // 5. Cost for One
    if (criteria.costForOne == 'under_200') {
      list = list.where((r) => r.priceForOne > 0 && r.priceForOne <= 200).toList();
    } else if (criteria.costForOne == '200_to_500') {
      list = list.where((r) => r.priceForOne > 200 && r.priceForOne <= 500).toList();
    } else if (criteria.costForOne == 'above_500') {
      list = list.where((r) => r.priceForOne > 500).toList();
    }

    // 6. Free Delivery
    if (criteria.freeDeliveryOnly) {
      list = list.where((r) => r.isFreeDelivery || r.deliveryFee == 0).toList();
    }

    // 7. Offers & Discounts
    if (criteria.hasOffersOnly) {
      list = list.where((r) => r.offerBadges.isNotEmpty).toList();
    }

    // 8. Cuisines & Categories Selected from Filter
    if (criteria.selectedCuisines.isNotEmpty) {
      list = list.where((r) {
        final tags = r.tags.map((t) => t.toLowerCase()).toSet();
        final rTags = r.restaurantTags.map((t) => t.toLowerCase()).toSet();
        final nameLower = r.name.toLowerCase();

        return criteria.selectedCuisines.any((c) {
          final cLower = c.toLowerCase().trim();
          final singular = cLower.endsWith('s') ? cLower.substring(0, cLower.length - 1) : cLower;
          return tags.contains(cLower) ||
              tags.contains(singular) ||
              rTags.contains(cLower) ||
              rTags.contains(singular) ||
              nameLower.contains(cLower);
        });
      }).toList();
    }

    // 9. Horizontal category selector if not 'All'
    if (selectedCategory != 'All' && selectedCategory != 'More') {
      final query = selectedCategory.toLowerCase().trim();
      final singular = query.endsWith('s') ? query.substring(0, query.length - 1) : query;
      list = list.where((r) {
        final haystack = '${r.name} ${r.tags.join(' ')} ${r.restaurantTags.join(' ')}'.toLowerCase();
        return haystack.contains(query) || haystack.contains(singular);
      }).toList();
    }

    // 10. Sorting
    switch (criteria.sortBy) {
      case 'rating_high':
        list.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'delivery_fast':
        list.sort((a, b) => _parseMinutes(a.deliveryTime).compareTo(_parseMinutes(b.deliveryTime)));
        break;
      case 'cost_low':
        list.sort((a, b) => a.priceForOne.compareTo(b.priceForOne));
        break;
      case 'cost_high':
        list.sort((a, b) => b.priceForOne.compareTo(a.priceForOne));
        break;
      case 'relevance':
      default:
        break;
    }

    return list;
  }

  static int _parseMinutes(String text) {
    final regExp = RegExp(r'(\d+)');
    final matches = regExp.allMatches(text);
    if (matches.isEmpty) return 999;
    return int.tryParse(matches.first.group(0) ?? '') ?? 999;
  }
}

/// Swiggy / Zomato style two-column Filter Bottom Sheet.
class HomeFilterBottomSheet extends StatefulWidget {
  final RestaurantFilterCriteria initialCriteria;
  final List<CategoryModel> categories;
  final ValueChanged<RestaurantFilterCriteria> onApply;

  const HomeFilterBottomSheet({
    super.key,
    required this.initialCriteria,
    required this.categories,
    required this.onApply,
  });

  static Future<void> show(
    BuildContext context, {
    required RestaurantFilterCriteria initialCriteria,
    required List<CategoryModel> categories,
    required ValueChanged<RestaurantFilterCriteria> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HomeFilterBottomSheet(
        initialCriteria: initialCriteria,
        categories: categories,
        onApply: onApply,
      ),
    );
  }

  @override
  State<HomeFilterBottomSheet> createState() => _HomeFilterBottomSheetState();
}

class _HomeFilterBottomSheetState extends State<HomeFilterBottomSheet> {
  late RestaurantFilterCriteria _current;
  int _selectedTabIndex = 0;

  static const List<String> _tabs = [
    'Sort by',
    'Delivery Time',
    'Cuisines',
    'Rating',
    'Cost for one',
    'More Filters',
  ];

  @override
  void initState() {
    super.initState();
    _current = widget.initialCriteria;
  }

  int _getTabBadgeCount(int tabIndex) {
    switch (tabIndex) {
      case 0:
        return _current.sortBy != 'relevance' ? 1 : 0;
      case 1:
        return _current.deliveryTime != 'any' ? 1 : 0;
      case 2:
        return _current.selectedCuisines.length;
      case 3:
        return _current.rating != 'any' ? 1 : 0;
      case 4:
        return _current.costForOne != 'any' ? 1 : 0;
      case 5:
        int more = 0;
        if (_current.pureVegOnly) more++;
        if (_current.freeDeliveryOnly) more++;
        if (_current.hasOffersOnly) more++;
        if (_current.distance != 'any') more++;
        return more;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.surfaceDark : Colors.white;
    final railColor = isDark ? const Color(0xFF1E242B) : const Color(0xFFF3F4F6);

    return Container(
      height: 0.78.sh,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: EdgeInsets.only(top: 10.h, bottom: 6.h),
              width: 38.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 8.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: const Color(0xFFC80A14),
                      size: 20.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Sort & Filters',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (!_current.isDefault)
                      TextButton(
                        onPressed: () {
                          Haptics.light();
                          setState(() {
                            _current = const RestaurantFilterCriteria();
                          });
                        },
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            color: const Color(0xFFC80A14),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      color: isDark ? Colors.white70 : Colors.black87,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Two-Column Content: Left Rail + Right Options
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Left Navigation Rail
                Container(
                  width: 122.w,
                  color: railColor,
                  child: ListView.builder(
                    itemCount: _tabs.length,
                    itemBuilder: (context, i) {
                      final isSelected = _selectedTabIndex == i;
                      final badgeCount = _getTabBadgeCount(i);

                      return InkWell(
                        onTap: () {
                          Haptics.light();
                          setState(() => _selectedTabIndex = i);
                        },
                        child: Container(
                          color: isSelected ? surfaceColor : Colors.transparent,
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 15.h),
                          child: Row(
                            children: [
                              // Active Indicator bar
                              Container(
                                width: 3.5.w,
                                height: 20.h,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFC80A14) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(2.r),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  _tabs[i],
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFFC80A14)
                                        : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                                  ),
                                ),
                              ),
                              if (badgeCount > 0)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFC80A14),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    '$badgeCount',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // 2. Right Options View
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                    child: _buildRightTabContent(isDark),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Clear filters
                  if (!_current.isDefault) ...[
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () {
                          Haptics.light();
                          setState(() {
                            _current = const RestaurantFilterCriteria();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          padding: EdgeInsets.symmetric(vertical: 13.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        ),
                        child: Text(
                          'Clear All',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                  ],

                  // Apply Button
                  Expanded(
                    flex: 6,
                    child: ElevatedButton(
                      onPressed: () {
                        Haptics.medium();
                        widget.onApply(_current);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC80A14),
                        padding: EdgeInsets.symmetric(vertical: 13.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                        elevation: 0,
                      ),
                      child: Text(
                        _current.activeFiltersCount > 0
                            ? 'Apply Filters (${_current.activeFiltersCount})'
                            : 'Apply Filters',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightTabContent(bool isDark) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildSortByOptions(isDark);
      case 1:
        return _buildDeliveryTimeOptions(isDark);
      case 2:
        return _buildCuisinesOptions(isDark);
      case 3:
        return _buildRatingOptions(isDark);
      case 4:
        return _buildCostForOneOptions(isDark);
      case 5:
        return _buildMoreFiltersOptions(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- 1. Sort By ---
  Widget _buildSortByOptions(bool isDark) {
    final options = [
      {'label': 'Relevance (Default)', 'value': 'relevance'},
      {'label': 'Rating: High to Low', 'value': 'rating_high'},
      {'label': 'Delivery Time: Fastest First', 'value': 'delivery_fast'},
      {'label': 'Cost: Low to High', 'value': 'cost_low'},
      {'label': 'Cost: High to Low', 'value': 'cost_high'},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: options.map((opt) {
        final val = opt['value'] as String;
        final selected = _current.sortBy == val;
        return _buildRadioTile(
          label: opt['label'] as String,
          isSelected: selected,
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(sortBy: val));
          },
          isDark: isDark,
        );
      }).toList(),
    );
  }

  // --- 2. Delivery Time ---
  Widget _buildDeliveryTimeOptions(bool isDark) {
    final options = [
      {'label': 'Any Delivery Time', 'value': 'any'},
      {'label': 'Under 30 mins (Fast)', 'value': '30mins'},
      {'label': 'Under 45 mins', 'value': '45mins'},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: options.map((opt) {
        final val = opt['value'] as String;
        final selected = _current.deliveryTime == val;
        return _buildRadioTile(
          label: opt['label'] as String,
          isSelected: selected,
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(deliveryTime: val));
          },
          isDark: isDark,
        );
      }).toList(),
    );
  }

  // --- 3. Cuisines ---
  Widget _buildCuisinesOptions(bool isDark) {
    final uniqueNames = <String>[];
    for (final c in widget.categories) {
      if (!uniqueNames.contains(c.name) && c.name.trim().isNotEmpty) {
        uniqueNames.add(c.name.trim());
      }
    }

    if (uniqueNames.isEmpty) {
      return Center(
        child: Text(
          'No cuisines found',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13.sp),
        ),
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: uniqueNames.map((name) {
        final isSelected = _current.selectedCuisines.contains(name);
        return _buildCheckboxTile(
          label: name,
          isSelected: isSelected,
          onTap: () {
            Haptics.light();
            final updated = Set<String>.from(_current.selectedCuisines);
            if (isSelected) {
              updated.remove(name);
            } else {
              updated.add(name);
            }
            setState(() => _current = _current.copyWith(selectedCuisines: updated));
          },
          isDark: isDark,
        );
      }).toList(),
    );
  }

  // --- 4. Rating ---
  Widget _buildRatingOptions(bool isDark) {
    final options = [
      {'label': 'Any Rating', 'value': 'any'},
      {'label': 'Rated 4.0+ Stars', 'value': '4.0'},
      {'label': 'Rated 4.5+ Stars', 'value': '4.5'},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: options.map((opt) {
        final val = opt['value'] as String;
        final selected = _current.rating == val;
        return _buildRadioTile(
          label: opt['label'] as String,
          isSelected: selected,
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(rating: val));
          },
          isDark: isDark,
        );
      }).toList(),
    );
  }

  // --- 5. Cost for One ---
  Widget _buildCostForOneOptions(bool isDark) {
    final options = [
      {'label': 'Any Cost', 'value': 'any'},
      {'label': 'Under ₹200 (Budget)', 'value': 'under_200'},
      {'label': '₹200 - ₹500', 'value': '200_to_500'},
      {'label': 'Above ₹500', 'value': 'above_500'},
    ];

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: options.map((opt) {
        final val = opt['value'] as String;
        final selected = _current.costForOne == val;
        return _buildRadioTile(
          label: opt['label'] as String,
          isSelected: selected,
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(costForOne: val));
          },
          isDark: isDark,
        );
      }).toList(),
    );
  }

  // --- 6. More Filters ---
  Widget _buildMoreFiltersOptions(bool isDark) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        _buildCheckboxTile(
          label: 'Pure Veg Only',
          isSelected: _current.pureVegOnly,
          icon: Icons.eco_rounded,
          iconColor: const Color(0xFF10B981),
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(pureVegOnly: !_current.pureVegOnly));
          },
          isDark: isDark,
        ),
        _buildCheckboxTile(
          label: 'Free Delivery',
          isSelected: _current.freeDeliveryOnly,
          icon: Icons.delivery_dining_rounded,
          iconColor: const Color(0xFFC80A14),
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(freeDeliveryOnly: !_current.freeDeliveryOnly));
          },
          isDark: isDark,
        ),
        _buildCheckboxTile(
          label: 'Great Offers & Discounts',
          isSelected: _current.hasOffersOnly,
          icon: Icons.local_offer_rounded,
          iconColor: Colors.amber.shade800,
          onTap: () {
            Haptics.light();
            setState(() => _current = _current.copyWith(hasOffersOnly: !_current.hasOffersOnly));
          },
          isDark: isDark,
        ),
        const Divider(height: 24),
        Text(
          'Maximum Distance',
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
          ),
        ),
        SizedBox(height: 8.h),
        ...[
          {'label': 'Any Distance', 'value': 'any'},
          {'label': 'Under 1 km', 'value': '1km'},
          {'label': 'Under 3 km', 'value': '3km'},
          {'label': 'Under 5 km', 'value': '5km'},
        ].map((dist) {
          final val = dist['value'] as String;
          final selected = _current.distance == val;
          return _buildRadioTile(
            label: dist['label'] as String,
            isSelected: selected,
            onTap: () {
              Haptics.light();
              setState(() => _current = _current.copyWith(distance: val));
            },
            isDark: isDark,
          );
        }),
      ],
    );
  }

  Widget _buildRadioTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 11.h, horizontal: 8.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFC80A14)
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                ),
              ),
            ),
            Container(
              width: 20.r,
              height: 20.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFC80A14) : Colors.grey.shade400,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10.r,
                        height: 10.r,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFC80A14),
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    IconData? icon,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
        child: Row(
          children: [
            Container(
              width: 20.r,
              height: 20.r,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6.r),
                color: isSelected ? const Color(0xFFC80A14) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFFC80A14) : Colors.grey.shade400,
                  width: 1.8,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15.sp,
                    )
                  : null,
            ),
            SizedBox(width: 10.w),
            if (icon != null) ...[
              Icon(icon, size: 18.sp, color: iconColor ?? const Color(0xFFC80A14)),
              SizedBox(width: 6.w),
            ],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5.sp,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFFC80A14)
                      : (isDark ? Colors.white : const Color(0xFF1F2937)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
