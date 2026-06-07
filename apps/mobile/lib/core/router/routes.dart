/// Route path constants for the Ether Synapse application.
///
/// Centralised here so that path strings are never duplicated across the
/// codebase. Use [AppRouteNames] for named navigation with GoRouter.
abstract final class AppRoutes {
  AppRoutes._();

  // ── Absolute paths ──────────────────────────────────────────────
  static const String splash = '/';
  static const String discovery = '/discovery';
  static const String pairing = '/discovery/pair/:peerId';
  static const String transfer = '/transfer/:peerId';
  static const String settings = '/settings';

  // ── Relative sub-paths (used in nested GoRoute definitions) ─────
  static const String pairingRelative = 'pair/:peerId';
}

/// Named route identifiers — used with [GoRouter.goNamed] and [GoRouter.pushNamed].
///
/// Prefer named navigation over path strings wherever possible so that
/// route renames require a single change here, not a grep across the codebase.
abstract final class AppRouteNames {
  AppRouteNames._();

  static const String splash = 'splash';
  static const String discovery = 'discovery';
  static const String pairing = 'pairing';
  static const String transfer = 'transfer';
  static const String settings = 'settings';
}
