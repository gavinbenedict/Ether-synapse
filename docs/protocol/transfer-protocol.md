# Transfer Protocol

> Protocol Version: 1.0 · Status: Draft

---

## Purpose

The Transfer Protocol defines how files are framed, encrypted, transmitted, and verified between two Ether Synapse peers over an established QUIC session. It runs on top of the Session Establishment Protocol and is implemented entirely in the Rust core (`core/src/transfer/`).

Flutter observes transfer progress via bridge event streams and controls transfer initiation (file selection, accept/reject), but performs no protocol logic, framing, encryption, or I/O.

---

## Responsibilities

| Responsibility | Owner |
|----------------|-------|
| File selection and path resolution | Flutter — file_picker package |
| Passing file path to Rust | Flutter → bridge (string path only) |
| File reading and chunking | **Rust — `transfer::sender`** |
| Manifest construction | **Rust — `transfer::manifest`** |
| Frame encryption | **Rust — `crypto::aead`** |
| QUIC stream management | **Rust — `transport::stream`** |
| Frame transmission | **Rust — `transfer::sender`** |
| Frame reception and decryption | **Rust — `transfer::receiver`** |
| File reassembly and write | **Rust — `transfer::receiver`** |
| Integrity verification | **Rust — `transfer::receiver`** + `crypto::hash` |
| Progress events to Flutter | **Rust** → bridge event stream → Flutter |
| Completion notification to user | Flutter presentation layer |

---

## Wire Format

All data transmitted over the QUIC stream is encrypted with ChaCha20-Poly1305 at the frame level before entering the QUIC transport. QUIC itself provides an additional encrypted transport layer (the custom session-key-derived QUIC crypto).

### Frame Structure

```
 Byte offset →   0        1        2        3        4        5
                 ┌────────┬────────┬────────┬────────┬────────── ─ ─ ┐
                 │ Frame  │        Payload Length    │  Payload       │
                 │ Type   │        (u32, big-endian) │  (variable)    │
                 └────────┴────────┴────────┴────────┴────────── ─ ─ ┘
                  1 byte            4 bytes            N bytes
```

The Payload field for each frame type carries the following after encryption:

### Frame Types

| Code | Name | Payload Contents |
|------|------|-----------------|
| `0x01` | `MANIFEST` | `name_len (u16)` · `name (UTF-8)` · `file_size (u64)` · `sha256 (32 bytes)` · `chunk_size (u32)` · `chunk_count (u32)` |
| `0x02` | `CHUNK` | `chunk_index (u32)` · `data (variable, ≤ chunk_size bytes)` |
| `0x03` | `FIN` | Empty payload. Signals end of file data. |
| `0x04` | `ABORT` | `reason_code (u16)` · `reason_msg (UTF-8, max 256 bytes)` |
| `0x05` | `ACK` | `chunk_index (u32)` · `status (u8: 0x00 = ok, 0x01 = error)` |
| `0x06` | `BATCH_MANIFEST` | `file_count (u16)` followed by `file_count` MANIFEST payloads |

### Nonce Construction

Each encrypted frame uses a unique 96-bit nonce:

```
nonce = direction (1 byte) || stream_id (3 bytes) || chunk_index (4 bytes) || padding (4 bytes, zero)

direction: 0x00 = sender → receiver
           0x01 = receiver → sender
stream_id: QUIC stream ID, truncated to 3 bytes
```

This construction guarantees nonce uniqueness across all frames in a session, even if both sides send simultaneously on different streams.

---

## Chunk Sizing

| Condition | Recommended Chunk Size |
|-----------|----------------------|
| Default (LAN Wi-Fi) | 64 KiB |
| Small file (< 256 KiB) | 32 KiB |
| Large file (> 1 GiB, high-throughput LAN) | 256 KiB |

Chunk size is negotiated in the MANIFEST frame. The sender proposes a chunk size; the receiver accepts by sending ACK on the first chunk. Chunk size is immutable for the duration of a single file transfer.

---

## Transfer Sequence

### Single File

