import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/alert_permission_flow.dart';
import '../../../core/services/device_readiness_service.dart';

/// Everything the rider needs to grant, asked for up front when the app opens
/// instead of piecemeal the first time they press "Go online".
enum _Step {
  location,
  backgroundLocation,
  notifications,
  fullScreenIntent,
  overlay,
  battery,
  autostart,
}

extension on _Step {
  String get title => switch (this) {
        _Step.location => 'Location',
        _Step.backgroundLocation => 'Location all the time',
        _Step.notifications => 'Notifications',
        _Step.fullScreenIntent => 'Full-screen order alerts',
        _Step.overlay => 'Display over other apps',
        _Step.battery => 'Unrestricted battery',
        _Step.autostart => 'Autostart',
      };

  String get description => switch (this) {
        _Step.location =>
          'Needed to go online and to be matched with nearby orders.',
        _Step.backgroundLocation =>
          'Choose "Allow all the time" so customers can track you while your '
              'screen is off.',
        _Step.notifications => 'Required to be told a new order has arrived.',
        _Step.fullScreenIntent =>
          'Lets the order card wake your phone instead of showing as a banner.',
        _Step.overlay =>
          'Shows the order card on top of any app so you can accept instantly.',
        _Step.battery =>
          'Stops your phone pausing the app and delaying orders.',
        _Step.autostart =>
          'Your phone brand blocks background apps. Turn on Autostart for this '
              'app.',
      };

  IconData get icon => switch (this) {
        _Step.location => Icons.location_on_rounded,
        _Step.backgroundLocation => Icons.share_location_rounded,
        _Step.notifications => Icons.notifications_active_rounded,
        _Step.fullScreenIntent => Icons.fullscreen_rounded,
        _Step.overlay => Icons.picture_in_picture_alt_rounded,
        _Step.battery => Icons.battery_charging_full_rounded,
        _Step.autostart => Icons.restart_alt_rounded,
      };
}

class PermissionSetupScreen extends StatefulWidget {
  const PermissionSetupScreen({super.key});

  static bool _shownThisLaunch = false;

  /// Opens the screen when anything is still missing — once per app launch, so
  /// a rider who chooses "Later" is asked again next time, not on every tab.
  static Future<void> showIfNeeded(BuildContext context) async {
    if (!Platform.isAndroid || _shownThisLaunch) return;
    _shownThisLaunch = true;
    final missing = await _PermissionChecks.missingRequired();
    if (missing.isEmpty || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const PermissionSetupScreen(),
      ),
    );
  }

  @override
  State<PermissionSetupScreen> createState() => _PermissionSetupScreenState();
}

/// Reads and requests each step.
class _PermissionChecks {
  static Future<bool> isGranted(_Step step) async {
    switch (step) {
      case _Step.location:
        if (!await Geolocator.isLocationServiceEnabled()) return false;
        final p = await Geolocator.checkPermission();
        return p == LocationPermission.whileInUse ||
            p == LocationPermission.always;
      case _Step.backgroundLocation:
        return Permission.locationAlways.isGranted;
      case _Step.notifications:
        return AlertPermissionFlow.isGranted(AlertPermission.notifications);
      case _Step.fullScreenIntent:
        return AlertPermissionFlow.isGranted(AlertPermission.fullScreenIntent);
      case _Step.overlay:
        return AlertPermissionFlow.isGranted(AlertPermission.overlay);
      case _Step.battery:
        return AlertPermissionFlow.isGranted(
          AlertPermission.batteryOptimisation,
        );
      case _Step.autostart:
        // No ROM lets an app read this back, so it is never reported as done.
        return false;
    }
  }

  /// Steps whose state can be read, still missing. Autostart is left out: it
  /// can never read as granted, and would reopen this screen forever.
  static Future<List<_Step>> missingRequired() async {
    final missing = <_Step>[];
    for (final step in _Step.values) {
      if (step == _Step.autostart) continue;
      if (!await isGranted(step)) missing.add(step);
    }
    return missing;
  }

