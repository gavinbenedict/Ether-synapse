import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';
import '../../features/discovery/presentation/discovery_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../features/transfer/presentation/transfer_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../shared/widgets/splash_screen.dart';

/// Riverpod provider for the application [GoRouter] instance.
///
/// The router is a singleton per ProviderScope lifetime.
/// Re-reading the provider returns the same instance.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      // ── Splash ──────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Discovery ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.discovery,
        name: AppRouteNames.discovery,
        builder: (context, state) => const DiscoveryScreen(),

        routes: [
          // ── Pairing (sub-route of discovery) ─────────────────
          GoRoute(
            path: AppRoutes.pairingRelative,
            name: AppRouteNames.pairing,
            builder: (context, state) {
              // peerId is passed as a path parameter.
              final peerId = state.pathParameters['peerId'] ?? '';
              return PairingScreen(peerId: peerId);
            },
          ),
        ],
      ),

      // ── Transfer ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.transfer,
        name: AppRouteNames.transfer,
        builder: (context, state) {
          final peerId = state.pathParameters['peerId'] ?? '';
          return TransferScreen(peerId: peerId);
        },
      ),

      // ── Settings ─────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        name: AppRouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // ── Error page ───────────────────────────────────────────────
    errorBuilder: (context, state) => _RouterErrorScreen(state.error),
  );
});

/// Minimal error screen rendered when GoRouter encounters an unknown route.
class _RouterErrorScreen extends StatelessWidget {
  const _RouterErrorScreen(this.error);

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          'Page not found.\n${error?.toString() ?? ''}',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
