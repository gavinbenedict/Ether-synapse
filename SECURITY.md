# Security Policy

## Our Commitment

Ether Synapse is a privacy-first application. Security is not a feature — it is the foundation. We take vulnerability reports seriously, respond promptly, and are committed to transparent disclosure once fixes are in place.

---

## Supported Versions

Security fixes are backported to the latest stable release and the active development branch. Older releases do not receive security patches.

| Version | Supported |
|---|---|
| `develop` (main branch) | ✅ Always |
| Latest stable release | ✅ Yes |
| Previous stable release | ⚠️ Critical fixes only (90 days) |
| Older releases | ❌ No |

---

## Reporting a Vulnerability

**Please do not open a public GitHub issue for security vulnerabilities.**

Public issues are visible to everyone, including potential attackers, before a fix is available. We use a responsible disclosure process to protect users.

### How to Report

**Option 1 (Preferred): GitHub Private Vulnerability Reporting**

Use GitHub's built-in private vulnerability reporting:

1. Go to the [Security tab](https://github.com/ether-synapse/ether-synapse/security) of the repository.
2. Click **"Report a vulnerability"**.
3. Fill out the form with as much detail as possible.

This creates a private security advisory visible only to maintainers.

**Option 2: Encrypted Email**

Send an encrypted email to the security team. PGP key details will be published in `docs/security/pgp-keys.md` once the project reaches public release.

### What to Include

A high-quality report helps us respond faster. Please include:

- **Description** — What is the vulnerability? What is the impact?
- **Component** — Which part of the system is affected (e.g., `core/crypto`, BLE handshake, QUIC transport)?
- **Reproduction steps** — How can we reproduce the issue? Include code, commands, or network traces.
- **Proof of concept** — If safe to share, include a PoC demonstrating exploitability.
- **Affected versions** — Which versions are affected?
- **Suggested fix** — If you have one, we welcome suggestions.
- **Your disclosure timeline preference** — We will respect reasonable requests.

---

## Response Process

| Step | Timeline |
|---|---|
| **Acknowledgement** | Within 48 hours of receipt |
| **Initial assessment** | Within 5 business days |
| **Status update** | Every 7 days until resolved |
| **Fix development** | Depends on severity (see below) |
| **Coordinated disclosure** | After fix is available and deployed |

### Severity and Fix Timeline

| Severity | CVSS Score | Target Fix Time |
|---|---|---|
| Critical | 9.0 – 10.0 | 7 days |
| High | 7.0 – 8.9 | 14 days |
| Medium | 4.0 – 6.9 | 30 days |
| Low | 0.1 – 3.9 | 90 days |

We will notify you when:
- The vulnerability has been confirmed
- A fix is developed and ready
- The fix is released
- The public advisory is published

---

## Coordinated Disclosure

We follow a coordinated disclosure model:

1. Reporter submits vulnerability privately.
2. Maintainers confirm and develop a fix.
3. Fix is prepared in a private branch.
4. We agree on a disclosure date with the reporter (typically after the fix is released).
5. Fix is released as a patch version.
6. Public security advisory is published on GitHub.
7. CVE (if applicable) is requested and published.

We aim to have fixes released within the timelines above. If exceptional circumstances delay a fix, we will communicate this and agree on an extension.

---

## Scope

The following are **in scope** for vulnerability reports:

- All code in this repository
- The Ether Synapse wire protocol (authentication, encryption, handshake)
- BLE-based device discovery and pairing logic
- QUIC transport security
- Cryptographic implementation correctness
- Session key lifecycle and zeroization
- Man-in-the-middle attacks during connection establishment
- Replay attacks
- Denial-of-service attacks with significant impact on usability

The following are **out of scope:**

- Vulnerabilities in third-party dependencies (report to those projects first; notify us if Ether Synapse is directly impacted)
- Social engineering attacks
- Physical attacks requiring access to an unlocked device
- Vulnerabilities in the operating system or hardware platform
- Issues that require the attacker to already have root/admin access to the device

---

## Safe Harbor

We consider security research conducted in good faith under this policy to be authorized. We will not take legal action against researchers who:

- Report vulnerabilities through the proper channels described above
- Do not access, modify, or exfiltrate data belonging to other users
- Do not perform denial-of-service attacks against production infrastructure
- Do not publicly disclose the vulnerability before coordinated disclosure is complete
- Act in good faith to avoid harm

---

## Security Architecture

For a detailed description of the security mechanisms built into Ether Synapse, see:

- [ARCHITECTURE.md](ARCHITECTURE.md) — Security Layer section
- [docs/security/threat-model.md](docs/security/threat-model.md) — Full threat model
- [docs/security/cryptography.md](docs/security/cryptography.md) — Cryptographic design decisions
- [docs/protocol/handshake.md](docs/protocol/handshake.md) — Protocol handshake specification

---

## Hall of Fame

We maintain a public list of researchers who have responsibly disclosed security vulnerabilities to us. Once the project reaches public release, this list will be published at `docs/security/hall-of-fame.md`.

---

## Contact

For questions about this policy (not vulnerability reports), open a [GitHub Discussion](https://github.com/ether-synapse/ether-synapse/discussions/categories/security).
