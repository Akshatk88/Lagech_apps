import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/haptics.dart';
import '../../../data/models/address_model.dart';
import '../../../di/location_providers.dart';
import '../../../platform/location/location_service.dart';
import '../../branding/app_colors.dart';
import '../../home/viewmodels/home_viewmodel.dart';
import '../../home/viewmodels/zone_viewmodel.dart';
import '../../navigation/route_names.dart';
import '../viewmodels/address_viewmodel.dart';
import '../viewmodels/recent_locations_viewmodel.dart';

/// "Select a location": where the home feed, restaurants and delivery estimates
/// are scoped to.
///
/// One list for everything a user might pick — their live GPS position, a saved
/// address, a place found by search, a place near them, or somewhere they chose
/// before. Adding or editing an address hands off to [AddAddressScreen]'s map.
class SelectLocationScreen extends ConsumerStatefulWidget {
  const SelectLocationScreen({super.key});

  @override
  ConsumerState<SelectLocationScreen> createState() =>
      _SelectLocationScreenState();
}

class _SelectLocationScreenState extends ConsumerState<SelectLocationScreen> {
  /// Nearby results by ~100 m cell, so reopening the screen (or a small GPS
  /// drift) does not bill another Places call.
  static final Map<String, ({DateTime at, List<NearbyPlace> places})>
      _nearbyCache = {};
  static const _nearbyTtl = Duration(minutes: 10);

  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  Timer? _debounce;

  String _query = '';
  bool _searching = false;
  List<NearbyPlace> _results = const [];

  /// Discards a slow response that arrives after a newer search was typed.
  int _searchSeq = 0;

  ({double lat, double lng})? _here;
  bool _gpsAllowed = true;
  String _currentSubtitle = '';

  List<NearbyPlace> _nearby = const [];
  bool _nearbyLoading = true;

  /// True while a saved address / GPS selection is being applied.
  bool _busy = false;

  bool get _isSearching => _query.length >= 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(addressViewModelProvider.notifier).load();
      _locate();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ───────────────────────── Where the user is ─────────────────────────────

  /// Works out a position for distances and "nearby" WITHOUT prompting: opening
  /// this screen must not throw a permission dialog at someone who is only
  /// looking at their saved addresses.
  Future<void> _locate() async {
    final service = ref.read(locationServiceProvider);

    var allowed = false;
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      allowed = enabled &&
          (permission == LocationPermission.whileInUse ||
              permission == LocationPermission.always);
    } catch (_) {}

    ({double lat, double lng})? here;
    if (allowed) {
      here = await service.lastKnownLatLng();
      if (mounted && here != null) setState(() => _here = here);
      try {
        final fix = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
        here = (lat: fix.latitude, lng: fix.longitude);
      } catch (_) {}
    }

    // No GPS: fall back to the place already chosen, so distances still mean
    // something.
    if (here == null) {
      final active = ref.read(activeLocationProvider);
      if (active?.latitude != null && active?.longitude != null) {
        here = (lat: active!.latitude!, lng: active.longitude!);
      }
    }

    if (!mounted) return;
    setState(() {
      _gpsAllowed = allowed;
      _here = here;
    });

