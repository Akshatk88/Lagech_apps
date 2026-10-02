import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';

import 'package:go_router/go_router.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/address_model.dart';
import '../../../data/models/zone_model.dart';
import '../../../di/catalog_providers.dart';
import '../../../di/location_providers.dart';
import '../../branding/app_colors.dart';
import '../../navigation/route_names.dart';
import '../../address/viewmodels/address_viewmodel.dart';
import '../viewmodels/home_viewmodel.dart';
import '../viewmodels/zone_viewmodel.dart';

/// Provider for fetching all admin-configured zones (10-min cache).
final allZonesProvider = FutureProvider<List<ServiceableZone>>((ref) {
  return ref.read(catalogRemoteDataSourceProvider).getAllZones();
});

/// Beautiful bottom sheet for picking a delivery location.
///
/// Priority order displayed:
///   1. "Use GPS" chip — auto-detects and locks current position
///   2. Admin-configured zones (from backend)
///   3. Free-text manual entry that also drives the filter
///
/// Selecting any option sets [activeLocationProvider] so the home feed,
/// header, and restaurant-list viewmodel all react automatically.
class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({super.key});

  /// Convenience helper — shows as a draggable bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (ctx) => const LocationPickerSheet(),
    );
  }

  @override
  ConsumerState<LocationPickerSheet> createState() =>
      _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet>
    with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _query = '';
  bool _isDetectingGps = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _scaleAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressViewModelProvider.notifier).load();
    });
  }

  void _pickSavedAddress(AddressModel address) {
    Haptics.light();
    ref.read(activeLocationProvider.notifier).setLocation(
      UserLocationInfo(
        title: address.title.isNotEmpty
            ? address.title
            : (address.street.isNotEmpty ? address.street : address.type),
        subtitle: address.fullAddress,
        latitude: address.latitude,
        longitude: address.longitude,
        isManual: false,
      ),
    );
    ref.invalidate(zoneViewModelProvider);
    ref.invalidate(homeViewModelProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _addNewAddress() {
    Haptics.light();
    Navigator.of(context).pop();
    context.push(RouteNames.addAddress);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ─────────────────── GPS detection ───────────────────────────────────────

  Future<void> _detectGps() async {
    Haptics.medium();
    setState(() => _isDetectingGps = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('Location services are disabled.');
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        _showMessage('Location permission denied. Please enable in settings.');
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      // Detect zone from backend
      final zone = await ref.read(catalogRemoteDataSourceProvider).detectZone(
            lat: pos.latitude,
            lng: pos.longitude,
          );
      final areaName = zone.name ?? 'Current Location';
      ref.read(activeLocationProvider.notifier).setLocation(
            UserLocationInfo(
              title: areaName,
              subtitle: 'GPS detected • ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
              latitude: pos.latitude,
              longitude: pos.longitude,
            ),
          );
      // Refresh zone-scoped restaurant list
      ref.invalidate(zoneViewModelProvider);
      Haptics.success();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _showMessage('Could not detect location. Try again.');
    } finally {
      if (mounted) setState(() => _isDetectingGps = false);
    }
  }

  // ─────────────────── Pick admin zone ────────────────────────────────────

  void _pickZone(ServiceableZone zone) {
    Haptics.light();
    ref.read(activeLocationProvider.notifier).setLocation(
          UserLocationInfo(
            title: zone.name,
            subtitle: zone.city ?? zone.description ?? 'Selected area',
            latitude: zone.latitude,
            longitude: zone.longitude,
          ),
        );
    ref.invalidate(zoneViewModelProvider);
    if (mounted) Navigator.of(context).pop();
  }

  // ─────────────────── Manual entry ───────────────────────────────────────

  void _applyManualEntry() {
    final text = _searchController.text.trim();
    if (text.isEmpty) return;
    Haptics.light();
    ref.read(activeLocationProvider.notifier).setLocation(
          UserLocationInfo(
            title: text,
            subtitle: 'Manually entered',
            isManual: true,
          ),
        );
    ref.invalidate(zoneViewModelProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _showMessage(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─────────────────── Build ──────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final zonesAsync = ref.watch(allZonesProvider);
    final savedAddresses = ref.watch(addressViewModelProvider);

    return ScaleTransition(
      scale: _scaleAnim,
      alignment: Alignment.bottomCenter,
      child: DraggableScrollableSheet(
        initialChildSize: 0.70,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.backgroundDark : Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 30,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              children: [
                // ─── Drag handle ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.only(top: 10.h, bottom: 4.h),
                  child: Container(
                    width: 38.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white24
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // ─── Header ─────────────────────────────────────────────
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                  child: Row(
                    children: [
                      Container(
                        width: 38.r,
                        height: 38.r,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: AppColors.primary,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose your location',
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Restaurants are filtered by your area',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Haptics.light();
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: 32.r,
                          height: 32.r,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white12
                                : Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16.sp,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ─── Search input ────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Container(
                    height: 46.h,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 14.w),
                        Icon(
                          Icons.search_rounded,
                          size: 20.sp,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : Colors.grey.shade500,
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            textInputAction: TextInputAction.done,
                            onChanged: (v) =>
                                setState(() => _query = v.trim().toLowerCase()),
                            onSubmitted: (_) => _applyManualEntry(),
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search city or area...',
                              hintStyle: TextStyle(
                                fontSize: 14.sp,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : Colors.grey.shade400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        if (_query.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              child: Icon(
                                Icons.close_rounded,
                                size: 16.sp,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 12.h),

                Divider(
                  height: 1,
                  color: isDark
                      ? AppColors.borderDark
                      : Colors.grey.shade100,
                ),

                // ─── Content list ────────────────────────────────────────
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                    children: [
                      // "Use GPS" option ──────────────────────────────────
                      if (_query.isEmpty) ...[
                        _buildGpsOption(isDark),
                        SizedBox(height: 16.h),
                        if (savedAddresses.isNotEmpty) ...[
                          _buildSectionLabel('Saved Addresses', isDark),
                          SizedBox(height: 8.h),
                          ...savedAddresses.map((addr) => _buildSavedAddressTile(addr, isDark)),
                          SizedBox(height: 10.h),
                        ],
                        _buildAddNewAddressButton(isDark),
                        SizedBox(height: 18.h),
                        _buildSectionLabel('Available Locations', isDark),
                        SizedBox(height: 8.h),
                      ],

                      // Admin zones ──────────────────────────────────────
                      zonesAsync.when(
                        loading: () => _buildZonesLoading(),
                        error: (_, _) => _buildZonesFallback(isDark),
                        data: (zones) {
                          final filtered = _query.isEmpty
                              ? zones
                              : zones
                                  .where((z) =>
                                      z.name
                                          .toLowerCase()
                                          .contains(_query) ||
                                      (z.city
                                              ?.toLowerCase()
                                              .contains(_query) ??
                                          false))
                                  .toList();

                          if (filtered.isEmpty) {
                            return _buildManualOption(isDark);
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ...filtered
                                  .map((z) => _buildZoneTile(z, isDark)),
                              SizedBox(height: 12.h),
                              if (_query.isNotEmpty)
                                _buildManualOption(isDark),
                            ],
                          );
                        },
                      ),

                      SizedBox(height: 24.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGpsOption(bool isDark) {
    return GestureDetector(
      onTap: _isDetectingGps ? null : _detectGps,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.08),
              AppColors.primary.withValues(alpha: 0.03),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: _isDetectingGps
                  ? Padding(
                      padding: EdgeInsets.all(10.r),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      color: AppColors.primary,
                      size: 20.sp,
                    ),
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isDetectingGps ? 'Detecting your location…' : 'Use current location',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  Text(
                    'Auto-detect via GPS',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.primary.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isDetectingGps)
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavedAddressTile(AddressModel address, bool isDark) {
    final active = ref.watch(activeLocationProvider);
    final isSelected = (active?.latitude != null &&
            address.latitude != null &&
            (active!.latitude! - address.latitude!).abs() < 0.0001 &&
            (active.longitude! - address.longitude!).abs() < 0.0001) ||
        (active?.title == address.title && address.title.isNotEmpty);

    IconData typeIcon = Icons.location_on_outlined;
    if (address.type.toLowerCase() == 'home') {
      typeIcon = Icons.home_outlined;
    } else if (address.type.toLowerCase() == 'office') {
      typeIcon = Icons.work_outline;
    }

    return GestureDetector(
      onTap: () => _pickSavedAddress(address),
      child: Container(
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.primary.withValues(alpha: 0.06))
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : const Color(0xFFEEEFF1)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                shape: BoxShape.circle,
              ),
              child: Icon(
                typeIcon,
                color: isSelected ? AppColors.primary : (isDark ? Colors.white70 : Colors.black87),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        address.title.isNotEmpty ? address.title : address.type,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppColors.primary
                              : (isDark ? Colors.white : AppColors.textPrimaryLight),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          address.type.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    address.fullAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? AppColors.textSecondaryDark : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20.sp,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddNewAddressButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _addNewAddress,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AppColors.primary, width: 1.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          padding: EdgeInsets.symmetric(vertical: 12.h),
          backgroundColor: isDark ? AppColors.primaryTintDark : const Color(0xFFFEF2F2),
        ),
        icon: Icon(Icons.add_location_alt_outlined, color: AppColors.primary, size: 18.sp),
        label: Text(
          '+ Add New Address',
          style: TextStyle(
            fontSize: 13.5.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, bool isDark) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 10.5.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: isDark ? Colors.white38 : Colors.grey.shade400,
      ),
    );
  }

  Widget _buildZoneTile(ServiceableZone zone, bool isDark) {
    final active = ref.watch(activeLocationProvider);
    final isSelected = active?.title == zone.name;

    return GestureDetector(
      onTap: () => _pickZone(zone),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.18)
                  : AppColors.primary.withValues(alpha: 0.06))
              : (isDark ? AppColors.cardDark : Colors.white),
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.4)
                : (isDark ? AppColors.borderDark : const Color(0xFFEEEFF1)),
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : Colors.grey.shade50),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.location_city_rounded,
                color: isSelected
                    ? AppColors.primary
                    : (isDark ? Colors.white54 : Colors.grey.shade400),
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    zone.name,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                    ),
                  ),
                  if (zone.city != null && zone.city!.isNotEmpty)
                    Text(
                      zone.city!,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : Colors.grey.shade500,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13.sp,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualOption(bool isDark) {
    if (_query.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _applyManualEntry,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 13.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFEEEFF1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36.r,
              height: 36.r,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.edit_location_alt_rounded,
                color: isDark ? Colors.white54 : Colors.grey.shade400,
                size: 18.sp,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Use "$_query"',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    'Search for restaurants in this area',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13.sp,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZonesLoading() {
    return Column(
      children: List.generate(
        3,
        (i) => Container(
          margin: EdgeInsets.only(bottom: 8.h),
          height: 64.h,
          decoration: BoxDecoration(
            color: Colors.grey.shade200.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      ),
    );
  }

  Widget _buildZonesFallback(bool isDark) {
    return _buildManualOption(isDark);
  }
}
