# PBI-028b — Share-Safe Expiring Links (Premium)

| Field | Value |
|---|---|
| Epic | E1 Vault / Cloud |
| Priority | P1 (Premium) |
| Story Points | 8 |
| Spec refs | Features §1.5 (links that auto-expire 1 h / 24 h / 7 d, optional PIN, revoke, "This document is no longer available", offline → share the file instead), §15 (Premium); Data model §3.2 `document_shares`, §5.3 (128-bit token, PIN rate limit, server-side view count), §6.2 `/documents/:id/share`, `DELETE /shares/:id`, `GET /share/:token` |
| Depends on | PBI-026a (account), PBI-026b (encrypted upload path and R2), PBI-028a (watermark, bundles, share history), PBI-029 (Premium) |
| Status | Ready (blocked by 026b) |

## User Story
As a **Premium user**, I want to send a link instead of a file, one that stops working after a day and can be protected with a PIN, so my CNIC doesn't sit forever in someone's WhatsApp, and I can switch it off if I sent it to the wrong person.

## Description

### Creating a link
- Share → **"Send a safe link"** (Premium; free users see it with the upgrade prompt, PBI-029).
- Works for a single document or a bundle (028a), optionally watermarked (028a). The shared copy is always a **flattened PDF**, never the Vault original.
- Options: **expires in** 1 hour / 24 hours (default) / 7 days; optional **4–6 digit PIN**; optional **view limit** (1, 3, 10).
- The phone encrypts the shared PDF with a **fresh random share key**, uploads the ciphertext, and builds the link `https://share.lifeos.app/s/{token}#k={shareKey}`.
  - The share key is in the URL **fragment**, which browsers never send to the server (data model §3.2 note). The server stores ciphertext it can't read, like the backup.
- The link goes through the normal share sheet, with a neutral message ("A document shared with you via LifeOS — expires {time}").

### Opening a link (recipient, no app needed)
- A small static web page at the share domain:
  - downloads the ciphertext and decrypts it **in the browser** with the key from the fragment;
  - shows the PDF in the browser with a "Download" button.
- A PIN, if set, is asked first. The server checks it (salted hash), limits attempts to 5 per hour per IP (§5.3), and counts views server-side.
- Expired, revoked, or view limit reached → "This document is no longer available" (EN/UR, chosen by the browser's language).
- The page has no tracking, no third-party scripts and no ads, and states "Encrypted end to end".

### Managing links (audit trail)
- The document's Details and Settings → Privacy → **Share history** (028a) show each link with status (active, expired, revoked), expiry time and view count. **Revoke** works in one tap.
- An expiry sweep (cron) deletes expired links' ciphertext from storage within 1 hour of expiry. Revoking deletes it immediately.
- Deleting the document or the account revokes all its links (026a).

### Offline
- With no connection, "Send a safe link" explains "No connection — share the file instead?". One tap falls back to the normal (or watermarked) file share. Per the spec, link creation is **not** silently queued, because a link that appears later is confusing to send.

## Acceptance Criteria
1. Creating a link uploads only ciphertext encrypted with a share key that never reaches the server. A test inspects every request. The key exists only in the URL fragment.
2. The recipient page decrypts and shows the exact PDF that was shared (byte-identical after decryption, in a headless-browser test).
3. The link stops working at its expiry (server test with clock control), after revoke (immediately), and after the view limit. Each shows "This document is no longer available".
4. PIN: the correct PIN opens it. After 5 wrong attempts from one IP within an hour, further attempts are refused until the hour passes. The PIN is stored only as a salted hash.
5. Expired and revoked links' ciphertext is gone from storage within 1 hour of expiry, or at once on revoke (storage check).
6. Share history shows every link with live status and view count, and revoke works from there and from the document.
7. Free users see the option with the upgrade prompt and can't create a link. Server-side, `/documents/:id/share` refuses a token without the Premium claim.
8. Offline: the user is offered the file share instead; nothing is queued.
9. The recipient page loads under 1 s on 4G (static, no third-party resources), works on current Chrome and Safari on phones, and is in EN and UR.

## Out of Scope
- Links that update when the document changes (a link is a snapshot).
- Recipient accounts, comments, or upload-back.
- Custom domains per user.

## Grooming Notes (2026-11-10)
- **Token:** 128-bit random, URL-safe base64. Stored hashed (SHA-256) on the server, so a database leak doesn't expose live links.
- **Crypto in the browser:** WebCrypto AES-GCM with the same file format as the app (nonce ‖ ciphertext ‖ tag), so one code path on the phone serves backup and share.
- **Hosting:** the static recipient page on Cloudflare Pages (same account as R2, 026b). The `GET /share/:token` and PIN check are an Edge Function. The domain (`share.lifeos.app` or similar) must be registered by the product owner.
- **Table:** `document_shares` as in the data model, plus `bundle` (jsonb of document ids, for bundles) and `token_hash` instead of `token`. The `share_events` local table (028a) gets `kind = link` rows with the link id, so history stays in one place.
- **Why not queue offline:** the spec offers two behaviours ("queue link creation, share file directly instead"). This PBI picks "share file directly" only. A queued link the user can't send yet adds a confusing pending state for little value. Flagged in case the product owner prefers queueing.