    if (here == null) {
      setState(() => _nearbyLoading = false);
      return;
    }
    unawaited(_loadNearby(here));
    if (allowed) unawaited(_describeCurrent(here));
  }

  Future<void> _describeCurrent(({double lat, double lng}) at) async {
    try {
      final geo =
          await ref.read(locationServiceProvider).reverseGeocode(at.lat, at.lng);
      final text = [geo.area, geo.city].where((s) => s.isNotEmpty).toSet().join(', ');
      final line = text.isNotEmpty ? text : geo.fullAddress;
      if (mounted && line.isNotEmpty) setState(() => _currentSubtitle = line);
    } catch (_) {}
  }

  Future<void> _loadNearby(({double lat, double lng}) at) async {
    final key = '${at.lat.toStringAsFixed(3)},${at.lng.toStringAsFixed(3)}';
    final hit = _nearbyCache[key];
    if (hit != null && DateTime.now().difference(hit.at) < _nearbyTtl) {
      if (mounted) {
        setState(() {
          _nearby = hit.places;
          _nearbyLoading = false;
        });
      }
      return;
    }

    final places =
        await ref.read(locationServiceProvider).nearbyPlaces(at.lat, at.lng);
    if (places.isNotEmpty) {
      _nearbyCache[key] = (at: DateTime.now(), places: places);
    }
    if (!mounted) return;
    setState(() {
      _nearby = places;
      _nearbyLoading = false;
    });
  }

  // ───────────────────────────── Search ────────────────────────────────────

  void _onQueryChanged(String value) {
    final text = value.trim();
    _debounce?.cancel();
    setState(() {
      _query = text;
      if (text.length < 3) {
        _results = const [];
        _searching = false;
      }
    });
    if (text.length < 3) {
      _searchSeq++;
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () => _runSearch(text));
  }

  Future<void> _runSearch(String text) async {
    final seq = ++_searchSeq;
    setState(() => _searching = true);
    final results = await ref
        .read(locationServiceProvider)
        .searchPlacesNear(text, lat: _here?.lat, lng: _here?.lng);
    if (!mounted || seq != _searchSeq) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  // ─────────────────────────── Choosing a location ─────────────────────────

  /// Makes [title] the location the app works from, remembers it, and leaves.
  Future<void> _applyLocation({
    required String title,
    required String subtitle,
    required double latitude,
    required double longitude,
  }) async {
    Haptics.light();
    ref.read(activeLocationProvider.notifier).setLocation(
          UserLocationInfo(
            title: title,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
            isManual: true,
          ),
        );
    _refreshForNewLocation();
    unawaited(ref.read(recentLocationsProvider.notifier).add(
          RecentLocation(
            title: title,
            subtitle: subtitle,
            latitude: latitude,
            longitude: longitude,
          ),
        ));
    if (mounted) context.pop();
  }

  void _refreshForNewLocation() {
    ref.invalidate(userLatLngProvider);
    ref.invalidate(zoneViewModelProvider);
    ref.invalidate(homeViewModelProvider);
  }

  void _pickPlace(NearbyPlace place) => _applyLocation(
        title: place.name,
        subtitle: place.address,
        latitude: place.latitude,
        longitude: place.longitude,
      );

  void _pickRecent(RecentLocation recent) => _applyLocation(
        title: recent.title,
        subtitle: recent.subtitle,
        latitude: recent.latitude,
        longitude: recent.longitude,
      );

  Future<void> _pickSaved(AddressModel address) async {
    if (_busy) return;
    final lat = address.latitude;
    final lng = address.longitude;
    final title = address.title.isNotEmpty
        ? address.title
        : (address.street.isNotEmpty
            ? address.street
            : (address.city.isNotEmpty ? address.city : 'Selected Address'));
    final subtitle = address.fullAddress.isNotEmpty
        ? address.fullAddress
        : [address.street, address.city, address.state, address.zipCode]
            .where((s) => s.isNotEmpty)
            .join(', ');

    if (lat == null || lng == null) {
      _message('This address has no map location. Edit it to pin it on the map.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Also the default for checkout, as everywhere else an address is picked.
      await ref.read(addressViewModelProvider.notifier).setDefaultAddress(address.id);
      await _applyLocation(
        title: title,
        subtitle: subtitle,
        latitude: lat,
        longitude: lng,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_busy) return;
    Haptics.medium();
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _message(
          'Location services are turned off.',
          actionLabel: 'Turn on',
          onAction: Geolocator.openLocationSettings,
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        _message(
          'Location permission is blocked for this app.',
          actionLabel: 'Settings',
          onAction: Geolocator.openAppSettings,
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        _message('Allow location access to use your current location.');
        return;
      }

      final notifier = ref.read(activeLocationProvider.notifier);
      final ok = await notifier.autoFetchGpsLocation(force: true);
      if (!ok) {
        _message("Couldn't get your location. Please try again.");
        return;
      }
      // Live GPS replaces any place picked earlier — also for the next launch.
      await notifier.forgetSavedSelection();
      _refreshForNewLocation();
      Haptics.success();
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addAddress() async {
    Haptics.light();
    final saved = await context.push<dynamic>(RouteNames.addAddress);
    if (!mounted) return;
    ref.read(addressViewModelProvider.notifier).load();
    // A saved address is already applied as the location; nothing left to pick.
    if (saved != null) context.pop();
  }

  Future<void> _editAddress(AddressModel address) async {
    Haptics.light();
    final saved =
        await context.push<dynamic>(RouteNames.addAddress, extra: address);
    if (!mounted) return;
    ref.read(addressViewModelProvider.notifier).load();
    if (saved != null) context.pop();
  }

  Future<void> _deleteAddress(AddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete address?'),
        content: Text(
          '"${address.title.isNotEmpty ? address.title : address.type}" will be removed from your saved addresses.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok =
        await ref.read(addressViewModelProvider.notifier).deleteAddress(address.id);
    if (!ok) _message("Couldn't delete this address. Please try again.");
  }

  Future<void> _setDefault(AddressModel address) async {
    final ok = await ref
        .read(addressViewModelProvider.notifier)
        .setDefaultAddress(address.id);
    _message(ok ? 'Default address updated.' : "Couldn't update the default address.");
  }

  void _shareAddress(AddressModel address) {
    final lines = <String>[
      if (address.title.isNotEmpty) address.title,
      address.fullAddress,
      if (address.latitude != null && address.longitude != null)
        'https://www.google.com/maps/search/?api=1&query=${address.latitude},${address.longitude}',
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  void _message(String text, {String? actionLabel, VoidCallback? onAction}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          behavior: SnackBarBehavior.floating,
          action: actionLabel == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
        ),
      );
  }

  // ────────────────────────────── Formatting ───────────────────────────────

  String? _distanceTo(double? lat, double? lng) {
    final here = _here;
    if (here == null || lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(here.lat, here.lng, lat, lng);
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return km < 10 ? '${km.toStringAsFixed(1)} km' : '${km.round()} km';
  }

  String _phone(String? raw) {
    final digits = (raw ?? '').trim();
    if (digits.isEmpty) return '';
    if (digits.startsWith('+')) return digits;
    final plain = digits.replaceAll(RegExp(r'\D'), '');
    return plain.length == 10 ? '+91-$plain' : digits;
  }

  // ─────────────────────────────── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : const Color(0xFFF4F5FA);
    final saved = ref.watch(addressViewModelProvider);
    final recents = ref.watch(recentLocationsProvider);

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 32.h),
                  children: _isSearching
                      ? _buildSearchResults(isDark)
                      : _buildSections(isDark, saved, recents),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final textColor = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 12.h, 16.w, 8.h),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 30.sp, color: textColor),
                tooltip: 'Close',
              ),
              Text(
                'Select a location',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          _buildSearchField(isDark),
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 52.h,
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isDark ? AppColors.borderDark : const Color(0xFFE3E5EE),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: AppColors.primary, size: 24.sp),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _debounce?.cancel();
                if (v.trim().length >= 3) _runSearch(v.trim());
              },
              style: TextStyle(
                fontSize: 15.sp,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              decoration: InputDecoration(
                hintText: 'Search for area, street name…',
                hintStyle: TextStyle(
                  fontSize: 15.sp,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                // The theme fills every field; the container draws the background.
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                _onQueryChanged('');
              },
              child: Icon(Icons.close_rounded,
                  size: 20.sp,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildSearchResults(bool isDark) {
    if (_searching && _results.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48.h),
          child: const Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_results.isEmpty) {
      return [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48.h, horizontal: 24.w),
          child: Column(
            children: [
              Icon(Icons.search_off_rounded,
                  size: 44.sp,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              SizedBox(height: 12.h),
              Text(
                'No places found for "$_query"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'Try a nearby landmark, area or street name.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    return [
      _card(
        isDark,
        [
          for (final place in _results)
            _PlaceRow(
              icon: Icons.location_on_outlined,
              distance: _distanceTo(place.latitude, place.longitude),
              title: place.name,
              subtitle: place.address,
              onTap: () => _pickPlace(place),
            ),
        ],
      ),
    ];
  }

  List<Widget> _buildSections(
    bool isDark,
    List<AddressModel> saved,
    List<RecentLocation> recents,
  ) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return [
      SizedBox(height: 8.h),
      _card(isDark, [
        _ActionRow(
          icon: Icons.my_location_rounded,
          title: 'Use current location',
          subtitle: _gpsAllowed
              ? (_currentSubtitle.isNotEmpty
                  ? _currentSubtitle
                  : 'Using GPS')
              : 'Tap to allow location access',
          onTap: _useCurrentLocation,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
        _ActionRow(
          icon: Icons.add_rounded,
          title: 'Add Address',
          onTap: _addAddress,
          primaryText: primaryText,
          secondaryText: secondaryText,
        ),
      ]),
      if (saved.isNotEmpty) ...[
        _sectionLabel('Saved addresses', secondaryText),
        for (final address in saved) _buildSavedCard(address, isDark),
      ],
      if (_nearbyLoading || _nearby.isNotEmpty) ...[
        _sectionLabel('Nearby locations', secondaryText),
        if (_nearbyLoading)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 20.h),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          _card(isDark, [
            for (final place in _nearby)
              _PlaceRow(
                icon: Icons.location_on_outlined,
                distance: _distanceTo(place.latitude, place.longitude),
                title: place.name,
                subtitle: place.address,
                onTap: () => _pickPlace(place),
              ),
          ]),
      ],
      if (recents.isNotEmpty) ...[
        _sectionLabel('Recent locations', secondaryText),
        _card(isDark, [
          for (final recent in recents)
            _PlaceRow(
              icon: Icons.schedule_rounded,
              distance: _distanceTo(recent.latitude, recent.longitude),
              title: recent.title,
              subtitle: recent.subtitle,
              onTap: () => _pickRecent(recent),
            ),
        ]),
      ],
    ];
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: EdgeInsets.fromLTRB(4.w, 24.h, 4.w, 10.h),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
            color: color,
          ),
        ),
      );

  Widget _card(bool isDark, List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(Divider(
          height: 1,
          thickness: 1,
          indent: 16.w,
          endIndent: 16.w,
          color: isDark ? AppColors.borderDark : const Color(0xFFF0F1F6),
        ));
      }
      children.add(rows[i]);
    }
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSavedCard(AddressModel address, bool isDark) {
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final distance = _distanceTo(address.latitude, address.longitude);
    final phone = _phone(address.contactPhone);

    final type = address.type.toLowerCase();
    final icon = type == 'home'
        ? Icons.home_outlined
        : (type == 'office' || type == 'work')
            ? Icons.work_outline_rounded
            : Icons.location_on_outlined;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: isDark ? AppColors.cardDark : Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          borderRadius: BorderRadius.circular(20.r),
          onTap: () => _pickSaved(address),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 12.w, 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44.w,
                  child: Column(
                    children: [
                      Icon(icon, size: 28.sp, color: secondaryText),
                      if (distance != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          distance,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.sp, color: secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              address.title.isNotEmpty ? address.title : address.type,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 17.sp,
                                fontWeight: FontWeight.w700,
                                color: primaryText,
                              ),
                            ),
                          ),
                          if (address.isDefault) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'Default',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        address.fullAddress,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.sp,
                          height: 1.3,
                          color: secondaryText,
                        ),
                      ),
                      if (phone.isNotEmpty) ...[
                        SizedBox(height: 6.h),
                        Text(
                          'Phone number: $phone',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: primaryText,
                          ),
                        ),
                      ],
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          _MenuButton(
                            isDark: isDark,
                            isDefault: address.isDefault,
                            onEdit: () => _editAddress(address),
                            onSetDefault: () => _setDefault(address),
                            onDelete: () => _deleteAddress(address),
                          ),
                          SizedBox(width: 10.w),
                          _CircleIconButton(
                            icon: Icons.share_outlined,
                            isDark: isDark,
                            tooltip: 'Share address',
                            onTap: () => _shareAddress(address),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Use current location" / "Add Address": icon, title, optional subtitle, chevron.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.primaryText,
    required this.secondaryText,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
        child: Row(
          children: [
            SizedBox(
              width: 44.w,
              child: Icon(icon, size: 26.sp, color: AppColors.primary),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 15.sp, color: secondaryText),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 26.sp, color: secondaryText),
          ],
        ),
      ),
    );
  }
}

