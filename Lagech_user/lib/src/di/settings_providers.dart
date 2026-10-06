import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/datasources/settings_remote_datasource.dart';
import '../data/models/business_settings_model.dart';
import 'network_providers.dart';

final settingsRemoteDataSourceProvider = Provider<SettingsRemoteDataSource>((ref) {
  return SettingsRemoteDataSource(ref.watch(apiClientProvider));
});

final businessSettingsProvider =
    NotifierProvider<BusinessSettingsNotifier, BusinessSettings>(
  BusinessSettingsNotifier.new,
);

/// The admin's Business Settings, loaded at start-up.
///
/// Starts from [BusinessSettings.fallback] (today's behaviour), paints the
/// cached copy as soon as there is one, then the live copy. A failed call keeps
/// whatever is already shown: a settings outage must never block ordering —
/// the server still enforces every switch and explains a refusal itself.
class BusinessSettingsNotifier extends Notifier<BusinessSettings> {
  @override
  BusinessSettings build() {
    Future.microtask(refresh);
    return BusinessSettings.fallback;
  }

  bool _loading = false;

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    try {
      state = await ref.read(settingsRemoteDataSourceProvider).getBusinessSettings(
            onCache: (cached) => state = cached,
          );
    } catch (_) {
      // Keep the current (cached or fallback) settings.
    } finally {
      _loading = false;
    }
  }
}

/// Offline payment methods to offer at checkout. Empty when the feature is
/// off or the call fails — the option is then simply not shown.
final offlinePaymentMethodsProvider =
    FutureProvider.autoDispose<List<OfflinePaymentMethod>>((ref) async {
  final enabled = ref.watch(
    businessSettingsProvider.select((s) => s.offlineEnabled),
  );
  if (!enabled) return const [];
  try {
    return await ref
        .read(settingsRemoteDataSourceProvider)
        .getOfflinePaymentMethods();
  } catch (_) {
    return const [];
  }
});
