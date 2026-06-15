import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'routes.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/receive/presentation/receive_screen.dart';
import '../../features/send/presentation/send_screen.dart';
import '../../features/negotiation/presentation/negotiation_screen.dart';
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
      // ── Splash ────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        name: AppRouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // ── Home (role selection) ────────────────────────────────
      // Receive and Send are nested so that pushNamed from Home
      // builds a proper back-stack: Home → Send/Receive → Back → Home.
      GoRoute(
        path: AppRoutes.home,
        name: AppRouteNames.home,
        builder: (context, state) => const HomeScreen(),
        routes: [
          // ── Receive (advertise-only mode) ──────────────────
          GoRoute(
            path: AppRoutes.receiveRelative,
            name: AppRouteNames.receive,
            builder: (context, state) => const ReceiveScreen(),
          ),

          // ── Send (scan-only mode) ──────────────────────────
          GoRoute(
            path: AppRoutes.sendRelative,
            name: AppRouteNames.send,
            builder: (context, state) => const SendScreen(),
            routes: [
              // ── Negotiate (capability exchange) ─────────────
              GoRoute(
                path: AppRoutes.negotiateRelative,
                name: AppRouteNames.negotiate,
                builder: (context, state) {
                  final peerId = state.pathParameters['peerId'] ?? '';
                  return NegotiationScreen(peerId: peerId);
                },
              ),
            ],
          ),
        ],
      ),

      // ── Legacy Discovery (kept for internal use) ─────────────
      GoRoute(
        path: AppRoutes.discovery,
        name: AppRouteNames.discovery,
        builder: (context, state) => const DiscoveryScreen(),
        routes: [
          GoRoute(
            path: AppRoutes.pairingRelative,
            name: AppRouteNames.pairing,
            builder: (context, state) {
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
          final hostIp = state.uri.queryParameters['hostIp'] ?? '';
          final isHost = state.uri.queryParameters['isHost'] == 'true';
          return TransferScreen(peerId: peerId, hostIp: hostIp, isHost: isHost);
        },
      ),

      // ── Settings (pushed as overlay) ─────────────────────────
      GoRoute(
        path: AppRoutes.settings,
        name: AppRouteNames.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],

    // ── Error page ─────────────────────────────────────────────
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
