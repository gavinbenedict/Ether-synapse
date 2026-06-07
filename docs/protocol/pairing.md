# Pairing Protocol

> Protocol Version: 1.0 · Status: Draft

---

## Purpose

The Pairing Protocol establishes a shared secret between two Ether Synapse devices, with out-of-band verification to protect against man-in-the-middle attacks. It runs over BLE GATT after a peer has been discovered and selected by the user. It produces a session key that is handed directly to the Rust core for use in the transport layer.

**The Flutter layer never holds, generates, or inspects cryptographic key material.** All key generation, key exchange computation, and session key derivation are performed inside the Rust core (`core/src/crypto/`). Flutter only receives opaque status events and the PIN value for display.

---

## Responsibilities

| Responsibility | Owner |
|----------------|-------|
| BLE GATT connection establishment | Flutter platform channel |
| Transmitting the local ephemeral public key over GATT | Flutter platform channel (passes opaque bytes from Rust) |
| Receiving the remote ephemeral public key over GATT | Flutter platform channel |
| Generating the ephemeral X25519 key pair | **Rust — `crypto::handshake`** |
| Computing the X25519 Diffie-Hellman shared secret | **Rust — `crypto::handshake`** |
| Deriving the session key via HKDF-SHA256 | **Rust — `crypto::handshake`** |
| Computing the PIN from the session key | **Rust — `crypto::handshake`** |
| Displaying the PIN to the user | Flutter presentation layer |
| Accepting or rejecting the PIN confirmation | User (physical, out-of-band) |
| Signalling confirmation over GATT | Flutter platform channel |
| Finalising the session in the Rust core | **Rust — `session::manager`** |

---

## GATT Profile

```
Service UUID: Reserved. Assigned during implementation.

├── Characteristic: PUBLIC_KEY      UUID: ...01
│     Properties:  Write Without Response, Notify
│     Description: Ephemeral X25519 public key (32 bytes)
│
├── Characteristic: PIN_DISPLAY     UUID: ...02
│     Properties:  Notify
│     Description: 4-byte value. PIN = big-endian u32 mod 1,000,000
│                  Displayed as a 6-digit zero-padded decimal on both screens.
│
├── Characteristic: CONFIRM         UUID: ...03
│     Properties:  Write Without Response
│     Description: 1-byte confirmation flag
│                  0x01 = user confirmed PIN match (pairing accepted)
│                  0x00 = user rejected PIN (pairing aborted)
│
└── Characteristic: ENDPOINT        UUID: ...04
      Properties:  Notify
      Description: Null-terminated UTF-8 string: "<IPv4>:<port>"
                   Sent by the Responder after CONFIRM is received.
                   Communicates the address of the QUIC listener.
```

---

## Key Derivation

All computations occur inside `core/src/crypto/handshake.rs`. Flutter receives only the outputs needed for display and BLE transmission.

```
Step 1 — Key generation (Rust):
  local_priv, local_pub  = X25519::generate_ephemeral()

Step 2 — Exchange (Flutter carries opaque bytes over GATT):
  → Send local_pub (32 bytes) to peer via PUBLIC_KEY characteristic
  ← Receive remote_pub (32 bytes) from peer via PUBLIC_KEY notification

Step 3 — Shared secret (Rust):
  raw_secret = X25519::diffie_hellman(local_priv, remote_pub)

Step 4 — Session key derivation (Rust):
  salt       = SHA256(local_pub || remote_pub)     ← lexicographically ordered by role
  session_key = HKDF-SHA256(
                  ikm  = raw_secret,
                  salt = salt,
                  info = b"ether-synapse-v1-session"
                )                                  → 32 bytes, never leaves Rust

Step 5 — PIN derivation (Rust, result surfaced to Flutter for display only):
  pin_bytes  = SHA256(session_key || b"ether-synapse-v1-pin")[0..4]
  pin_int    = big_endian_u32(pin_bytes) mod 1_000_000
  pin_string = format!("{:06}", pin_int)           → "042817" style

Step 6 — Out-of-band verification (user):
  Both devices independently compute and display the same PIN.
  User verbally or visually confirms the digits match.

Step 7 — Confirmation (Flutter → GATT → peer):
  Write 0x01 to CONFIRM characteristic if user accepts.
  Write 0x00 and abort if user rejects.
```

**The session key is stored exclusively in Rust memory and is never serialised, logged, or passed to Flutter.**

---

## Sequence

```
Initiator (Device A)                              Responder (Device B)
      │                                                    │
      │  [Rust: generate ephemeral key pair A]             │  [Rust: generate ephemeral key pair B]
      │                                                    │
      │── GATT Connect ───────────────────────────────────►│
      │── Write PUBLIC_KEY_A (32 bytes) ──────────────────►│
      │                                                    │  [Rust: store pub_A]
      │◄── Notify PUBLIC_KEY_B (32 bytes) ─────────────────│
      │  [Rust: store pub_B]                               │
      │                                                    │
      │  [Rust: compute X25519, derive session_key_A]      │  [Rust: compute X25519, derive session_key_B]
      │  [session_key_A == session_key_B by DH property]   │
      │                                                    │
      │  [Rust: compute pin_A]                             │  [Rust: compute pin_B]
      │  [Flutter: display pin_A]                          │  [Flutter: display pin_B]
      │                                                    │
      │  [User: verify pin_A == pin_B out-of-band]         │
      │                                                    │
      │── Write CONFIRM (0x01) ───────────────────────────►│
      │                                                    │
      │                                                    │  [Rust: session established]
      │                                                    │  [Rust: QUIC listener bound → get address]
      │◄── Notify ENDPOINT ("192.168.1.42:54321") ─────────│
      │                                                    │
      │  [Rust: open QUIC connection to endpoint]          │
      │  [→ Session Establishment Protocol begins]         │
```

---

## Security Considerations

- **Ephemeral keys only.** X25519 key pairs are generated fresh for every pairing and discarded after the session key is derived. There is no persistent device keypair.
- **Forward secrecy.** Because keys are ephemeral and never stored, past sessions cannot be decrypted even if the device is later compromised.
- **PIN length vs. attack window.** A 6-digit PIN has 10^6 possible values. BLE GATT is a proximity channel, so an attacker would need to be physically present. Pairing should time out after 60 seconds if not confirmed.
- **Confirmation binding.** The PIN binds the session key to the visual verification step. An attacker who intercepts the BLE exchange would compute a different session key, derive a different PIN, and fail the user's visual check.
- **Role-ordered salt.** The HKDF salt uses a lexicographically ordered concatenation of both public keys, ensuring both sides independently compute the same salt without needing to agree on a role-specific input ordering for this step.

---

## Future Extensions

| Extension | Notes |
|-----------|-------|
| Pairing persistence (trusted peers) | Store a BLAKE3 fingerprint of the session key (not the key itself) to recognise previously trusted devices without re-pairing |
| NFC pairing | Exchange public keys via NFC tap as an alternative to BLE GATT |
| QR pairing | Encode the local public key in a QR code; scanner reads it via camera |
| Biometric confirmation | Replace or supplement PIN display with a biometric-gated confirmation on supported hardware |