  /// Opens the grant path for [step] and returns once the rider is back.
  static Future<void> request(_Step step) async {
    switch (step) {
      case _Step.location:
        if (!await Geolocator.isLocationServiceEnabled()) {
          await Geolocator.openLocationSettings();
          await AlertPermissionFlow.waitForResume();
          return;
        }
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) {
          p = await Geolocator.requestPermission();
        }
        if (p == LocationPermission.deniedForever) {
          await Geolocator.openAppSettings();
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.backgroundLocation:
        // Android only offers "all the time" after the foreground grant.
        if (!await isGranted(_Step.location)) await request(_Step.location);
        final status = await Permission.locationAlways.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.notifications:
        final status = await Permission.notification.request();
        if (status.isPermanentlyDenied) {
          await openAppSettings();
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.fullScreenIntent:
        if (await AlertPermissionFlow.request(AlertPermission.fullScreenIntent)) {
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.overlay:
        if (await AlertPermissionFlow.request(AlertPermission.overlay)) {
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.battery:
        if (await AlertPermissionFlow.request(
          AlertPermission.batteryOptimisation,
        )) {
          await AlertPermissionFlow.waitForResume();
        }
      case _Step.autostart:
        await DeviceReadinessService.fix('autostart');
        await AlertPermissionFlow.waitForResume();
    }
  }
}

class _PermissionSetupScreenState extends State<PermissionSetupScreen>
    with WidgetsBindingObserver {
  Map<_Step, bool>? _granted;
  bool _hasAutostart = false;
  bool _autostartOpened = false;
  bool _working = false;

  List<_Step> get _steps => [
        for (final step in _Step.values)
          if (step != _Step.autostart || _hasAutostart) step,
      ];

  bool _isDone(_Step step) => step == _Step.autostart
      ? _autostartOpened
      : (_granted?[step] ?? false);

  bool get _allRequiredDone =>
      _steps.where((s) => s != _Step.autostart).every(_isDone);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Every grant happens in a system screen; re-read on return so the tick
    // moves without the rider having to do anything.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final hasAutostart = await DeviceReadinessService.hasAutoStartSettings();
    final granted = <_Step, bool>{};
    for (final step in _Step.values) {
      granted[step] = await _PermissionChecks.isGranted(step);
    }
    if (!mounted) return;
    setState(() {
      _hasAutostart = hasAutostart;
      _granted = granted;
    });
  }

  Future<void> _requestOne(_Step step) async {
    if (_working) return;
    setState(() => _working = true);
    try {
      await _PermissionChecks.request(step);
      if (step == _Step.autostart) _autostartOpened = true;
    } finally {
      await _refresh();
      if (mounted) setState(() => _working = false);
    }
  }

  /// One screen at a time: Android drops a Settings request made while another
  /// is still showing, so asking for everything at once loses all but one.
  Future<void> _allowAll() async {
    if (_working) return;
    setState(() => _working = true);
    try {
      for (final step in _steps) {
        if (step == _Step.autostart) {
          if (_autostartOpened) continue;
          await _PermissionChecks.request(step);
          _autostartOpened = true;
          continue;
        }
        if (await _PermissionChecks.isGranted(step)) continue;
        await _PermissionChecks.request(step);
        if (!mounted) return;
      }
    } finally {
      await _refresh();
      if (mounted) setState(() => _working = false);
    }
    if (mounted && _allRequiredDone) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = _granted;
    final steps = _steps;
    final doneCount = steps.where(_isDone).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up your phone'),
        automaticallyImplyLeading: false,
      ),
      body: granted == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 16.h),
                    children: [
                      Text(
                        'Allow these once so you never miss an order — even '
                        'when the app is closed or your screen is off.',
                        style: TextStyle(
                          fontSize: 13.sp,
                          height: 1.4,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      LinearProgressIndicator(
                        value: steps.isEmpty ? 1 : doneCount / steps.length,
                        minHeight: 6.h,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '$doneCount of ${steps.length} done',
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                      SizedBox(height: 12.h),
                      ...steps.map(_buildTile),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _working
                                ? null
                                : _allRequiredDone
                                    ? () => Navigator.of(context).pop()
                                    : _allowAll,
                            child: _working
                                ? SizedBox(
                                    width: 20.r,
                                    height: 20.r,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _allRequiredDone ? 'Continue' : 'Allow all',
                                  ),
                          ),
                        ),
                        if (!_allRequiredDone)
                          TextButton(
                            onPressed: _working
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Later'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTile(_Step step) {
    final done = _isDone(step);
    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: (done ? Colors.green : Colors.orange)
                    .withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.icon,
                size: 20.sp,
                color: done ? Colors.green : Colors.orange.shade800,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey[600],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            if (done)
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 24.sp)
            else
              TextButton(
                onPressed: _working ? null : () => _requestOne(step),
                child: Text(step == _Step.autostart ? 'Open' : 'Allow'),
              ),
          ],
        ),
      ),
    );
  }
}
