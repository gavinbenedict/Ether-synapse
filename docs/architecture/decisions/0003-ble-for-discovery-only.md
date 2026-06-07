# ADR 0003 — BLE Used Exclusively for Discovery and Pairing

**Status**: Accepted

**Date**: June 2026

---

## Context

Ether Synapse needs a mechanism for two devices to find each other and establish a shared secret without any pre-shared configuration, accounts, or internet connectivity. The mechanism must:

- Work when devices are not on the same Wi-Fi network (or before Wi-Fi connection details are known).
- Provide a natural proximity requirement to reduce the risk of accidental or malicious remote pairing.
- Be available on all five target platforms: Android, iOS, Windows, macOS, and Linux.
- Be suitable for transmitting small amounts of data (32-byte public keys, 1-byte confirmation).

Once discovery and pairing are complete, the mechanism must hand off to a higher-bandwidth transport for file transfer.

---

## Decision

**BLE (Bluetooth Low Energy) is used exclusively for:**
1. Advertising device presence.
2. Scanning for nearby peers.
3. Exchanging ephemeral public keys (GATT write/notify).
4. Communicating the QUIC listener endpoint address after pairing.
5. Confirming PIN verification.

**BLE is never used for file data transmission.**

File transfer occurs exclusively over QUIC on the Wi-Fi interface, using the session key established during the BLE pairing exchange.

mDNS is used as a supplementary discovery mechanism on desktop platforms where BLE scanning may be unavailable or restricted, but does not participate in pairing.

---

## Consequences

**Positive:**
- BLE proximity (~10 m range) is a natural security boundary. A remote attacker cannot participate in BLE pairing without being physically present.
- BLE is purpose-built for low-power, low-data-rate control signalling — exactly the use case here.
- The separation of concerns (BLE = control, Wi-Fi = data) allows each transport to operate at its optimum.
- BLE platform APIs are stable and well-documented on all five target platforms.
- Keeping BLE in the Flutter platform channel layer (not Rust) simplifies the Rust core and avoids the need for platform-specific BLE bindings in Rust.

**Negative:**
- The two-radio approach (BLE + Wi-Fi) means both must be enabled for the full feature to work on mobile. If BLE is unavailable, pairing is not possible (mDNS can still discover but cannot pair).
- BLE platform APIs differ significantly between Android, iOS, macOS, Windows, and Linux. Each platform runner requires its own BLE implementation.
- Windows BLE API (WinRT) requires Windows 10 build 1903 or later and has a smaller developer community than Android/iOS equivalents.

---

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|----------------|
| **Wi-Fi only (mDNS discovery + TCP pairing)** | Requires both devices on the same subnet; no natural proximity requirement; attacker on same LAN can attempt pairing |
| **QR code pairing only** | Requires camera permission and a scanning UI; less convenient as the primary flow; retained as a future extension |
| **NFC** | Not universally available on laptops/desktops; not available on macOS; retained as future extension for mobile |
| **BLE for data transfer** | BLE throughput (approximately 1–3 Mbps theoretical, far less in practice) is insufficient for large file transfers. Wi-Fi is 10–100× faster on a local network |
| **Wi-Fi Direct** | Not available on macOS or Linux without third-party drivers; inconsistent API across platforms |
