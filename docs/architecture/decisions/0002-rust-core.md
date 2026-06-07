# ADR 0002 — Rust for the Core Engine

**Status**: Accepted

**Date**: June 2026

---

## Context

Ether Synapse requires a core engine that handles:

- Cryptographic key exchange and symmetric encryption.
- High-throughput file I/O and network I/O.
- Concurrent async operations (multiple streams, progress reporting).
- Cross-platform compilation to Android, iOS, Windows, macOS, and Linux.
- Predictable memory management without garbage collection pauses during file transfer.
- A security posture appropriate for a privacy-critical application.

The UI framework (Flutter/Dart) is well suited to cross-platform UX but provides no native async I/O primitives suitable for high-throughput network operations, and Dart's crypto ecosystem is substantially less mature than Rust's.

---

## Decision

All performance-critical, security-critical, and I/O-critical logic is implemented in **Rust** and exposed to the Flutter UI via `flutter_rust_bridge`.

Rust is chosen because:

- **Memory safety without GC.** Rust's ownership model eliminates use-after-free, buffer overflows, and data races at compile time — categories of bugs that are historically severe in security-sensitive network code.
- **`zeroize` crate.** Sensitive key material can be explicitly zeroed from memory when dropped, a property that is difficult to guarantee in GC-managed runtimes.
- **RustCrypto ecosystem.** Audited, constant-time implementations of X25519, ChaCha20-Poly1305, SHA-256, and HKDF are available as first-class crates with no C dependency.
- **Tokio async runtime.** Provides the concurrency model required for multiplexed QUIC streams, file I/O, and progress event emission without blocking the UI thread.
- **Cross-compilation.** Rust compiles to all five target platforms from a single codebase using standard toolchain targets and `flutter_rust_bridge` handles the FFI layer automatically.
- **Performance.** Rust achieves C-level throughput for file I/O operations with no runtime overhead.

---

## Consequences

**Positive:**
- Cryptographic operations are impossible to accidentally perform in Dart; the architecture enforces a hard boundary.
- Memory safety guarantees reduce the attack surface for the most sensitive code paths.
- A single Rust codebase serves all five target platforms.
- The RustCrypto crates receive independent security audits, benefiting the project without additional audit cost.

**Negative:**
- Rust has a steeper learning curve than Dart. Contributors must be proficient in both languages to work across the stack.
- `flutter_rust_bridge` adds a codegen step to the build pipeline. The generated files must be committed and kept in sync.
- Cross-compilation setup (especially for iOS and Android) requires careful toolchain configuration.

---

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Pure Dart core** | Dart's crypto libraries are not independently audited; Dart isolates provide concurrency but not the throughput of Rust async I/O; memory zeroing of key material is not guaranteed |
| **C/C++ core via FFI** | Manual memory management reintroduces the vulnerability classes Rust eliminates; C FFI from Flutter is lower-level and more error-prone than flutter_rust_bridge |
| **Go core** | Go has a GC that can cause pause spikes during large file I/O; cross-compilation to iOS is less mature than Rust; no equivalent of flutter_rust_bridge |
| **Kotlin Multiplatform (KMP)** | Limited to Android and iOS officially; no desktop parity without additional work; crypto ecosystem less mature than RustCrypto |
