# ADR 0004 — Strictly Local Architecture (No Cloud Dependency)

**Status**: Accepted

**Date**: June 2026

---

## Context

Many file transfer applications route data through cloud infrastructure for convenience: relay servers handle NAT traversal, accounts provide device identity, and cloud storage enables asynchronous transfers. These conveniences come with costs:

- User data transits third-party servers, creating legal and privacy exposure.
- Services can be discontinued, leaving users stranded.
- Accounts require registration and create honeypots of personal information.
- Cloud relay introduces latency and bandwidth costs.
- Internet dependency breaks offline use cases.

Ether Synapse is explicitly designed for users who prioritise privacy and control. Any cloud dependency — even an optional one — undermines the trust model.

---

## Decision

Ether Synapse operates with **zero cloud dependency**. Specifically:

- **No relay servers.** All data travels directly between devices on the local network.
- **No STUN or TURN.** NAT traversal is not attempted. The application targets local network use cases where STUN/TURN are unnecessary.
- **No accounts or registration.** No user identity is created, stored, or transmitted to any external service.
- **No telemetry.** No analytics, crash reporting, usage metrics, or diagnostic data is collected or transmitted.
- **No update checks.** The application does not contact any server at runtime. Updates are distributed via platform app stores or direct download; the application itself does not check for or apply updates.
- **No CDN dependencies.** All application assets are bundled. No fonts, icons, or resources are fetched from the internet at runtime.

This applies to all builds: debug, profile, and release.

---

## Consequences

**Positive:**
- Unconditional privacy: user data never reaches infrastructure we do not control.
- Works entirely offline and in air-gapped environments.
- No server infrastructure to maintain, secure, or pay for.
- No single point of failure or service discontinuation risk.
- Legal exposure is minimised: we hold no user data and transmit none.
- Trust is verifiable: users and auditors can confirm the behaviour by reviewing the open-source code.

**Negative:**
- **No cross-network transfer.** If two devices are on different LANs (e.g., home and office), Ether Synapse cannot transfer files without a VPN or shared network. This is a deliberate constraint, not a bug.
- **No transfer history or cloud sync.** There is no persistent record of past transfers outside the device's local file system.
- **Discovery is proximity-limited.** BLE and mDNS only work on the local network or within BLE range. There is no remote device lookup.

---

## Implications for Future Features

Any feature proposal that would introduce a network call to an external server must be rejected or redesigned to remain fully local. Examples of proposals that are **not acceptable**:

- Optional cloud relay for cross-network transfers.
- Cloud backup of transfer history.
- Server-side device directory or contact list.
- Crash reporting or analytics (even anonymised).

Examples of proposals that **are acceptable**:

- VPN-aware mode (works transparently if the user's VPN bridges two LANs).
- Local network device history stored on-device only.
- Export of transfer logs to a local file.

---

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Optional cloud relay** | "Optional" features inevitably become default; privacy model is undermined even for users who disable it because the infrastructure exists |
| **Self-hosted relay** | Shifts operational burden to the user; most users cannot host and maintain a relay server |
| **IPFS or DHT-based transfer** | Introduces dependency on a global peer-to-peer network; data may transit nodes outside user control |
| **E2E-encrypted cloud with zero-knowledge server** | Server still receives ciphertext and metadata; legal subpoenas or server compromise remain risks |