```
Sender (Rust)                                        Receiver (Rust)
      │                                                      │
      │  [open unidirectional QUIC stream]                   │
      │── MANIFEST ─────────────────────────────────────────►│
      │                                                      │  [validate manifest]
      │                                                      │  [emit TransferOfferEvent → Flutter]
      │                                                      │  [wait for user accept]
      │◄── ACK (chunk_index=0, status=ok) ──────────────────│  [user accepted]
      │                                                      │
      │── CHUNK (index=0) ──────────────────────────────────►│
      │── CHUNK (index=1) ──────────────────────────────────►│
      │── CHUNK (index=N) ──────────────────────────────────►│  [streaming, no per-chunk ACK required]
      │── FIN ──────────────────────────────────────────────►│
      │                                                      │
      │                                                      │  [verify SHA-256 of assembled file]
      │◄── ACK (chunk_index=N, status=ok) ──────────────────│  [write to disk complete]
      │                                                      │
      │  [emit TransferCompleteEvent → Flutter]              │  [emit TransferCompleteEvent → Flutter]
```

### Batch Transfer (Multiple Files)

```
Sender (Rust)                                        Receiver (Rust)
      │
      │── BATCH_MANIFEST ───────────────────────────────────►│
      │◄── ACK (batch accepted) ────────────────────────────│
      │
      │  [For each file: open stream, send MANIFEST + CHUNKs + FIN]
      │  [Streams may be opened concurrently up to QUIC stream limit]
      │
      │── [stream 1] MANIFEST → CHUNKs → FIN ──────────────►│
      │── [stream 2] MANIFEST → CHUNKs → FIN ──────────────►│
      │◄── ACK (stream 1 complete) ─────────────────────────│
      │◄── ACK (stream 2 complete) ─────────────────────────│
```

---

## Progress Events

The Rust transfer engine emits the following event types to Flutter via the bridge stream:

| Event | Fields |
|-------|--------|
| `TransferOffer` | `peer_name`, `file_name`, `file_size`, `file_count` |
| `TransferProgress` | `file_name`, `bytes_sent`, `total_bytes`, `percent` |
| `TransferComplete` | `file_name`, `duration_ms`, `bytes_transferred` |
| `TransferError` | `file_name`, `error_code`, `reason` |
| `BatchProgress` | `files_complete`, `files_total`, `total_bytes_sent`, `total_bytes` |

---

## Integrity Verification

The receiver computes SHA-256 over the raw (decrypted) file bytes as chunks arrive. After FIN is received, the computed digest is compared to the SHA-256 included in the MANIFEST. If they do not match:

1. The file is deleted from disk.
2. A `TransferError` event with code `0x0010` (`INTEGRITY_FAILURE`) is emitted.
3. An ABORT frame is sent to the sender.

---

## Error and Abort Handling

| Scenario | Behaviour |
|----------|-----------|
| User cancels send | Rust closes the QUIC stream; ABORT frame sent; `TransferError` emitted to both sides |
| User rejects incoming file | ACK with `status=0x01` sent; Sender closes stream cleanly |
| Network interruption | QUIC handles path migration; if connection lost, session enters CLOSED state |
| Integrity check failure | File deleted; ABORT sent; error event emitted |
| Disk full on receiver | ABORT sent with code `0x0011` (`DISK_FULL`); error event emitted |

---

## Security Considerations

- **Double encryption.** Each frame is encrypted by ChaCha20-Poly1305 at the application layer before being handed to QUIC's own encrypted transport. An attacker who somehow breaks QUIC transport encryption would still face per-frame AEAD.
- **Integrity is mandatory.** SHA-256 verification is not optional and cannot be disabled. Files that fail verification are never delivered.
- **No metadata leakage.** File names are encrypted within the MANIFEST frame. The QUIC transport layer reveals only approximate transfer size (via packet count) to a passive local network observer.
- **Receive-side accept/reject.** The receiver explicitly accepts or rejects a file offer before the sender streams data. Files cannot be silently pushed to a device.

---

## Future Extensions

| Extension | Notes |
|-----------|-------|
| Transfer resumption | If a session is interrupted mid-transfer, allow resumption from the last acknowledged chunk using a persistent transfer manifest |
| Optional compression | Negotiate LZ4 or Zstandard compression in the MANIFEST frame for compressible content |
| Directory transfer | Add a `DIRECTORY_MANIFEST` frame type for recursive folder transfer |
| Transfer queue | Allow the sender to queue multiple batches without re-pairing |
| Bandwidth throttling | Add a negotiated transfer rate limit for background transfers |
