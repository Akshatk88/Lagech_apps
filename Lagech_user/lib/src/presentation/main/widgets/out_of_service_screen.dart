import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../branding/app_colors.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../navigation/route_names.dart';

/// Replaces the whole app, bottom navigation included, while the selected
/// location is outside every delivery zone. [MainAppShell] swaps back to the
/// normal app by itself once a location inside a zone is chosen.
class OutOfServiceScreen extends ConsumerWidget {
  const OutOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 32.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'We don’t deliver to this area',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30.sp,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                  SizedBox(height: 36.h),
                  SizedBox(
                    width: double.infinity,
                    height: 58.h,
                    child: ElevatedButton.icon(
                      // Same flow as the location in the home header.
                      onPressed: () async {
                        Haptics.light();
                        await context.push(RouteNames.selectLocation);
                        if (context.mounted) {
                          ref.invalidate(addressViewModelProvider);
                          ref.invalidate(homeViewModelProvider);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      icon: Icon(Icons.location_on_rounded, size: 26.sp),
                      label: Text(
                        'Change Location',
                        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
