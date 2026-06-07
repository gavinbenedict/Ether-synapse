# Session Establishment Protocol

> Protocol Version: 1.0 · Status: Draft

---

## Purpose

The Session Establishment Protocol defines how a QUIC connection is opened between two Ether Synapse devices after the Pairing Protocol has completed and a shared session key is held in both Rust cores. It authenticates the connection at the application layer using the session key material produced during pairing, and produces a live, authenticated, encrypted transport session ready for file transfer.

This protocol runs entirely inside the Rust core (`core/src/transport/`). Flutter observes session state changes via the bridge but participates in no protocol logic.

---

## Responsibilities

| Responsibility | Owner |
|----------------|-------|
| Binding the QUIC listener endpoint | **Rust — `transport::endpoint`** |
| Reporting the listener address to Flutter for GATT delivery | **Rust — `transport::endpoint`** (bridge call) |
| Establishing the QUIC connection to the responder's address | **Rust — `transport::endpoint`** |
| Custom QUIC crypto provider (pre-shared session key) | **Rust — `transport::session`** |
| Application-layer session hello / capability exchange | **Rust — `transport::session`** |
| Session state machine transitions | **Rust — `session::state`** |
| Notifying Flutter of session readiness | **Rust — `session::manager`** (bridge event stream) |
| Displaying connection status to the user | Flutter presentation layer |

---

## QUIC Endpoint Configuration

Standard QUIC uses TLS 1.3 for authentication and key exchange. Ether Synapse replaces the TLS layer with a custom Quinn `crypto` provider that authenticates the connection using the session key derived during BLE pairing.

Rationale for bypassing TLS:

- There are no certificates or certificate authorities in a zero-account system.
- The session key already provides mutual authentication (both sides derived the same key from a verified DH exchange).
- Using TLS on top of the session key would be redundant and would introduce dependency on TLS certificate management.

The custom crypto provider implements the `quinn::crypto::Session` trait and uses the session key to:

1. Derive a client-to-server and server-to-client encryption key via HKDF-SHA256.
2. Use ChaCha20-Poly1305 for record-layer encryption of all QUIC packets.
3. Authenticate the opening handshake with a MAC over the protocol version and session ID.

> **Security Note:** The custom `crypto::Session` approach described here is an architectural placeholder. The final implementation — including the exact mechanism for integrating the BLE-derived session key with Quinn's transport layer — is subject to security review during the Rust implementation phase. The project prefers established, audited cryptographic primitives in all cases. No transport security decision documented here is final until it has been independently reviewed.

---

## Session Hello Message

After the QUIC connection is established at the transport layer, both peers exchange a **Session Hello** message on the first bidirectional QUIC stream to confirm application-layer compatibility.

```
Session Hello frame layout:

 ┌──────────┬─────────────┬──────────────┬──────────────────────────────┐
 │ Magic    │ Proto       │ Capabilities │ Device Name                  │
 │ (4 bytes)│ Version     │ Flags        │ (length-prefixed UTF-8)      │
 │          │ (2 bytes)   │ (4 bytes)    │                              │
 └──────────┴─────────────┴──────────────┴──────────────────────────────┘

Magic:         0x45 0x53 0x59 0x4E  ("ESYN")
Proto Version: 0x0001  (current)
Capability Flags (bit field):
  Bit 0: SEND_FILES
  Bit 1: RECEIVE_FILES
  Bit 2: MULTI_FILE_BATCH
  Bit 3–31: Reserved (must be zero)
```

Both peers send their Hello immediately after QUIC handshake. If the proto versions are incompatible, the session is rejected with a QUIC application error code and an error event is streamed to Flutter.

---

## Session State Machine

```
         ┌──────────┐
         │  IDLE    │ ← initial state, no peer selected
         └────┬─────┘
              │ user selects peer + pairing begins
         ┌────▼─────┐
         │ PAIRING  │ ← BLE GATT handshake in progress
         └────┬─────┘
              │ session key derived + ENDPOINT received
         ┌────▼──────────┐
         │ CONNECTING    │ ← QUIC handshake in progress
         └────┬──────────┘
              │ QUIC connected + Hello exchanged
         ┌────▼──────────┐
         │ ESTABLISHED   │ ← ready for file transfer
         └────┬──────────┘
              │ user initiates transfer
         ┌────▼──────────┐
         │ TRANSFERRING  │ ← file transfer in progress
         └────┬──────────┘
              │ transfer complete / user disconnects
         ┌────▼──────────┐
         │ CLOSED        │ ← terminal state; session discarded
         └───────────────┘

Error transitions: any state → CLOSED on unrecoverable error
```

State transitions are owned by `session::state`. The current state is surfaced to Flutter via the bridge event stream as a `SessionStatusEvent`.

---

## Sequence

```
Initiator Rust Core                          Responder Rust Core
      │                                             │
      │  [session key held from pairing]            │  [session key held from pairing]
      │                                             │
      │                                             │  [bind QUIC listener on random port]
      │                                             │  [emit ENDPOINT address → Flutter → GATT → Initiator]
      │                                             │
      │  [receive ENDPOINT from Flutter]            │
      │  [create QUIC endpoint (client)]            │
      │── QUIC Initial (custom crypto) ────────────►│
      │◄── QUIC Handshake Done ─────────────────────│
      │                                             │
      │── Session Hello ────────────────────────────►│
      │◄── Session Hello ───────────────────────────│
      │                                             │
      │  [validate versions + capabilities]         │  [validate versions + capabilities]
      │                                             │
      │  [state → ESTABLISHED]                      │  [state → ESTABLISHED]
      │  [emit SessionStatusEvent → Flutter]        │  [emit SessionStatusEvent → Flutter]
      │                                             │
      │  [→ Transfer Protocol begins]               │
```

---

## Security Considerations

- **Session keys never leave Rust.** Flutter is notified of session state transitions (`ESTABLISHED`, `CLOSED`, etc.) but receives no key material at any point.
- **Session keys are not persisted.** On CLOSED, the session object and all associated key material are dropped. Rust's ownership model ensures keys are zeroed at deallocation (using `zeroize` for sensitive types).
- **Capability negotiation prevents feature exploitation.** A peer advertising capabilities it does not implement will fail the Hello exchange cleanly.
- **QUIC path validation.** Quinn performs source address validation on the QUIC handshake, providing protection against off-path packet injection.
- **Session is not resumable.** There is no 0-RTT or session resumption. Every new pairing produces a fresh session.

---

## Future Extensions

| Extension | Notes |
|-----------|-------|
| Multi-session (concurrent peers) | Allow simultaneous connections to multiple peers; requires session multiplexing in `session::manager` |
| Session resumption with trusted peer fingerprint | If trusted-peer persistence is added, allow skipping re-pairing for recently trusted peers |
| Capability negotiation v2 | Add negotiated chunk size, compression, and priority flags |
| Transport fallback | If QUIC is unavailable (firewall), fall back to TCP with TLS using the same session key |
