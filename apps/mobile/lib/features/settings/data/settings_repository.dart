/// Data layer for the settings feature.
///
/// Owns persistence of [AppSettings] to local device storage.
///
/// DO NOT call any external network here.
/// DO NOT transmit settings data anywhere.
abstract interface class SettingsRepository {
  /// Load persisted settings, or return defaults if none are saved.
  Future<AppSettings> loadSettings();

  /// Persist updated settings to local storage.
  Future<void> saveSettings(AppSettings settings);
}

// Import guard — AppSettings is defined in the domain layer.
// Re-export for convenience of the data layer.
export '../domain/app_settings.dart';
