# ADR 0001 — QUIC as the File Transfer Transport Protocol

**Status**: Accepted

**Date**: June 2026

---

## Context

Ether Synapse requires a transport mechanism for transferring potentially large files between two devices on a local Wi-Fi network. The transport must:

- Provide high throughput on a local LAN (hundreds of Mbps).
- Recover gracefully from transient packet loss.
- Support multiplexed concurrent transfers without head-of-line blocking.
- Provide a foundation for application-layer encryption without relying on a certificate authority or TLS PKI.
- Have a mature, well-audited Rust implementation available.
- Work without internet connectivity or external servers.

---

## Decision

We adopt **QUIC** (specifically the **Quinn** Rust crate) as the sole transport protocol for file data.

QUIC runs over UDP and provides:

- **Stream multiplexing** — Multiple file transfers can occur concurrently on the same QUIC connection without head-of-line blocking.
- **Built-in loss recovery** — QUIC implements its own reliable delivery and retransmission over UDP.
- **Custom crypto provider** — Quinn supports replacing the TLS 1.3 session layer with a custom `crypto::Session` implementation, allowing us to use the BLE-pairing-derived session key directly without certificates.
- **Path migration** — If the device's IP address changes during a transfer (rare on LAN, but possible), QUIC can migrate the connection without interruption.

Quinn is chosen over alternatives because it is the most mature async-native QUIC implementation in Rust, has an active maintenance team, and integrates natively with the Tokio async runtime already required by the project.

---

## Consequences

**Positive:**
- No head-of-line blocking between concurrent file streams.
- Custom crypto provider eliminates certificate management entirely.
- Multiplexing allows batch file transfer over a single connection.
- QUIC's 0-RTT is not used (we use a full handshake every session), which is acceptable given pairing latency already exceeds 0-RTT benefits.

**Negative:**
- Some corporate or enterprise Wi-Fi networks block UDP traffic. Ether Synapse targets home and ad-hoc networks; this is an acceptable trade-off for v1.
- Implementing the custom crypto provider requires careful implementation to avoid cryptographic misuse.
- QUIC adds protocol complexity compared to raw TCP. This is mitigated by using Quinn rather than implementing QUIC from scratch.

---

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **TCP + TLS** | Head-of-line blocking across streams; requires TLS with certs or a custom protocol on top; heavier per-connection overhead |
| **WebRTC DataChannel** | Designed for browser-to-browser; dependency footprint is large; not idiomatic in a native Rust context |
| **Raw UDP (custom protocol)** | Would require implementing reliability, ordering, and congestion control from scratch — QUIC solves all of these |
| **Wi-Fi Direct / WFD** | Platform API support is inconsistent across all 5 target platforms; not available on Linux desktop |
| **SCTP** | Limited OS support on macOS and Windows without third-party libraries; not available in the Rust async ecosystem with comparable maturity |
