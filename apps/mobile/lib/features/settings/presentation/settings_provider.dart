import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import '../../../shared/models/device_role.dart';
import '../../../providers/app_providers.dart';

/// Riverpod [StateNotifier] for app settings.
///
/// Persists to local storage only — never to a remote service.
/// On construction, loads the previously saved settings from
/// [SharedPrefsSettingsRepository] so that values (e.g. device name) survive
/// app restarts.
class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier(this._repository) : super(_repository.loadSettings());

  final SettingsRepository _repository;

  /// Update the device display name and persist.
  void setDeviceName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(deviceName: trimmed);
    _repository.saveSettings(state);
  }

  /// Update the theme preference and persist.
  void setTheme(ThemePreference pref, WidgetRef ref) {
    state = state.copyWith(themePreference: pref);
    ref.read(themeModeProvider.notifier).state = switch (pref) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.system => ThemeMode.system,
    };
    _repository.saveSettings(state);
  }

  /// Toggle whether completed transfer history is shown and persist.
  void setShowHistory(bool show) {
    state = state.copyWith(showTransferHistory: show);
    _repository.saveSettings(state);
  }

  /// Persist the last-used [DeviceRole] so the home screen can pre-select it.
  void setLastRole(DeviceRole role) {
    state = state.copyWith(lastRole: role);
    _repository.saveSettings(state);
  }
}

/// Provider for the settings repository (singleton).
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SharedPrefsSettingsRepository(prefs);
});

/// Provider for [SettingsNotifier].
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref.watch(settingsRepositoryProvider));
});
