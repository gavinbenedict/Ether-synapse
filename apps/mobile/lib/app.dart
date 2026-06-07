import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/app_providers.dart';

/// Root widget for Ether Synapse.
///
/// Wires together:
///   - Material 3 theming (light + dark, system-adaptive)
///   - GoRouter navigation
///   - Riverpod state
class EtherSynapseApp extends ConsumerWidget {
  const EtherSynapseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Ether Synapse',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,

      // Navigation
      routerConfig: router,
    );
  }
}
