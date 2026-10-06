import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../../search/widgets/voice_search_dialog.dart';
import '../../../di/settings_providers.dart';
import '../viewmodels/veg_filter_provider.dart';

class HomeSearchBarRow extends ConsumerWidget {
  const HomeSearchBarRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isVegOnly = ref.watch(vegFilterProvider);
    final showVegToggle = ref.watch(
      businessSettingsProvider.select((s) => s.vegNonVegToggle),
    );

    return Row(
      children: [
        // Left: Rounded White / Surface Capsule Search Bar
        Expanded(
          child: Container(
            height: 40.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(30.r),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFE5E7EB),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Search Icon & Prompt Click
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Haptics.light();
                      context.push(RouteNames.search);
                    },
                    child: Row(
                      children: [
                        Icon(
                          Icons.search,
                          color: const Color(0xFFC80A14), // Brand Red
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'Search restaurants, dishes...',
                            style: TextStyle(
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                              fontSize: 12.5.sp,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Mic Icon
                InkWell(
                  onTap: () async {
                    Haptics.light();
                    final query = await VoiceSearchDialog.show(context);
                    if (query != null &&
                        query.trim().isNotEmpty &&
                        context.mounted) {
                      context.push(RouteNames.search, extra: query.trim());
                    }
                  },
                  child: Padding(
                    padding: EdgeInsets.only(left: 4.w),
                    child: Icon(
                      Icons.mic_none_rounded,
                      color: const Color(0xFFC80A14), // Brand Red
                      size: 18.sp,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right: VEG MODE Toggle Pill Button — hidden when the admin has
        // switched the veg / non-veg toggle off.
        if (showVegToggle) SizedBox(width: 10.w),
        if (showVegToggle)
        InkWell(
          onTap: () {
            Haptics.light();
            ref.read(vegFilterProvider.notifier).toggle();
          },
          borderRadius: BorderRadius.circular(8.r),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'VEG\nMODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1F2937),
                  letterSpacing: 0.4,
                  height: 1.1,
                ),
              ),
              SizedBox(height: 2.h),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 32.w,
                height: 16.h,
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.r),
                  color: isVegOnly
                      ? const Color(0xFF10B981) // Emerald Green
                      : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                ),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: isVegOnly
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    width: 12.h,
                    height: 12.h,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
