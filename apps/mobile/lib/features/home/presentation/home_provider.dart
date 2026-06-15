import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/device_role.dart';
import '../../settings/presentation/settings_provider.dart';

/// State for the home screen role selection.
@immutable
class HomeState {
  const HomeState({this.selectedRole});

  /// The role the user has chosen on this screen (before confirming).
  /// Null = nothing selected yet.
  final DeviceRole? selectedRole;

  HomeState copyWith({DeviceRole? selectedRole}) =>
      HomeState(selectedRole: selectedRole ?? this.selectedRole);
}

/// Notifier for the home screen.
///
/// Restores the last-used role from settings as the initial selection.
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier(this._ref)
      : super(HomeState(
          // Pre-select the last used role if available.
          selectedRole: _ref.read(settingsProvider).lastRole,
        ));

  final Ref _ref;

  void selectRole(DeviceRole role) {
    state = state.copyWith(selectedRole: role);
    // Persist immediately so next launch pre-selects the same role.
    _ref.read(settingsProvider.notifier).setLastRole(role);
  }
}

final homeProvider =
    StateNotifierProvider.autoDispose<HomeNotifier, HomeState>((ref) {
  return HomeNotifier(ref);
});
