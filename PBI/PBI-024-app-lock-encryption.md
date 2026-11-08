# PBI-024 — App Lock, Vault Lock & On-Device Encryption

| Field | Value |
|---|---|
| Epic | E5 Platform / Security |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §1.6, §14; Data model §5.1 |
| Depends on | PBI-003 |
| Status | Ready |

## User Story
As a **user**, I want my documents unreadable to anyone who gets my phone or the cloud.

## Description
- App lock (biometric/PIN) and a separate optional Vault lock. Auto-lock after N minutes (default 5).
- Master Key (256-bit random) created on the device, wrapped by the Android Keystore / iOS Secure Enclave (`flutter_secure_storage`)
- A per-file key (FK) for each `document_files` row. Files are stored as AES-256-GCM ciphertext. FK is wrapped by the MK and stored in `enc_key_wrapped`, with the nonce in `enc_iv`.
- SHA-256 of the ciphertext is stored for integrity
- Optional screenshot blocking inside the Vault (Android FLAG_SECURE)
- Decrypt-on-open into memory only. No plaintext temp files are left on disk.

## Acceptance Criteria
1. Files on disk are never plaintext. The test reads raw bytes and asserts there is no PDF/JPEG header.
2. Encrypt → decrypt round-trips byte-for-byte. A tampered ciphertext fails authentication (tested).
3. With app lock on, the app asks for biometric/PIN on cold start and after N minutes in the background.
4. With Vault lock on, entering the Vault asks for authentication again.
5. When screenshot blocking is enabled, screenshots inside the Vault are blocked on Android.
6. No key material is ever logged or written outside secure storage.
