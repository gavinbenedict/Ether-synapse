import '../../../shared/models/device_role.dart';
///
/// Persisted to local device storage only — never transmitted.
/// No account IDs, no cloud sync, no telemetry.
final class AppSettings {
  const AppSettings({
    this.deviceName = 'My Device',
    this.themePreference = ThemePreference.system,
    this.defaultSaveDirectory,
    this.showTransferHistory = true,
    this.lastRole,
  });

  /// The display name broadcast during discovery.
  ///
  /// Max 24 characters (see AppConstants.maxDeviceNameLength).
  final String deviceName;

  /// User's preferred theme mode.
  final ThemePreference themePreference;

  /// Directory to save received files, or `null` to use platform default.
  final String? defaultSaveDirectory;

  /// Whether to show a history of completed transfers on the transfer screen.
  final bool showTransferHistory;

  /// Last role the user selected (Send or Receive).
  ///
  /// Restored on next launch as the pre-selected role on the home screen.
  final DeviceRole? lastRole;

  AppSettings copyWith({
    String? deviceName,
    ThemePreference? themePreference,
    String? defaultSaveDirectory,
    bool? showTransferHistory,
    bool clearSaveDirectory = false,
    DeviceRole? lastRole,
  }) {
    return AppSettings(
      deviceName: deviceName ?? this.deviceName,
      themePreference: themePreference ?? this.themePreference,
      defaultSaveDirectory: clearSaveDirectory
          ? null
          : (defaultSaveDirectory ?? this.defaultSaveDirectory),
      showTransferHistory: showTransferHistory ?? this.showTransferHistory,
      lastRole: lastRole ?? this.lastRole,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppSettings &&
          other.deviceName == deviceName &&
          other.themePreference == themePreference &&
          other.defaultSaveDirectory == defaultSaveDirectory &&
          other.showTransferHistory == showTransferHistory &&
          other.lastRole == lastRole;

  @override
  int get hashCode => Object.hash(
        deviceName,
        themePreference,
        defaultSaveDirectory,
        showTransferHistory,
        lastRole,
      );
}

/// User's theme preference stored in settings.
enum ThemePreference {
  system,
  light,
  dark;

  String get label => switch (this) {
        ThemePreference.system => 'Follow system',
        ThemePreference.light => 'Light',
        ThemePreference.dark => 'Dark',
      };
}
