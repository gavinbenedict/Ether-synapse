import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/app_settings.dart';
import '../../../providers/app_providers.dart';

/// Riverpod [StateNotifier] for app settings.
///
/// Persists to local storage only — never to a remote service.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  // TODO(impl): Inject SettingsRepository and load on construction.

  /// Update the device display name.
  void setDeviceName(String name) {
    state = state.copyWith(deviceName: name.trim());
    // TODO(impl): await _repository.saveSettings(state);
  }

  /// Update the theme preference.
  void setTheme(ThemePreference pref, WidgetRef ref) {
    state = state.copyWith(themePreference: pref);
    ref.read(themeModeProvider.notifier).state = switch (pref) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.system => ThemeMode.system,
    };
    // TODO(impl): await _repository.saveSettings(state);
  }

  /// Toggle whether completed transfer history is shown.
  void setShowHistory(bool show) {
    state = state.copyWith(showTransferHistory: show);
    // TODO(impl): await _repository.saveSettings(state);
  }
}

/// Provider for [SettingsNotifier].
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});
