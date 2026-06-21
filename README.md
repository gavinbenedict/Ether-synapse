<p align="center">
  <img src="docs/assets/logo.png" alt="Ether Synapse" width="120" height="120" />
</p>

<h1 align="center">Ether Synapse</h1>

<p align="center">
  Privacy-first, peer-to-peer file transfer — no cloud, no accounts, no compromise.
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: Apache 2.0" src="https://img.shields.io/badge/license-Apache%202.0-blue.svg" /></a>
  <a href="https://flutter.dev"><img alt="Flutter" src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" /></a>
  <a href="https://www.rust-lang.org"><img alt="Rust" src="https://img.shields.io/badge/Rust-1.80+-DEA584?logo=rust" /></a>
  <img alt="Platforms" src="https://img.shields.io/badge/platforms-Android%20%7C%20iOS%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-brightgreen" />
</p>

---

## What Is Ether ynapse?

Ether Synapse is a free, open-source, privacy-first file transfer application. It transfers files directly between devices over a local Wi-Fi network at maximum speed, using Bluetooth Low Energy only to discover, pair, and verify nearby peers. Nothing ever leaves your local network. There are no servers, no accounts, no telemetry, and no subscriptions — ever.

## Principles

| Principle | Implementation |
|-----------|----------------|
| Zero cloud | All data stays on the local network between devices |
| Zero accounts | No registration, no identity, no login |
| Zero tracking | No analytics, no crash reporting, no usage metrics |
| Zero cost | Free forever; Apache 2.0 licensed |
| Encrypted by default | X25519 key exchange + ChaCha20-Poly1305 per session |
| Fast | QUIC transport over Wi-Fi Direct / local network |
| Cross-platform | Android, iOS, Windows, macOS, Linux |

## How It Works

```
┌──────────────────────────────────────────────────────┐
│                    Discovery Phase                   │
│  BLE Advertisement ──► Peer Scan ──► Device Found   │
└─────────────────────────┬────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────┐
│                    Pairing Phase                     │
│  X25519 Key Exchange ──► PIN Verification ──► Trust  │
└─────────────────────────┬────────────────────────────┘
                          │
┌─────────────────────────▼────────────────────────────┐
│                   Transfer Phase                     │
│  QUIC Channel ──► ChaCha20-Poly1305 ──► Files Sent  │
└──────────────────────────────────────────────────────┘
```

1. **Discover** — BLE advertisements let devices find each other without Wi-Fi credentials.
2. **Pair** — An X25519 ephemeral key exchange is completed over BLE. A short numeric PIN is shown on both screens for out-of-band verification.
3. **Transfer** — A QUIC connection is established peer-to-peer over Wi-Fi. Every byte is encrypted with ChaCha20-Poly1305 using the session key derived during pairing.

## Technology Stack

| Layer | Technology |
|-------|-----------|
| UI | Flutter 3 · Dart · Riverpod · GoRouter |
| Bridge | flutter_rust_bridge |
| Core engine | Rust |
| Transport | QUIC (Quinn) · Tokio async runtime |
| Discovery | Bluetooth Low Energy (platform APIs via Flutter) |
| Key exchange | X25519 |
| Encryption | ChaCha20-Poly1305 |
| Integrity | SHA-256 |

## Supported Platforms

| Platform | Minimum Version |
|----------|----------------|
| Android | 8.0 (API 26) |
| iOS | 15.0 |
| macOS | 12.0 Monterey |
| Windows | 10 (1903) |
| Linux | Ubuntu 20.04+ / equivalent |

## Repository Structure

```
ether_synapse/
├── apps/
│   └── mobile/                 # Flutter application
├── core/                       # Rust core engine
├── bridge/                     # flutter_rust_bridge glue
├── docs/                       # Project documentation
└── scripts/                    # Developer utility scripts
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for the full structural breakdown and module boundary definitions.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.22
- [Rust toolchain](https://rustup.rs) ≥ 1.80 (stable)
- [flutter_rust_bridge CLI](https://cjycode.com/flutter_rust_bridge/)
- Platform SDK for your target (Android Studio / Xcode / MSVC Build Tools)

### Clone

```bash
git clone https://github.com/your-org/ether_synapse.git
cd ether_synapse
```

### Build the Rust core

```bash
cd core
cargo build --release
```

### Generate the bridge

```bash
cd bridge
flutter_rust_bridge_codegen generate
```

### Run the Flutter app

```bash
cd apps/mobile
flutter pub get
flutter run
```

## Contributing

Contributions are welcome. Please read [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) before opening a pull request.

### Branching Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable, release-ready code |
| `develop` | Integration branch for features |
| `feature/*` | Individual feature work |
| `fix/*` | Bug fixes |
| `release/*` | Release preparation |
| `hotfix/*` | Emergency production fixes |

All feature branches are cut from `develop` and merged back via pull request. Merges to `main` happen only from `release/*` or `hotfix/*` branches.

## Security

Ether Synapse is designed with security as a first-class concern:

- **Forward secrecy** — Ephemeral X25519 key pairs are generated fresh for every session. Compromising a past session key reveals nothing about future sessions.
- **Authenticated encryption** — ChaCha20-Poly1305 provides both confidentiality and integrity for every transferred byte.
- **Out-of-band verification** — The short PIN shown during pairing allows users to confirm they are talking to the intended device, not a rogue attacker.
- **No persistent identity** — Devices have no persistent cryptographic identity. Each pairing is independent.
- **Local network only** — The transfer channel is a direct QUIC connection on the local network. No relay, no STUN, no TURN.

To report a security vulnerability, please open a confidential issue or email the maintainers directly. Do not disclose security issues publicly before they are resolved.

## License

Ether Synapse is released under the [Apache License 2.0](LICENSE).

---

<p align="center">Built with ❤️ and zero compromise on privacy.</p>