/// A place in the nearby / recent / search lists: icon over its distance, then
/// the name and address.
class _PlaceRow extends StatelessWidget {
  const _PlaceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.distance,
  });

  final IconData icon;
  final String? distance;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondaryText = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44.w,
              child: Column(
                children: [
                  Icon(icon, size: 28.sp, color: secondaryText),
                  if (distance != null) ...[
                    SizedBox(height: 4.h),
                    Text(
                      distance!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.sp, color: secondaryText),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: 3.h),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.sp,
                        height: 1.3,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 40.r,
          height: 40.r,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppColors.borderDark : const Color(0xFFE3E5EE),
            ),
          ),
          child: Icon(icon, size: 18.sp, color: AppColors.primary),
        ),
      ),
    );
  }
}

enum _AddressAction { edit, setDefault, delete }

/// The "…" button: edit, make default, delete.
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.isDark,
    required this.isDefault,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDelete,
  });

  final bool isDark;
  final bool isDefault;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AddressAction>(
      tooltip: 'More',
      padding: EdgeInsets.zero,
      onSelected: (action) {
        switch (action) {
          case _AddressAction.edit:
            onEdit();
          case _AddressAction.setDefault:
            onSetDefault();
          case _AddressAction.delete:
            onDelete();
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: _AddressAction.edit, child: Text('Edit')),
        if (!isDefault)
          const PopupMenuItem(
            value: _AddressAction.setDefault,
            child: Text('Set as default'),
          ),
        const PopupMenuItem(value: _AddressAction.delete, child: Text('Delete')),
      ],
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? AppColors.borderDark : const Color(0xFFE3E5EE),
          ),
        ),
        child: Icon(Icons.more_horiz_rounded, size: 18.sp, color: AppColors.primary),
      ),
    );
  }
}
