# Ether Synapse — Project Roadmap

This document tracks the planned development milestones for Ether Synapse. It is a living document and will be updated as the project evolves. Community feedback is welcome via [GitHub Discussions](https://github.com/ether-synapse/ether-synapse/discussions).

---

## Milestone Overview

| Milestone | Status | Target |
|---|---|---|
| M0 — Foundation | ✅ Complete | Q2 2026 |
| M1 — Core Engine (Alpha) | 🟡 In Progress | Q3 2026 |
| M2 — Flutter Shell (Alpha) | 🔲 Planned | Q4 2026 |
| M3 — Alpha Release | 🔲 Planned | Q4 2026 |
| M4 — Beta Release | 🔲 Planned | Q1 2027 |
| M5 — Stable v1.0 | 🔲 Planned | Q2 2027 |

---

## M0 — Foundation

**Status:** ✅ Complete  
**Goal:** Establish the repository foundation, architecture decisions, and project governance.

### Deliverables

- [x] Repository structure and folder conventions
- [x] README, CONTRIBUTING, SECURITY, CODE_OF_CONDUCT
- [x] ARCHITECTURE.md with full system design
- [x] Architecture Decision Records (ADRs) for all key technology choices
- [x] GitHub issue templates and PR template
- [x] GitHub Actions CI pipeline scaffold
- [x] Protocol specification (v0 draft)
- [x] Security threat model (initial)
- [x] Branching strategy and release process defined
- [x] License (Apache 2.0)

---

## M1 — Core Engine (Alpha)

**Status:** 🟡 In Progress  
**Goal:** Implement the Rust core engine with working QUIC transport, cryptographic handshake, and BLE abstraction interfaces.

### Deliverables

#### Cryptography (`core/crypto`)
- [ ] X25519 ECDH key pair generation
- [ ] Session key derivation (HKDF-SHA256)
- [ ] ChaCha20-Poly1305 AEAD encryption/decryption
- [ ] SHA-256 fingerprint generation
- [ ] Constant-time comparison utilities
- [ ] Zeroize secret material on drop

#### Transport (`core/transport`)
- [ ] QUIC listener (Quinn + Tokio)
- [ ] QUIC connector
- [ ] Stream abstraction over QUIC connections
- [ ] Reliable multi-stream session management
- [ ] Graceful shutdown and timeout handling
- [ ] Backpressure and flow control

#### BLE Abstraction (`core/ble`)
- [ ] Platform-agnostic BLE trait definition
- [ ] BLE advertisement data encoding/decoding
- [ ] Pairing token generation and validation
- [ ] Session establishment protocol

#### Protocol (`core/proto`)
- [ ] Message framing format (length-prefixed binary)
- [ ] Handshake message types
- [ ] Transfer request and metadata messages
- [ ] Progress and acknowledgement messages
- [ ] Error and cancellation messages

#### Flutter Bridge (`core/engine`)
- [ ] flutter_rust_bridge bindings scaffolded
- [ ] Async event stream to Dart
- [ ] Transfer progress callback interface
- [ ] Error type mapping

#### Unit Tests
- [ ] Crypto round-trip tests
- [ ] Transport integration tests (loopback)
- [ ] Protocol message serialization tests

---

## M2 — Flutter Shell (Alpha)

**Status:** 🔲 Planned  
**Goal:** Implement the Flutter UI layer connected to the Rust engine via flutter_rust_bridge. Complete the full transfer flow end-to-end.

### Deliverables

#### Navigation & State
- [ ] GoRouter navigation setup
- [ ] Riverpod provider architecture
- [ ] App lifecycle management
- [ ] Permission handling (BLE, Wi-Fi, Storage)

#### Screens
- [ ] Home / Device Discovery screen
- [ ] Device selection sheet
- [ ] Verification screen (visual fingerprint display)
- [ ] File picker integration
- [ ] Transfer progress screen
- [ ] Transfer history screen
- [ ] Settings screen (theme, language)
- [ ] About / Open Source Licenses screen

#### Platform BLE Integration
- [ ] Android BLE implementation
- [ ] iOS BLE implementation (CoreBluetooth)
- [ ] macOS BLE implementation
- [ ] Windows BLE implementation (WinRT)
- [ ] Linux BLE implementation (BlueZ)

#### Transfer
- [ ] File selection (single and multi-file)
- [ ] Folder transfer support
- [ ] Receive-side file save location selection
- [ ] Transfer cancellation
- [ ] Retry on error

---

## M3 — Alpha Release

**Status:** 🔲 Planned  
**Goal:** Ship the first public alpha build. Focus on Android ↔ Android and macOS ↔ macOS transfers.

### Deliverables

- [ ] End-to-end file transfer working on Android and macOS
- [ ] Signed Android APK published to GitHub Releases
- [ ] macOS `.dmg` published to GitHub Releases
- [ ] Crash reporting integration (opt-in, privacy-respecting)
- [ ] Alpha tester community outreach
- [ ] Known issues documented

### Out of Scope for Alpha
- iOS transfers (CoreBluetooth multiplatform limitations)
- Windows transfers
- Linux transfers
- Folder transfers

---

## M4 — Beta Release

**Status:** 🔲 Planned  
**Goal:** Full cross-platform support. Production-quality UI. App store readiness.

### Deliverables

- [ ] iOS ↔ * transfers working
- [ ] Windows ↔ * transfers working
- [ ] Linux ↔ * transfers working
- [ ] Cross-platform interoperability test suite
- [ ] UI/UX polish pass
- [ ] Accessibility audit (WCAG 2.1 AA)
- [ ] Localization framework in place (English + 5 community languages)
- [ ] App Store and Google Play submission preparation
- [ ] Security audit (community-driven)
- [ ] Performance benchmarking report
- [ ] Beta tester feedback loop established

---

## M5 — Stable v1.0

**Status:** 🔲 Planned  
**Goal:** Production-ready 1.0 release across all supported platforms.

### Deliverables

- [ ] Stable public release on all 5 platforms
- [ ] Published to Google Play Store
- [ ] Published to Apple App Store
- [ ] Published via `winget` (Windows)
- [ ] Published via Homebrew (macOS/Linux)
- [ ] Published on Flathub (Linux)
- [ ] External security audit completed and report published
- [ ] Full protocol specification v1.0 finalized
- [ ] Public developer API documented
- [ ] Stable flutter_rust_bridge API surface locked
- [ ] Long-term support commitment documented

---

## Post-1.0 Ideas (Not Committed)

The following ideas are under consideration for future versions. They are not committed roadmap items.

- **Text snippet sharing** — Share clipboard content as well as files
- **Contact list** — Remember trusted devices by name
- **Batch send to multiple recipients** — Transfer to multiple devices simultaneously
- **Directory sync mode** — Synchronize a folder between two trusted devices
- **CLI interface** — Headless transfer tool for power users and server environments
- **Plugin API** — Allow third-party integrations for specialized transfer workflows
- **Partial transfer resume** — Resume interrupted transfers from last checkpoint
- **Web Companion** — Browser-based receiver (no app required on the receiving end for small files)

---

## Versioning Policy

Ether Synapse follows [Semantic Versioning](https://semver.org):

- `MAJOR.MINOR.PATCH` — e.g., `1.2.3`
- **MAJOR** — Breaking protocol changes
- **MINOR** — New features, backward-compatible
- **PATCH** — Bug fixes, security patches

Pre-release versions:
- `1.0.0-alpha.1` — Alpha builds (expect instability)
- `1.0.0-beta.1` — Beta builds (feature complete, stabilizing)
- `1.0.0-rc.1` — Release candidates (final testing)

---

## How to Influence the Roadmap

- **Request a feature** — Open a [Feature Request](https://github.com/ether-synapse/ether-synapse/issues/new?template=feature_request.yml) issue
- **Discuss direction** — Start a thread in [GitHub Discussions](https://github.com/ether-synapse/ether-synapse/discussions)
- **Vote on priorities** — React with 👍 on issues to signal importance
- **Contribute** — See [CONTRIBUTING.md](CONTRIBUTING.md)

---

*Last updated: June 2026*
