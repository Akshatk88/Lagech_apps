import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/settings_providers.dart';

/// Shared veg-only filter, toggled from both the Home search bar pill and
/// the Profile "Veg Mode" switch so they always reflect the same state.
final vegFilterProvider = NotifierProvider<VegFilterNotifier, bool>(() {
  return VegFilterNotifier();
});

class VegFilterNotifier extends Notifier<bool> {
  @override
  bool build() {
    // The admin can switch the Veg Mode toggle off; a filter the customer can
    // no longer see or undo must not keep hiding non-veg restaurants.
    ref.listen(
      businessSettingsProvider.select((s) => s.vegNonVegToggle),
      (_, enabled) {
        if (!enabled) state = false;
      },
    );
    return false;
  }

  void set(bool value) => state = value;

  void toggle() => state = !state;
}
