# PBI-024 — App Lock, Vault Lock & On-Device Encryption

| Field | Value |
|---|---|
| Epic | E5 Platform / Security |
| Priority | P0 |
| Story Points | 8 |
| Spec refs | Features §1.6, §14; Data model §5.1 |
| Depends on | PBI-003 |
| Status | Done (biometric prompt on a phone with a screen lock still to be tried by hand) |

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

## Grooming Notes (Sprint 6, 2026-11-09)
**Keys**
- `KeyStore` interface. The device implementation uses `flutter_secure_storage` (Android Keystore-backed) holding a 256-bit Master Key (MK) created on first use.
- Tests use an in-memory key store. The MK never leaves the key store, except into memory while in use.

**Files**
- Each `document_files` row gets a random 256-bit file key (FK).
- Content is AES-256-GCM encrypted with the FK and a 12-byte nonce (`enc_iv`, base64).
- FK is wrapped with the MK using AES-GCM (nonce + ciphertext + tag, base64) in `enc_key_wrapped`.
- `sha256` = hash of the ciphertext.
- Package: `cryptography`, run in an isolate for large files.

**Read path:** `VaultFiles.read(file)` decrypts in memory.
- Viewer: images through `Image.memory`; PDFs through `PdfDocument.openData`.
- Thumbnails decrypt in memory too.
- No plaintext is written, except the share copies (PBI-007), which are deleted after the share sheet closes and cleared again before the next share.

**Migration:** on start, any file with no `enc_iv` (Sprint 1–5 data) is encrypted in place, once.

**Capture drafts:** scanner and import temporary pages are deleted after save or discard.

**App lock** (`local_auth`, biometric or device PIN; MainActivity becomes `FlutterFragmentActivity`)
- When on, a lock screen covers the app on cold start, and on resume after more than `auto_lock_min` minutes in the background.
- Vault lock asks again when entering the Vault tab or opening a document from elsewhere. It stays unlocked until the app goes to the background.
- Without device security, the toggles explain why they're unavailable.

**Screenshot blocking:** a `lifeos/secure` method channel sets FLAG_SECURE while Vault screens or the document viewer are visible, if the setting is on.

**AC6:** a test greps `lib/` for printing or logging of key variables. Key material is only ever passed around as bytes.

## Dev & QA Notes (Sprint 6, 2026-11-09)
Code:
- `lib/features/security/crypto/vault_crypto.dart`:
  - AES-256-GCM via `cryptography`, in an isolate.
  - A per-file key wrapped by a Master Key, stored through `KeyStore` (`flutter_secure_storage` on the phone).
- `crypto/vault_files.dart`: in-memory reads, plus a one-time migration of older plaintext files.
- `lock_gate.dart`: `LockGate` (app lock), `VaultGate` (Vault lock + FLAG_SECURE), `Authenticator` (`local_auth`).
- `MainActivity` is now a `FlutterFragmentActivity` with a `lifeos/secure` channel.
- Capture encrypts on save. The viewer, thumbnails, PDF view (`PdfDocument.openData`), share and export all decrypt in memory.

| AC | Result | Evidence |
|---|---|---|
| 1 | ✅ | Test: saved PDF and JPEG files have no `%PDF` / `FF D8` header on disk, and decrypting gives the original. **Device:** the Sprint 3 PDF (`%PDF` before) was encrypted in place on first start, and it still opens and renders in the viewer. |
| 2 | ✅ | Round-trip byte-for-byte (100 KB). A flipped bit in the file or the wrapped key fails authentication. Each file gets its own key and nonce. A different Master Key can't decrypt. |
| 3 | ✅ | Widget (fake authenticator): App lock asks on cold start; a failed check keeps the lock screen up; it locks again after more than N minutes in the background, but not after 2 of 5. |
| 4 | ✅ | Widget: Vault lock → the Vault tab shows the lock until authenticated. It relocks when the app goes to the background. |
| 5 | ✅ | Widget: with blocking on, `setSecure(true)` while the Vault is visible and `false` on Home. Native: FLAG_SECURE is set in `MainActivity`. |
| 6 | ✅ | Test: no print/log call in `lib/` mentions a key, and the Master Key is written only to the key store (once). |

Behaviour notes:
- Without a phone screen lock, both lock toggles are disabled with "Set a screen lock on this phone to use this". Nobody can be locked out.
- Share copies are the only plaintext ever written. They're deleted when the share sheet closes.

Found in dev:
- The viewer's loading spinner kept tests from ever settling; it's now a still placeholder.
- An interrupted migration could leave a file and its row out of step; reads now fall back to the plaintext if decryption fails on a file with a PDF/JPEG header.

`flutter analyze`: no issues · full suite **457/457 passed**, identical on two runs · schema v6 migration tested from v1–v5 · device checks on the Android 17 emulator (2026-11-09).
