import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';
import '../../../shared/models/device_role.dart';

/// Data layer for the settings feature.
///
/// Owns persistence of [AppSettings] to local device storage via
/// [SharedPreferences]. All data stays on-device — never transmitted.
///
/// DO NOT call any external network here.
/// DO NOT transmit settings data anywhere.
abstract interface class SettingsRepository {
  /// Load persisted settings, or return defaults if none are saved.
  AppSettings loadSettings();

  /// Persist updated settings to local storage.
  Future<void> saveSettings(AppSettings settings);
}

/// Concrete implementation backed by [SharedPreferences].
class SharedPrefsSettingsRepository implements SettingsRepository {
  SharedPrefsSettingsRepository(this._prefs);
  final SharedPreferences _prefs;

  static const _keyDeviceName = 'settings.deviceName';
  static const _keyTheme = 'settings.themePreference';
  static const _keyShowHistory = 'settings.showTransferHistory';
  static const _keyLastRole = 'settings.lastRole';

  @override
  AppSettings loadSettings() {
    return AppSettings(
      deviceName: _prefs.getString(_keyDeviceName) ?? 'My Device',
      themePreference: _themeFromString(_prefs.getString(_keyTheme)),
      showTransferHistory: _prefs.getBool(_keyShowHistory) ?? true,
      lastRole: _roleFromString(_prefs.getString(_keyLastRole)),
    );
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setString(_keyDeviceName, settings.deviceName);
    await _prefs.setString(_keyTheme, settings.themePreference.name);
    await _prefs.setBool(_keyShowHistory, settings.showTransferHistory);
    if (settings.lastRole != null) {
      await _prefs.setString(_keyLastRole, settings.lastRole!.name);
    }
  }

  ThemePreference _themeFromString(String? value) {
    if (value == null) return ThemePreference.system;
    return ThemePreference.values.firstWhere(
      (p) => p.name == value,
      orElse: () => ThemePreference.system,
    );
  }

  DeviceRole? _roleFromString(String? value) {
    if (value == null) return null;
    return DeviceRole.values.firstWhere(
      (r) => r.name == value,
    );
  }
}
