/// Ether Synapse bridge placeholder.
///
/// This file is the Dart-side entry point for the flutter_rust_bridge
/// generated bindings. It re-exports the auto-generated API surface so that
/// the rest of the app can import a single stable path.
///
/// IMPORTANT: Do NOT import the generated files directly from feature code.
/// Always import through this file so that the bridge location can change
/// without touching every call site.
///
/// Usage:
///   import 'package:ether_synapse/bridge/ether_bridge.dart';
///
/// The generated bindings live at:
///   lib/bridge/generated/   (do not edit by hand)
///
/// To regenerate after modifying bridge/src/api.rs, run:
///   scripts/gen_bridge.sh
///
/// See ARCHITECTURE.md §6 for the full bridge contract.

// TODO(codegen): Uncomment after running gen_bridge.sh
// export 'generated/bridge_generated.dart';

// ── Stub types ───────────────────────────────────────────────────────────────
// These stubs allow the rest of the Flutter codebase to compile before the
// Rust bridge is generated. Remove once gen_bridge.sh has been run.

/// Placeholder for the generated Rust API class.
abstract final class RustBridge {
  RustBridge._();
  // ignore: unused_element
  static Never _notYetGenerated() =>
      throw UnimplementedError(
        'The Rust bridge has not been generated yet.\n'
        'Run scripts/gen_bridge.sh to generate bridge bindings.',
      );
}
