# ADR 0005 — Single Bridge Boundary Between Flutter and Rust

**Status**: Accepted

**Date**: June 2026

---

## Context

Ether Synapse is a hybrid application: the UI is Flutter/Dart, and the core engine is Rust. The two runtimes must communicate. The design of this cross-language boundary is one of the most consequential architectural decisions in the project because:

- Every cross-boundary call is a potential source of bugs, memory unsafety, or data exposure.
- The boundary must be auditable: reviewers must be able to understand exactly what data crosses between layers.
- The boundary must be version-stable: changes to the Rust API should produce obvious, compiler-caught errors in Dart and vice versa.
- The boundary is the only place where cryptographic data (public keys, confirmation bytes, session state) could inadvertently leak to the Flutter layer.

---

## Decision

**There is exactly one permitted cross-layer boundary: `bridge/src/api.rs`.**

All functions callable from Flutter into Rust, and all event types streamable from Rust into Flutter, must be declared in this file and annotated with `#[flutter_rust_bridge]`. The `flutter_rust_bridge_codegen` tool generates type-safe Dart wrappers from this file.

Additionally, the following **information flow constraints** are enforced at the architectural level:

**Flutter MUST NOT receive:**
- Private key material (X25519 private keys).
- Session keys.
- Intermediate key derivation values.
- Raw shared secrets.

**Flutter MAY receive (as opaque status values only):**
- Connection state (`Idle`, `Pairing`, `Connecting`, `Established`, `Closed`).
- Transfer state (`Idle`, `Offering`, `Transferring`, `Complete`, `Error`).
- Verification PIN (a 6-digit string computed by Rust, for display only).
- Device metadata received from a peer (name, capability flags).
- Transfer progress (bytes sent, bytes total, file name).
- Error descriptions (human-readable strings, never containing key material).

**Flutter MAY send to Rust (as opaque command values only):**
- File path strings (for the Rust sender to open).
- Peer endpoint address strings (IP + port received via GATT).
- Remote public key bytes (32 bytes, opaque to Flutter — received from BLE GATT and forwarded to Rust).
- User confirmations (boolean: PIN accepted / rejected).
- Cancel commands (stream close requests).

This boundary is enforced by code review policy and documented here as a hard architectural rule. Any PR that adds a new bridge API function must justify it against these constraints.

---

## Consequences

**Positive:**
- A single file is the authoritative source of truth for the entire cross-language API surface. Auditors, contributors, and security reviewers have one place to look.
- The codegen tool produces compile-time errors if the Dart usage diverges from the Rust API definition, catching integration bugs early.
- The constraint that Flutter never receives key material is architecturally enforced: there is no API to retrieve a session key, so it is physically impossible for Flutter to accidentally log or display one.
- The bridge file is small and reviewable. A security audit of the cross-language boundary takes minutes, not hours.

**Negative:**
- All cross-layer changes require running the codegen script and committing the generated files.
- Contributors new to the project must understand the bridge constraint before adding new features.
- The single-file constraint may become unwieldy if the API surface grows significantly in a multi-crate future. (See the note on single vs. multi-crate Rust architecture in ARCHITECTURE.md §12.)

---

## Enforcement

The following checks enforce the boundary in practice:

1. **Code review.** Every PR touching `bridge/src/api.rs` requires explicit review of the new API against the information flow constraints above.
2. **Commit policy.** Generated files in `apps/mobile/lib/bridge/generated/` must be regenerated and committed as part of any PR that changes `bridge/src/api.rs`. Reviewers verify by diffing the generated output.
3. **Naming convention.** Bridge functions that receive sensitive bytes from Flutter (e.g., remote public keys) must include `opaque` in their name or doc comment to signal that Flutter does not interpret the value.

---

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Multiple bridge files** | Distributes the API surface across files, making audits harder and increasing the risk of inconsistent constraints |
| **Direct FFI (no flutter_rust_bridge)** | Requires manual `unsafe` Dart FFI code and Rust `extern "C"` declarations; no type safety; high maintenance burden |
| **Platform channels for all Rust calls** | Platform channels serialise to JSON/byte maps; no type safety; significant performance overhead for high-frequency events like transfer progress |
| **Dart-side crypto (remove the boundary constraint)** | Violates the security ownership model; Dart crypto libraries are less mature and not audited to the same standard as RustCrypto |
