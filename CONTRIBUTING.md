# Contributing to Ether Synapse

First off, thank you for taking the time to contribute. Ether Synapse is a community-driven open-source project and every contribution — whether it's a bug report, documentation improvement, or new feature — makes a real difference.

Please read this guide before opening your first issue or pull request. Following these conventions keeps the project healthy and makes review fast.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
  - [Reporting Bugs](#reporting-bugs)
  - [Requesting Features](#requesting-features)
  - [Improving Documentation](#improving-documentation)
  - [Contributing Code](#contributing-code)
- [Development Setup](#development-setup)
  - [Prerequisites](#prerequisites)
  - [Repository Layout](#repository-layout)
  - [Building the Project](#building-the-project)
  - [Running Tests](#running-tests)
- [Code Style](#code-style)
  - [Dart / Flutter](#dart--flutter)
  - [Rust](#rust)
  - [Documentation](#documentation)
- [Commit Conventions](#commit-conventions)
- [Branching Strategy](#branching-strategy)
- [Pull Request Process](#pull-request-process)
- [Architecture Decision Records (ADRs)](#architecture-decision-records-adrs)
- [Security Vulnerabilities](#security-vulnerabilities)
- [Community & Communication](#community--communication)

---

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating, you agree to uphold it. Please report unacceptable behavior to the project maintainers.

---

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/ether-synapse.git
   cd ether-synapse
   ```
3. **Add the upstream remote:**
   ```bash
   git remote add upstream https://github.com/ether-synapse/ether-synapse.git
   ```
4. **Create a branch** from `develop` (not `main`) for your work:
   ```bash
   git fetch upstream
   git checkout -b feat/my-feature upstream/develop
   ```
5. When ready, open a pull request against `develop`.

---

## How to Contribute

### Reporting Bugs

Before filing a bug report:

- Search [existing issues](https://github.com/ether-synapse/ether-synapse/issues) to avoid duplicates.
- Try to reproduce the issue on the latest `develop` build.

When filing a bug report, use the **[Bug Report](.github/ISSUE_TEMPLATE/bug_report.yml)** template and include:

- Steps to reproduce (be specific)
- Expected behavior
- Actual behavior
- Platform(s) affected and OS versions
- App version or commit hash
- Relevant logs or screenshots

### Requesting Features

Use the **[Feature Request](.github/ISSUE_TEMPLATE/feature_request.yml)** template.

Before requesting a feature:

- Check the [ROADMAP.md](ROADMAP.md) to see if it is already planned.
- Search [Discussions](https://github.com/ether-synapse/ether-synapse/discussions) to see if it has already been proposed.
- Ensure the feature aligns with the project's core values: **privacy-first, no cloud dependency, no accounts**.

### Improving Documentation

Documentation improvements are among the most valuable contributions. You can:

- Fix typos, grammar, or formatting issues
- Clarify ambiguous passages
- Add missing sections to existing documents
- Translate documentation (coordinate in Discussions first)

Documentation lives in:
- Root markdown files (`README.md`, `ARCHITECTURE.md`, etc.)
- `docs/` directory (architecture docs, protocol specs, ADRs)

### Contributing Code

Before starting significant coding work:

1. Open an issue to discuss the change if one doesn't exist.
2. For major features, write or reference an ADR in `docs/decisions/`.
3. Get at least one maintainer acknowledgement before investing heavy effort.

For small fixes (typos, minor bugs), open a PR directly without a preceding issue.

---

## Development Setup

### Prerequisites

| Tool | Version | Purpose |
|---|---|---|
| Flutter SDK | stable (latest) | UI framework |
| Dart SDK | bundled with Flutter | Flutter language |
| Rust toolchain | stable (latest) | Core engine |
| `cargo` | bundled with Rust | Rust package manager |
| `flutter_rust_bridge_codegen` | latest | FFI bridge code generation |
| `cargo-ndk` | latest | Android cross-compilation |
| `cargo-lipo` | latest | iOS universal binary |
| Android SDK | API 26+ | Android development |
| Xcode | 15+ | iOS/macOS development |

Install Rust:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Install Flutter:
Follow the official guide at https://flutter.dev/docs/get-started/install

Install bridge tools:
```bash
cargo install flutter_rust_bridge_codegen
cargo install cargo-ndk
cargo install cargo-lipo
```

### Repository Layout

```
ether-synapse/
├── apps/
│   ├── mobile/       # Flutter app for Android + iOS
│   └── desktop/      # Flutter app for Windows + macOS + Linux
├── core/
│   ├── engine/       # Top-level Rust crate (library), used by bridge
│   ├── ble/          # BLE abstraction layer crate
│   ├── transport/    # QUIC transport crate
│   ├── crypto/       # Cryptography primitives crate
│   └── proto/        # Protocol message types crate
├── docs/             # All project documentation
├── assets/           # Shared application assets
├── tests/            # Integration and E2E tests
└── scripts/          # Developer utility scripts
```

### Building the Project

```bash
# Step 1: Install Dart/Flutter dependencies
cd apps/mobile
flutter pub get
cd ../desktop
flutter pub get
cd ../..

# Step 2: Generate flutter_rust_bridge bindings
cd core/engine
flutter_rust_bridge_codegen generate
cd ../..

# Step 3: Build Rust for desktop (native)
cd core/engine
cargo build
cd ../..

# Step 4: Run the Flutter app
cd apps/mobile
flutter run -d <device>
```

For platform-specific build steps, see `docs/development/`.

### Running Tests

**Rust unit tests:**
```bash
cd core
cargo test --workspace
```

**Flutter unit tests:**
```bash
cd apps/mobile
flutter test
```

**Flutter integration tests:**
```bash
cd apps/mobile
flutter test integration_test/
```

**All tests (via script):**
```bash
./scripts/test-all.sh
```

---

## Code Style

### Dart / Flutter

- Follow the official [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- All code must pass `dart format` with no changes.
- All code must pass `flutter analyze` with no warnings or errors.
- Use Riverpod for all state management. Do not use `setState` in feature code.
- Prefer named parameters for functions with more than two arguments.
- Write docstrings for all public APIs.

Format and analyze before committing:
```bash
dart format .
flutter analyze
```

### Rust

- Follow the [Rust API Guidelines](https://rust-lang.github.io/api-guidelines/).
- All code must pass `cargo fmt --all` with no changes.
- All code must pass `cargo clippy --all-targets --all-features -- -D warnings`.
- Use `thiserror` for error types. Avoid `unwrap()` in library code — prefer `?` propagation.
- All cryptographic material (private keys, session secrets) must implement `zeroize::Zeroize`.
- Write doc comments for all public items. Include `# Examples` sections for non-trivial APIs.
- Unsafe code requires a `// SAFETY:` comment explaining the invariant.

Format and lint before committing:
```bash
cargo fmt --all
cargo clippy --all-targets --all-features -- -D warnings
```

### Documentation

- Use [Markdown](https://commonmark.org) for all documentation.
- Diagrams are written as [Mermaid](https://mermaid.js.org) diagrams embedded in Markdown, or stored as source files in `docs/diagrams/`.
- ADRs follow the template at `docs/decisions/000-adr-template.md`.
- Write in clear, plain English. Avoid jargon where possible.

---

## Commit Conventions

Ether Synapse uses [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

**Format:**
```
<type>(<scope>): <short summary>

[optional body]

[optional footer(s)]
```

**Types:**

| Type | When to use |
|---|---|
| `feat` | A new feature |
| `fix` | A bug fix |
| `docs` | Documentation only changes |
| `style` | Formatting changes (no logic change) |
| `refactor` | Code restructuring (no feature or fix) |
| `perf` | Performance improvement |
| `test` | Adding or fixing tests |
| `chore` | Build system, dependency updates, CI |
| `security` | Security fix or hardening |

**Scopes** (use the crate or module name):
- `crypto`, `transport`, `ble`, `proto`, `engine` — Rust crates
- `mobile`, `desktop` — Flutter apps
- `ci`, `docs`, `deps`, `release` — Other

**Examples:**
```
feat(transport): implement QUIC connection pool with backpressure
fix(crypto): zeroize session keys on drop via zeroize crate
docs(protocol): add handshake sequence diagram
chore(deps): update quinn to 0.11.0
security(crypto): fix timing side-channel in fingerprint comparison
```

**Rules:**
- Summary line must be 72 characters or fewer.
- Use the imperative mood: "add feature" not "added feature".
- Reference issues in the footer: `Closes #42` or `Fixes #17`.
- Breaking changes: append `!` after the type/scope and add `BREAKING CHANGE:` in the footer.

---

## Branching Strategy

| Branch | Purpose | Protected |
|---|---|---|
| `main` | Latest stable release | ✅ Yes |
| `develop` | Integration branch for next release | ✅ Yes |
| `feat/<name>` | New features | No |
| `fix/<name>` | Bug fixes | No |
| `docs/<name>` | Documentation work | No |
| `chore/<name>` | Maintenance tasks | No |
| `release/<version>` | Release preparation | ✅ Yes (once cut) |
| `hotfix/<name>` | Emergency fixes to `main` | No |

**Rules:**
- Never commit directly to `main` or `develop`.
- Feature branches are created from `develop` and merged back into `develop`.
- `main` only receives merges from `release/*` or `hotfix/*` branches.
- Hotfixes are branched from `main`, merged to `main`, and back-merged to `develop`.

---

## Pull Request Process

1. **Open early** — Draft PRs are welcome. Mark as `[Draft]` if not ready for review.
2. **Fill the template** — Complete all sections of the PR template.
3. **Keep PRs small** — A PR should do one thing. Split large changes into multiple PRs.
4. **All CI checks must pass** — Do not ask for review until CI is green.
5. **Resolve all review comments** — Address every comment before re-requesting review.
6. **Do not force-push after review starts** — Use merge commits to add changes.
7. **One approving review required** — Two required for changes to `crypto/` or `transport/`.
8. **Squash and merge** — PRs are squash-merged into `develop` to maintain a clean history.

**Security-sensitive code** (anything in `core/crypto/` or affecting the handshake protocol) requires review from a maintainer with cryptography background before merging.

---

## Architecture Decision Records (ADRs)

Significant technical decisions are documented as Architecture Decision Records in `docs/decisions/`.

If your PR involves a major technical decision (choice of library, protocol change, API design), write an ADR:

1. Copy the template: `docs/decisions/000-adr-template.md`
2. Name it: `docs/decisions/NNN-short-title.md` (next available number)
3. Fill in all sections: Context, Decision, Consequences
4. Submit the ADR in its own commit or PR before or alongside the implementing PR

---

## Security Vulnerabilities

**Do not open public issues for security vulnerabilities.**

Please follow the responsible disclosure process described in [SECURITY.md](SECURITY.md).

---

## Community & Communication

| Channel | Purpose |
|---|---|
| [GitHub Issues](https://github.com/ether-synapse/ether-synapse/issues) | Bug reports, feature requests |
| [GitHub Discussions](https://github.com/ether-synapse/ether-synapse/discussions) | General discussion, ideas, Q&A |
| [GitHub Pull Requests](https://github.com/ether-synapse/ether-synapse/pulls) | Code review and contributions |

We do not use Discord or Slack. GitHub Discussions is the primary community space.

---

## Recognition

All contributors are recognized in `CHANGELOG.md` release notes and the GitHub contributors list.

Thank you for helping build Ether Synapse. 🙏
