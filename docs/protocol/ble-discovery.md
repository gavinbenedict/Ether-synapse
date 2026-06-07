# BLE Discovery Protocol

> Protocol Version: 1.0 · Status: Draft

---

## Purpose

The BLE Discovery Protocol defines how Ether Synapse devices find each other on the local radio environment without any prior knowledge of each other's network addresses, Wi-Fi credentials, or user accounts.

BLE is chosen exclusively for discovery because it:

- Works independently of Wi-Fi network topology (no router, no DHCP, no LAN subnet required).
- Has a well-defined, cross-platform advertising model available on all five target platforms.
- Provides a tight, low-power signal radius appropriate for proximity-based pairing.

**BLE is never used to transfer file data.** Discovery ends when a peer device is found and identified. All subsequent data flow moves to the Wi-Fi transport layer.

---

## Responsibilities

| Responsibility | Owner |
|----------------|-------|
| Advertising device presence | BLE Advertiser (Flutter platform channel) |
| Scanning for nearby peers | BLE Scanner (Flutter platform channel) |
| Filtering advertisements by service UUID | BLE Scanner |
| Presenting discovered peers to the user | Discovery feature, Flutter presentation layer |
| Storing discovered peer metadata | Discovery domain, Dart |
| Terminating scan after peer selection | Discovery feature, Flutter data layer |

mDNS advertisement and resolution is handled in the Rust `discovery` module (see `core/src/discovery/mdns.rs`) as a supplementary discovery mechanism for platforms where BLE scanning may be restricted or unavailable (principally desktop).

---

## Service Identity

All Ether Synapse devices advertise a fixed, project-assigned BLE service UUID.

```
Service UUID: Reserved. Assigned during implementation.
```

> The service UUID will be registered and assigned prior to the first public release. It must not be generated ad-hoc; the assigned value must be used consistently across all platform implementations.

Advertisement payload:

| Field | Value |
|-------|-------|
| Service UUID | Ether Synapse service UUID (above) |
| Local Name | Device display name (UTF-8, max 20 bytes, truncated) |
| Tx Power Level | Included (for proximity estimation) |

---

## Sequence

```
Advertiser (Device A)                      Scanner (Device B)
       │                                           │
       │  [Start advertising]                      │  [Start scanning for service UUID]
       │── BLE Advertisement ───────────────────────────────────────────────►│
       │                                           │
       │                                           │  [Filter: service UUID match]
       │                                           │  [Extract: device name, RSSI]
       │                                           │  [Add to peer list]
       │                                           │  [Emit PeerDiscovered event → UI]
       │                                           │
       │                              [User selects Device A from peer list]
       │                                           │
       │                                           │  [Stop scanning]
       │                                           │  [→ Pairing protocol begins]
```

Both devices may advertise and scan simultaneously. The device whose user initiates the connection becomes the **Initiator**; the other becomes the **Responder**.

---

## mDNS Supplement (Desktop Platforms)

On Windows, macOS, and Linux, mDNS service discovery is provided in addition to BLE. The Rust `discovery::mdns` module registers and resolves the following service type:

```
_ethersynapse._udp.local.
```

TXT record fields:

| Key | Value |
|-----|-------|
| `name` | Device display name (UTF-8) |
| `v` | Protocol version integer (`1`) |
| `id` | Ephemeral session identifier (random, per-boot, non-persistent) |

mDNS discovery requires the device to be on the same LAN subnet. It is not a fallback for BLE — both mechanisms may run concurrently, and the UI merges results into a single peer list, deduplicating by device name + identifier.

---

## Security Considerations

- **No authentication at this layer.** Discovery only reveals device name and the fact that a device is running Ether Synapse. No sensitive data is transmitted.
- **No persistent identity.** The advertised device name is user-configurable. The mDNS `id` field is re-randomised on every application start. Neither persists across sessions.
- **BLE range is a natural boundary.** Effective BLE range is approximately 10 metres in open space. This provides a physical proximity requirement for discovery, reducing the attack surface compared to internet-reachable services.
- **UUID filtering prevents accidental cross-app pairing.** Devices running other BLE applications will not appear in the Ether Synapse peer list.

---

## Future Extensions

| Extension | Notes |
|-----------|-------|
| RSSI-based proximity sorting | Sort peer list by signal strength to surface nearby devices first |
| Wi-Fi Direct peer discovery | Supplement BLE on Android where Wi-Fi Direct is available |
| QR code pairing | Allow pairing by scanning a QR code as an alternative to BLE discovery |
| NFC tap-to-pair | Single-tap NFC discovery as a supplementary channel on supported hardware |
