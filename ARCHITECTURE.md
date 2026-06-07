# Ether Synapse — Architecture

> Revision 1.1 · June 2026
>
> Changes from Revision 1.0: discovery module added to Rust core; security
> ownership model formalised; ADR coverage expanded to five records; protocol
> documentation directory added; single-vs-multi-crate scalability note added;
> open-source readiness folder structure updated.

---

## Table of Contents

1. [Repository Layout](#1-repository-layout)
2. [Documentation Structure](#2-documentation-structure)
3. [Architectural Overview](#3-architectural-overview)
4. [Module Boundaries](#4-module-boundaries)
5. [Security Ownership Model](#5-security-ownership-model)
6. [Flutter ↔ Rust Interaction Model](#6-flutter--rust-interaction-model)
7. [BLE Layer Design](#7-ble-layer-design)
8. [Discovery Module Design](#8-discovery-module-design)
9. [Transport Layer Design](#9-transport-layer-design)
10. [Security Model](#10-security-model)
11. [Development Workflow](#11-development-workflow)
12. [Branching Strategy](#12-branching-strategy)
13. [Dependency Policy](#13-dependency-policy)
14. [Rust Crate Scalability Note](#14-rust-crate-scalability-note)

---

## 1. Repository Layout

```
ether_synapse/                              ← repository root
│
├── apps/
│   └── mobile/                             ← Flutter app (single target for all 5 platforms)
│       ├── android/                        ← Android runner + BLE platform channel impl
│       ├── ios/                            ← iOS runner + BLE platform channel impl
│       ├── macos/                          ← macOS runner + BLE platform channel impl
│       ├── windows/                        ← Windows runner + BLE platform channel impl
│       ├── linux/                          ← Linux runner (mDNS discovery only; BLE optional)
│       ├── lib/
│       │   ├── main.dart
│       │   ├── app.dart                    ← MaterialApp / GoRouter root
│       │   ├── core/                       ← App-wide utilities, theme, constants
│       │   │   ├── theme/
│       │   │   ├── router/
│       │   │   └── constants/
│       │   ├── features/
│       │   │   ├── discovery/              ← Peer list UI; BLE/mDNS status display
│       │   │   │   ├── data/               ← BLE platform channel calls; bridge calls
│       │   │   │   ├── domain/             ← PeerDevice entity, DiscoveryState
│       │   │   │   └── presentation/       ← Riverpod providers + screens
│       │   │   ├── pairing/                ← PIN display, pairing progress UI
│       │   │   │   ├── data/
│       │   │   │   ├── domain/
│       │   │   │   └── presentation/
│       │   │   ├── transfer/               ← File picker, progress bars, history
│       │   │   │   ├── data/               ← Bridge calls into Rust transfer engine
│       │   │   │   ├── domain/
│       │   │   │   └── presentation/
│       │   │   └── settings/               ← Device name, theme, permissions
│       │   │       ├── data/
│       │   │       ├── domain/
│       │   │       └── presentation/
│       │   └── bridge/                     ← Generated bindings — do not edit by hand
│       │       └── generated/
│       ├── pubspec.yaml
│       └── pubspec.lock
│
├── core/                                   ← Rust crate (core engine)
│   ├── Cargo.toml
│   ├── Cargo.lock
│   ├── build.rs                            ← flutter_rust_bridge codegen trigger
│   └── src/
│       ├── lib.rs                          ← Public API surface exposed via the bridge
│       ├── crypto/                         ← All cryptographic operations (see §5)
│       │   ├── mod.rs
│       │   ├── handshake.rs                ← X25519 ephemeral key pair generation + DH
│       │   ├── aead.rs                     ← ChaCha20-Poly1305 encrypt/decrypt
│       │   └── hash.rs                     ← SHA-256 file integrity
│       ├── discovery/                      ← mDNS advertisement and peer resolution
│       │   ├── mod.rs
│       │   ├── mdns.rs                     ← mDNS advertiser and resolver (Tokio async)
│       │   ├── peer.rs                     ← Peer identity model and metadata types
│       │   ├── protocol.rs                 ← Discovery protocol constants and frame types
│       │   └── service.rs                  ← Service abstraction trait (discovery backend)
│       ├── transport/                      ← QUIC session management
│       │   ├── mod.rs
│       │   ├── endpoint.rs                 ← Quinn QUIC endpoint (client + server modes)
│       │   ├── session.rs                  ← Authenticated, encrypted QUIC session wrapper
│       │   └── stream.rs                   ← Bidirectional stream multiplexing
│       ├── transfer/                       ← File transfer protocol
│       │   ├── mod.rs
│       │   ├── sender.rs                   ← Chunked file reading, send loop, progress
│       │   ├── receiver.rs                 ← Chunk reassembly, write, integrity check
│       │   └── manifest.rs                 ← Transfer manifest (name, size, checksum)
│       └── session/                        ← Peer session lifecycle
│           ├── mod.rs
│           ├── state.rs                    ← Session state machine
│           └── manager.rs                  ← Active session registry
│
├── bridge/                                 ← flutter_rust_bridge configuration
│   ├── flutter_rust_bridge.yaml            ← Codegen configuration
│   └── src/
│       └── api.rs                          ← ONLY permitted cross-layer boundary (see §4)
│
├── docs/                                   ← Project documentation
│   ├── assets/
│   │   └── logo.png
│   ├── architecture/
│   │   ├── decisions/                      ← Architecture Decision Records (ADRs)
│   │   │   ├── 0001-quic-transport.md
│   │   │   ├── 0002-rust-core.md
│   │   │   ├── 0003-ble-for-discovery-only.md
│   │   │   ├── 0004-no-cloud-architecture.md
│   │   │   └── 0005-flutter-rust-boundary.md
│   │   ├── diagrams/                       ← Mermaid / Draw.io source files
│   │   └── SEQUENCE_DIAGRAMS.md
│   └── protocol/                           ← Protocol specifications
│       ├── ble-discovery.md
│       ├── pairing.md
│       ├── session-establishment.md
│       └── transfer-protocol.md
│
├── scripts/                                ← Developer utility scripts
│   ├── gen_bridge.sh                       ← Regenerate flutter_rust_bridge bindings
│   ├── build_all.sh                        ← Build Rust for all targets
│   └── lint.sh                             ← Run Clippy + flutter analyze
│
├── .editorconfig
├── .gitattributes
├── .gitignore
├── ARCHITECTURE.md                         ← This file
├── CHANGELOG.md                            ← Keep-a-Changelog format
├── CODE_OF_CONDUCT.md                      ← Contributor Covenant
├── CONTRIBUTING.md                         ← Contributor guide
├── LICENSE                                 ← Apache 2.0
├── README.md
├── ROADMAP.md                              ← Public feature roadmap
└── SECURITY.md                             ← Vulnerability disclosure policy
```

---

## 2. Documentation Structure

```
docs/
├── assets/                    Static assets (logo, screenshots)
│
├── architecture/
│   ├── decisions/             Architecture Decision Records (ADRs)
│   │                          Filename: NNNN-short-title.md
│   │                          One decision per file.
│   │                          Sections: Status · Context · Decision · Consequences · Alternatives
│   │
│   ├── diagrams/              Source files for architecture diagrams (Mermaid preferred)
│   │
│   └── SEQUENCE_DIAGRAMS.md  Consolidated sequence diagrams for cross-cutting flows
│
└── protocol/                  Protocol specifications
                               One file per protocol layer.
                               Sections: Purpose · Responsibilities · Wire Format ·
                                         Sequence · Security Considerations · Future Extensions
```

### Architecture Decision Record Template

```markdown
# NNNN — Title

**Status**: Proposed | Accepted | Deprecated | Superseded by NNNN
**Date**: YYYY-MM

## Context
What situation, constraint, or requirement prompted this decision.

## Decision
What was decided and why.

## Consequences
Trade-offs accepted as a result of this decision.
Separate positive and negative consequences clearly.

## Alternatives Considered
| Alternative | Reason Rejected |
|-------------|----------------|
| ...         | ...             |
```

### Protocol Specification Template

```markdown
# Protocol Name

> Protocol Version: N · Status: Draft | Stable

## Purpose
## Responsibilities (table: Responsibility | Owner)
## Wire Format (if applicable)
## Sequence (ASCII diagram)
## Security Considerations
## Future Extensions
```

### Current ADR Index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](docs/architecture/decisions/0001-quic-transport.md) | QUIC as the File Transfer Transport | Accepted |
| [0002](docs/architecture/decisions/0002-rust-core.md) | Rust for the Core Engine | Accepted |
| [0003](docs/architecture/decisions/0003-ble-for-discovery-only.md) | BLE Used Exclusively for Discovery and Pairing | Accepted |
| [0004](docs/architecture/decisions/0004-no-cloud-architecture.md) | Strictly Local Architecture (No Cloud Dependency) | Accepted |
| [0005](docs/architecture/decisions/0005-flutter-rust-boundary.md) | Single Bridge Boundary Between Flutter and Rust | Accepted |

---

## 3. Architectural Overview

Ether Synapse is partitioned into three horizontal layers and four vertical domains.

### Horizontal Layers

```
┌───────────────────────────────────────────────────────────────────┐
│  Presentation Layer                                               │
│  Flutter / Dart                                                   │
│  Riverpod state · GoRouter navigation · Platform-native UI        │
│  Observes status events only — performs no crypto operations      │
├───────────────────────────────────────────────────────────────────┤
│  Bridge Layer                                                     │
│  flutter_rust_bridge                                              │
│  Type-safe Dart ↔ Rust FFI · async call dispatch                 │
│  Single seam: bridge/src/api.rs                                   │
├───────────────────────────────────────────────────────────────────┤
│  Core Layer                                                       │
│  Rust                                                             │
│  Discovery · Crypto · QUIC transport · File transfer protocol     │
│  Owns all key material · Performs all crypto operations           │
└───────────────────────────────────────────────────────────────────┘
```

### Vertical Domains

```
┌──────────────┬──────────────┬──────────────┬──────────────────────┐
│  Discovery   │  Pairing     │  Session     │  Transfer            │
│  Domain      │  Domain      │  Domain      │  Domain              │
│              │              │              │                      │
│  BLE Scan*   │  X25519 DH   │  QUIC Conn   │  Chunk Send/Recv     │
│  mDNS Adv†  │  PIN Derive  │  Hello Exch  │  Progress Events     │
│  Peer List   │  Key Derive  │  State Mach  │  SHA-256 Verify      │
│              │              │              │                      │
│ *Flutter     │  †Rust core  │  Rust core   │  Rust core           │
│  platform    │   discovery  │   session/   │   transfer/          │
│  channel     │   module     │   transport  │                      │
└──────────────┴──────────────┴──────────────┴──────────────────────┘
```

BLE advertisement and scanning live in the Flutter platform channel layer (platform-native code per runner). mDNS advertisement and resolution live in the Rust `discovery` module. All cryptographic and transport operations live exclusively in the Rust core.

---

## 4. Module Boundaries

### Hard Rules

| Rule | Rationale |
|------|-----------|
| The Rust core **must not** import any Flutter or Dart code. | Rust is a standalone, independently testable engine. |
| The Flutter app **must not** perform any cryptographic operation. | All crypto is centralised in Rust. See §5. |
| The Flutter app **must not** open, manage, or directly address QUIC sockets. | Transport lifecycle is owned by the Rust session manager. |
| BLE advertisement and scanning **must not** be implemented in Rust. | BLE APIs are platform-native; platform channels provide the correct abstraction. |
| mDNS advertisement and resolution **must** be implemented in Rust (`core/src/discovery/`). | mDNS is network I/O; Rust owns all network operations below the bridge. |
| `bridge/src/api.rs` is the **only** permitted cross-layer boundary. | One seam = one place to audit, one place to update. See ADR 0005. |
| Generated files under `apps/mobile/lib/bridge/generated/` **must not** be edited by hand. | They are regenerated on every `gen_bridge.sh` run. |

### Module Dependency Graph

```
apps/mobile (Flutter)
    │
    │  imports generated Dart bindings
    ▼
apps/mobile/lib/bridge/generated/     ◄── codegen output (do not edit)
    ▲
    │  generated from
bridge/src/api.rs                     ← single permitted cross-layer seam
    │
    │  calls into
    ▼
core/src/lib.rs
    ├── core/src/crypto/              ← key gen, AEAD, hashing
    ├── core/src/discovery/           ← mDNS advertisement and peer model  [NEW]
    ├── core/src/transport/           ← QUIC endpoint, session, streams
    ├── core/src/transfer/            ← chunked send/receive, manifest
    └── core/src/session/             ← state machine, active session registry
```

### Feature Layer Rules (Flutter)

Each feature under `lib/features/<name>/` follows a strict three-layer internal structure:

```
data/         ← External calls only: bridge invocations, platform channels.
              ← Must not contain business logic.
              ← May contain repository implementations.

domain/       ← Pure Dart business entities and state definitions.
              ← Must not import Flutter widgets.
              ← Must not call bridge or platform channels directly.

presentation/ ← Riverpod providers, screens, and widgets.
              ← Reads domain state; calls data layer via provider interfaces.
              ← Must not call bridge directly.
              ← Must not perform or interpret cryptographic values.
```

---

## 5. Security Ownership Model

This section is the authoritative statement of which layer owns which security responsibility. It supersedes any language in earlier drafts that implied Flutter might hold or process key material.

### Ownership Table

| Responsibility | Owner | Notes |
|----------------|-------|-------|
| Ephemeral X25519 key pair generation | **Rust** `crypto::handshake` | Keys are generated fresh per session; never stored |
| X25519 Diffie-Hellman computation | **Rust** `crypto::handshake` | Raw shared secret never leaves Rust |
| Session key derivation (HKDF-SHA256) | **Rust** `crypto::handshake` | Derived key never leaves Rust memory |
| PIN derivation for out-of-band verification | **Rust** `crypto::handshake` | Pin value (6-digit string) surfaced to Flutter for display only |
| ChaCha20-Poly1305 encryption | **Rust** `crypto::aead` | All frames encrypted before QUIC |
| ChaCha20-Poly1305 decryption | **Rust** `crypto::aead` | Decryption occurs before data is passed to Flutter |
| SHA-256 file integrity verification | **Rust** `crypto::hash` + `transfer::receiver` | Flutter receives pass/fail status only |
| Session key memory zeroing on drop | **Rust** (`zeroize` crate) | Enforced by Rust ownership; GC cannot interfere |
| BLE public key byte transport | Flutter platform channel | Flutter carries opaque bytes it does not interpret |
| QUIC endpoint address delivery | Flutter platform channel | IP:port string; not sensitive |

### What Flutter Receives Through the Bridge

Flutter is permitted to receive only the following categories of data through `bridge/src/api.rs`:

| Category | Examples |
|----------|---------|
| Connection status events | `Idle`, `Pairing`, `Connecting`, `Established`, `Closed` |
| Transfer status events | `Offering`, `Transferring`, `Complete`, `Error` |
| Verification display values | 6-digit PIN string (computed by Rust, displayed by Flutter) |
| Peer device metadata | Device name (string), capability flags (bitmask) |
| Transfer progress | Bytes sent (u64), total bytes (u64), file name (string) |
| Error descriptions | Human-readable strings — must never contain key material |

### What Flutter Sends Through the Bridge

Flutter is permitted to send only the following categories of data into Rust:

| Category | Examples |
|----------|---------|
| File paths | String path to file selected by user via file_picker |
| Remote public key bytes | 32-byte opaque blob received from BLE GATT; not interpreted by Flutter |
| Peer endpoint address | "192.168.1.x:port" string received from BLE GATT |
| User confirmations | Boolean: PIN accepted (`true`) / PIN rejected (`false`) |
| Cancel commands | Transfer abort request (no payload) |

### Enforcement

1. **Code review gate.** Every PR touching `bridge/src/api.rs` requires explicit review against the ownership table above.
2. **Naming convention.** Bridge functions that receive opaque bytes from Flutter must be documented with `# Safety: Flutter does not interpret this value`.
3. **No Dart crypto packages.** The project's `pubspec.yaml` must not import any Dart package whose primary purpose is cryptography. This is enforced by code review.

---

## 6. Flutter ↔ Rust Interaction Model

### Bridge API Contract

All calls from Flutter into Rust, and all events from Rust to Flutter, pass through `bridge/src/api.rs`. The `flutter_rust_bridge_codegen` tool produces:

- A Dart class with async methods mirroring each Rust function.
- C FFI bindings compiled into the native library.

```bash
flutter_rust_bridge_codegen generate \
  --rust-input bridge/src/api.rs \
  --dart-output apps/mobile/lib/bridge/generated/
```

### Call Patterns

#### 1. One-shot async call (command → result)

Used for: starting a BLE pairing handshake (Flutter passes opaque remote public key bytes; Rust returns a PIN string).

```
Flutter (async Dart)           Bridge              Rust (async Tokio)
      │                           │                       │
      │── beginPairing(pubBytes) ─►│── FFI dispatch ──────►│
      │                           │                       │── X25519 DH
      │                           │                       │── HKDF derive
      │                           │                       │── PIN derive
      │◄── PairingResult(pin) ────│◄── return value ──────│
      │
      │  [Flutter displays PIN — does not store or process it further]
```

Note: `pubBytes` is opaque to Flutter. Flutter does not know it is a public key. It received this blob from the BLE GATT characteristic and forwards it unchanged.

#### 2. Event stream (Rust → Flutter)

Used for: session status updates, transfer progress, discovery events.

```
Rust (Tokio broadcast channel)   Bridge            Flutter (Dart Stream)
      │                              │                      │
      │── emit(SessionEvent) ───────►│── FFI callback ─────►│
      │── emit(TransferProgress) ───►│                      │── Riverpod provider
      │── emit(TransferComplete) ───►│                      │── notifies listeners
      │                              │                      │── UI reacts
```

Streams are backed by `StreamSink<T>` in the bridge API and exposed as `Stream<T>` in Dart. A Riverpod `StreamProvider` subscribes and propagates state to the widget tree.

#### 3. Platform channel (Flutter → native BLE)

BLE operations are not routed through Rust. Flutter invokes platform channels on each host platform. Once the BLE exchange is complete, the 32-byte remote public key blob is forwarded to Rust via the bridge.

```
Flutter                  Platform Channel             Native (Swift/Kotlin/WinRT)
      │                         │                              │
      │── startScan() ─────────►│─────────────────────────────►│
      │◄── Stream<PeerInfo> ────│◄────────────────────────────│
      │── connectPeer(id) ──────►│─────────────────────────────►│
      │── writePubKey(bytes) ───►│─────────────────────────────►│── GATT write
      │◄── remotePubKey(bytes) ─│◄────────────────────────────│── GATT notify
      │
      │  [Flutter forwards remotePubKey bytes to Rust via bridge]
      │── beginPairing(remotePubKey) ──► [bridge] ──► Rust
```

### Data Type Mapping

| Rust type | Dart type |
|-----------|-----------|
| `String` | `String` |
| `Vec<u8>` | `Uint8List` |
| `u64` | `int` |
| `u32` | `int` |
| `f32` | `double` |
| `bool` | `bool` |
| `Option<T>` | `T?` |
| `Result<T, E>` | throws `FfiException` |
| Custom struct | Generated Dart class (immutable) |
| Custom enum | Generated Dart sealed class |
| `StreamSink<T>` | `Stream<T>` |

---

## 7. BLE Layer Design

BLE is used exclusively for out-of-band discovery, pairing, and session bootstrap. It never carries file data.

### GATT Profile

```
Service UUID: Reserved. Assigned during implementation.

├── Characteristic: PUBLIC_KEY   UUID: ...01
│     Properties:  Write Without Response, Notify
│     Payload:     32-byte ephemeral X25519 public key (opaque blob)
│
├── Characteristic: PIN_DISPLAY  UUID: ...02
│     Properties:  Notify
│     Payload:     4 bytes; PIN = big-endian u32 mod 1,000,000
│
├── Characteristic: CONFIRM      UUID: ...03
│     Properties:  Write Without Response
│     Payload:     1 byte; 0x01 = accepted, 0x00 = rejected
│
└── Characteristic: ENDPOINT     UUID: ...04
      Properties:  Notify
      Payload:     Null-terminated UTF-8 "<IPv4>:<port>" of QUIC listener
```

### BLE Pairing Sequence (abbreviated)

For the full sequence including security analysis, see [`docs/protocol/pairing.md`](docs/protocol/pairing.md).

```
Initiator                                        Responder
      │                                               │
      │── GATT Connect ───────────────────────────────►│
      │── Write PUBLIC_KEY (initiator pub, 32 B) ─────►│
      │◄── Notify PUBLIC_KEY (responder pub, 32 B) ────│
      │                                                │
      │  [Both sides: Rust computes DH + derives session key]
      │  [Both sides: Rust derives PIN]
      │  [Both sides: Flutter displays PIN]
      │                                                │
      │  [User verifies PIN matches out-of-band]       │
      │── Write CONFIRM (0x01) ────────────────────────►│
      │◄── Notify ENDPOINT ("192.168.x.x:port") ───────│
      │                                                │
      │  [→ Session Establishment (QUIC) begins]       │
```

---

## 8. Discovery Module Design

The `core/src/discovery/` module is the Rust-owned component for mDNS-based peer discovery on desktop platforms. It supplements BLE discovery and is the primary discovery mechanism on Linux, where BLE scanning may be unavailable.

### Module Responsibilities

| File | Responsibility |
|------|----------------|
| `mod.rs` | Module root; re-exports public types; wires service to Tokio runtime |
| `mdns.rs` | mDNS advertiser (registers `_ethersynapse._udp.local.`) and resolver (listens for peers) |
| `peer.rs` | `Peer` struct: ephemeral ID, display name, capability flags, last-seen timestamp, resolved address |
| `protocol.rs` | Protocol constants: service type string, TXT record keys, protocol version integer |
| `service.rs` | `DiscoveryService` trait: abstraction over discovery backends (mDNS impl + future BLE Rust impl if needed) |

### mDNS Service Record

```
Service type:  _ethersynapse._udp.local.

TXT record:
  name = <device display name, UTF-8>
  v    = 1                              ← protocol version integer
  id   = <random 8-byte hex, per-boot> ← ephemeral, non-persistent, for deduplication
```

### Discovery Events (bridge stream)

The discovery module emits the following event types to Flutter:

| Event | Fields |
|-------|--------|
| `PeerFound` | `id: String`, `name: String`, `address: String`, `source: "mdns"\|"ble"` |
| `PeerLost` | `id: String` |
| `PeerUpdated` | `id: String`, `name: String`, `address: String` |

Flutter's discovery feature merges BLE events (from the platform channel) and mDNS events (from the bridge stream) into a single deduplicated peer list using the ephemeral `id` field as the deduplication key.

### Platform Coverage

| Platform | BLE Discovery | mDNS Discovery |
|----------|--------------|----------------|
| Android | ✓ (platform channel) | ○ (optional, via bridge) |
| iOS | ✓ (platform channel) | ○ (optional, via bridge) |
| macOS | ✓ (platform channel) | ✓ (bridge) |
| Windows | ✓ (platform channel, WinRT) | ✓ (bridge) |
| Linux | ✗ (unavailable without BlueZ) | ✓ (bridge, primary) |

For the full discovery protocol specification, see [`docs/protocol/ble-discovery.md`](docs/protocol/ble-discovery.md).

---

## 9. Transport Layer Design

### QUIC Session Lifecycle

```
┌──────────────────────────────────────────────────────────────────┐
│  QUIC Endpoint (Quinn + Tokio)                                   │
│                                                                  │
│  ┌──────────────┐              ┌───────────────────────────────┐ │
│  │  Sender      │              │  Receiver                     │ │
│  │              │              │                               │ │
│  │ open_stream  │─────────────►│ accept_stream                 │ │
│  │ send_manifest│─────────────►│ read_manifest                 │ │
│  │ send_chunks  │─────────────►│ recv_chunks → write_file      │ │
│  │ send_fin     │─────────────►│ verify SHA-256                │ │
│  └──────────────┘              └───────────────────────────────┘ │
└──────────────────────────────────────────────────────────────────┘
```

### Connection Establishment

1. Responder's Rust core binds a Quinn QUIC endpoint on a random ephemeral port on the Wi-Fi interface.
2. The address (IP:port) is delivered to the initiator via BLE GATT (`ENDPOINT` characteristic).
3. Initiator's Rust core opens a QUIC connection. The QUIC session layer uses a custom Quinn crypto provider backed by the BLE-pairing-derived session key (replacing TLS). See [`docs/protocol/session-establishment.md`](docs/protocol/session-establishment.md).
4. After QUIC handshake, a **Session Hello** message is exchanged to confirm protocol version and capabilities.
5. Each file transfer opens a new unidirectional QUIC stream.

> **Security Note:** The custom QUIC cryptography described in step 3 is an architectural placeholder. The final implementation approach — including whether to use a fully custom `crypto::Session` or an alternative mechanism — is subject to security review during the Rust implementation phase. The project prefers established, audited cryptographic primitives in all cases. No transport security decision is final until it has been reviewed.

### Transfer Frame Layout

```
Byte  0        1        2        3        4 …
      ┌────────┬────────────────────────┬──────────────────────────┐
      │ Frame  │   Payload Length       │  Encrypted Payload       │
      │ Type   │   (u32, big-endian)    │  (ChaCha20-Poly1305)     │
      └────────┴────────────────────────┴──────────────────────────┘
       1 byte         4 bytes                   N bytes

Frame Types:
  0x01  MANIFEST        file name, size (u64), SHA-256 (32 B), chunk metadata
  0x02  CHUNK           chunk index (u32) + payload bytes
  0x03  FIN             end-of-file marker (empty payload)
  0x04  ABORT           reason code (u16) + reason string
  0x05  ACK             chunk index (u32) + status (u8)
  0x06  BATCH_MANIFEST  file count (u16) + N × MANIFEST payloads
```

Chunk size: 64 KiB default, negotiated per transfer in MANIFEST. For the full transfer protocol specification, see [`docs/protocol/transfer-protocol.md`](docs/protocol/transfer-protocol.md).

---

## 10. Security Model

### Threat Model

| Threat | Mitigation |
|--------|-----------|
| Passive eavesdropper on local network | ChaCha20-Poly1305 encrypts all transferred bytes |
| Active MITM during BLE pairing | Out-of-band PIN verification; attacker computes a different PIN |
| Session replay | Ephemeral X25519 key pairs per session; no key reuse |
| Malicious peer advertising | User must confirm PIN before QUIC session opens |
| File integrity tampering in transit | SHA-256 checksum verified by receiver before delivery |
| Persistent cross-session tracking | No persistent device identity; mDNS `id` is re-randomised per boot |
| Key material exposed to Flutter | Impossible: bridge API exposes no key retrieval function (see §5) |
| Key material persisted to disk | Session keys held in Rust memory only; zeroed on drop via `zeroize` |

### Key Derivation

```
Step 1 — DH:
  raw_secret = X25519(local_ephemeral_priv, remote_ephemeral_pub)

Step 2 — Session key:
  salt        = SHA256(pubkey_A || pubkey_B)   ← lexicographically ordered
  session_key = HKDF-SHA256(
                  ikm  = raw_secret,
                  salt = salt,
                  info = b"ether-synapse-v1-session"
                )                              → 32 bytes, never leaves Rust

Step 3 — PIN:
  pin_bytes = SHA256(session_key || b"ether-synapse-v1-pin")[0..4]
  pin_int   = big_endian_u32(pin_bytes) mod 1_000_000
  pin_str   = format!("{:06}", pin_int)       → surfaced to Flutter as a String
```

### Nonce Strategy

```
nonce (96 bits) = direction (8 bits) || stream_id (24 bits) || chunk_index (32 bits) || zero (32 bits)

direction: 0x00 = sender→receiver,  0x01 = receiver→sender
```

This ensures nonce uniqueness across all frames in a session even when both sides encrypt concurrently on different streams.

---

## 11. Development Workflow

### Environment Setup

```bash
# 1. Rust stable toolchain
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable

# 2. Rust targets for each platform you will build
rustup target add aarch64-linux-android      # Android ARM64
rustup target add aarch64-apple-ios          # iOS
rustup target add x86_64-unknown-linux-gnu   # Linux desktop

# 3. flutter_rust_bridge codegen CLI
cargo install flutter_rust_bridge_codegen

# 4. Flutter SDK — follow flutter.dev/docs/get-started/install

# 5. Verify
flutter doctor
cargo --version
flutter_rust_bridge_codegen --version
```

### Daily Development Loop

```
1. Pull latest from `develop`
2. Cut a feature or fix branch
3. Edit Rust source in core/ and/or bridge/src/api.rs
4. Run scripts/gen_bridge.sh  ← regenerate Dart bindings
5. Edit Flutter source in apps/mobile/lib/
6. Run scripts/lint.sh         ← Clippy + flutter analyze + dart format check
7. Run flutter run on target device or emulator
8. Open pull request → develop
```

### `scripts/gen_bridge.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

flutter_rust_bridge_codegen generate \
  --rust-input bridge/src/api.rs \
  --dart-output apps/mobile/lib/bridge/generated/ \
  --c-output apps/mobile/ios/Runner/bridge_generated.h
```

Generated files **must** be committed. Reviewers verify by re-running the script and diffing the output.

### `scripts/lint.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Rust: Clippy ==="
(cd core && cargo clippy --all-targets --all-features -- -D warnings)

echo "=== Flutter: analyze ==="
(cd apps/mobile && flutter analyze)

echo "=== Dart: format check ==="
(cd apps/mobile && dart format --output=none --set-exit-if-changed lib/)
```

---

## 12. Branching Strategy

### Branch Topology

```
main ──────────────────────────────────────────────────────────────►
  │                                          ▲              ▲
  │  (initial commit)                        │              │
  │                                          │              │
develop ────────────────────────────────────►│              │
  │        ▲          ▲         ▲            │              │
  │        │          │         │            │              │
  │  feature/A   feature/B   fix/C     release/1.0    hotfix/1.0.1
  │        │          │         │            │              │
  └────────┴──────────┴─────────┴────────────┴──────────────┘
```

### Branch Naming

| Prefix | Example | Source | Merge Target |
|--------|---------|--------|-------------|
| `feature/` | `feature/mdns-desktop-discovery` | `develop` | `develop` |
| `fix/` | `fix/ble-scan-crash-android` | `develop` | `develop` |
| `release/` | `release/1.0.0` | `develop` | `main` + `develop` |
| `hotfix/` | `hotfix/1.0.1-quic-timeout` | `main` | `main` + `develop` |

### Merge Rules

- All merges require a pull request with at least one approving review.
- `main` and `develop` are protected; direct pushes are prohibited.
- `feature/*` and `fix/*` are squash-merged to `develop` (clean linear history).
- `release/*` and `hotfix/*` are merge-committed to `main` (preserve release history).
- Release tags are applied to `main` commits: `v1.0.0`, `v1.1.0`, etc.

---

## 13. Dependency Policy

### Rust (Cargo)

| Crate | Purpose | Justification |
|-------|---------|--------------|
| `quinn` | QUIC transport | Best-maintained async QUIC in the Rust ecosystem; see ADR 0001 |
| `tokio` | Async runtime | Quinn requires Tokio; industry standard |
| `x25519-dalek` | X25519 key exchange | Audited; dalek ecosystem; constant-time |
| `chacha20poly1305` | AEAD encryption | RustCrypto; constant-time; see ADR 0002 |
| `sha2` | SHA-256 | RustCrypto |
| `hkdf` | Key derivation | RustCrypto |
| `zeroize` | Secure memory zeroing | RustCrypto; ensures key material is zeroed on drop |
| `mdns-sd` | mDNS advertisement + resolution | Pure Rust; no C dependency; Tokio-compatible |
| `flutter_rust_bridge` | FFI bridge | The established Flutter ↔ Rust bridge; see ADR 0005 |

**New Rust dependency checklist** (required in PR description):

1. Why no existing dependency fulfils this need.
2. Is the crate audited? Run `cargo audit` and include output.
3. Is the crate actively maintained (commits in last 6 months)?

### Dart / Flutter

| Package | Purpose |
|---------|---------|
| `flutter_rust_bridge` | Generated bridge runtime |
| `riverpod` | State management |
| `go_router` | Navigation |
| `file_picker` | Native file picker (no network capability) |
| `permission_handler` | Runtime permission requests |

**Prohibited package categories:** analytics, crash reporting, advertising SDKs, packages with network calls not explicitly required by the feature.

---

## 14. Rust Crate Scalability Note

> This section is informational. It does not prescribe an immediate change. It records the architectural recommendation for future reference.

### Current Structure

The Rust core is a **single crate** (`core/`). All modules — `crypto`, `discovery`, `transport`, `transfer`, `session` — live within this crate and are compiled together.

### Option A — Single Crate (Current)

All Rust code lives in `core/` as one `Cargo.toml` unit.

**Advantages:**
- Minimal build configuration.
- No intra-workspace dependency declarations.
- Simpler onboarding for contributors unfamiliar with Cargo workspaces.
- Module boundaries are enforced by Rust's `pub`/`pub(crate)` visibility system without requiring separate compilation units.

**Disadvantages:**
- Full recompilation of the entire core on any change.
- Module boundaries are advisory, not hard: a contributor can add `pub(crate)` visibility to bypass a module boundary without a structural refactor.
- As the codebase grows, build times increase proportionally.

### Option B — Cargo Workspace with Multiple Crates

The repository root becomes a Cargo workspace. Each major module becomes its own crate:

```
Cargo.toml                      ← workspace root
core-crypto/                    ← crate: key exchange, AEAD, hashing
core-discovery/                 ← crate: mDNS, peer model, service trait
core-transport/                 ← crate: QUIC endpoint, session, streams
core-transfer/                  ← crate: chunked send/receive, manifest
core-session/                   ← crate: state machine, session manager
bridge/                         ← crate: flutter_rust_bridge API (depends on all above)
```

**Advantages:**
- Hard module boundaries: cross-crate access requires explicit public API.
- Incremental compilation: changing `core-discovery` does not recompile `core-crypto`.
- Independent versioning and changelogs per crate.
- Enables community contributions to individual crates without full-stack knowledge.

**Disadvantages:**
- Higher initial setup cost.
- `flutter_rust_bridge` codegen and the `bridge/` crate must explicitly list all upstream dependencies.
- Workspace configuration adds onboarding friction for new contributors.

### Recommendation

**For MVP: remain with a single crate.**

The single-crate approach is appropriate while the codebase is small, the team is small, and build times are not yet a bottleneck. The existing module structure (`crypto/`, `discovery/`, `transport/`, `transfer/`, `session/`) provides sufficient logical separation, and Rust's visibility system enforces boundaries at the file and module level.

**For long-term open-source growth: migrate to a Cargo workspace.**

When any of the following conditions are met, initiate the workspace migration:

- Cold build time for `core/` exceeds 3 minutes on a modern developer machine.
- The project accepts contributions from maintainers who own individual subsystems (e.g., a discovery specialist who should not need full-stack context).
- The `discovery` or `crypto` modules are considered for extraction as standalone reusable libraries.
- The bridge API surface grows to the point where a single `api.rs` file becomes unwieldy (>500 lines).

The migration should be driven by a dedicated ADR (`0006-cargo-workspace.md`) at that time.

---

*End of ARCHITECTURE.md*
