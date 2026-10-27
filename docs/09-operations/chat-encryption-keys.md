# Chat encryption keys — runbook

Approach (owner-approved, 2026-10-26): Grab/Uber-style TLS in transit + server-side encryption at rest, staff-reviewable. **No end-to-end encryption** (see OPEN item in `00-governance/decisions-and-assumptions.md`).

## What is encrypted
- `chat_messages.body_ciphertext` = base64(iv[12] | GCM tag[16] | ciphertext), AES-256-GCM (Node `crypto`), random IV per message.
- AAD = `chat:<threadId>:<messageId>` — a ciphertext cannot be moved to another row.
- `chat_messages.key_version` = key version used. `body` (plaintext) is `NULL` for encrypted rows; legacy rows keep `body` until backfilled.
- Code: `backend/src/modules/communication/chat/chat-cipher.ts`, `chat-prisma.repository.ts`. Decrypt only happens in the repository for participants that `ChatService` has authorised.
- Transport: API/Socket.IO over HTTPS/WSS; mobile release builds refuse `http://` base URLs (`assertSecureApiBaseUrl`), iOS ATS blocks cleartext.
- Push: a new message sends "Tin nhắn mới từ tài xế/khách" with the order code only — never the message text (see [push notifications](push/push-notifications.md)).
- Logs: backend never logs bodies; mobile debug Dio log redacts `body`.

## Env
| Var | Meaning |
|---|---|
| `CHAT_ENCRYPTION_KEY` | base64 of 32 random bytes. **Required when `NODE_ENV=production`** — the API refuses to start without it. |
| `CHAT_ENCRYPTION_KEY_VERSION` | integer, default 1. Bump on rotation. |
| `CHAT_ENCRYPTION_PREVIOUS_KEYS` | `1:<base64>,2:<base64>` old keys kept for decrypt only. |

Blank key outside production = messages stored plaintext (dev convenience only). An encrypted row read without the key fails closed (error, no content).

## Generate & store
1. `openssl rand -base64 32` on a trusted machine; do not paste into chat/tickets.
2. Store in the secret manager for the environment (prod/staging separately; never reuse dev keys). Back up the key: **losing it makes all chat history unreadable.**
3. Set `CHAT_ENCRYPTION_KEY` (+ `CHAT_ENCRYPTION_KEY_VERSION=1`) for both API and worker, deploy.

## Backfill legacy plaintext rows
```
cd backend
npm run chat:encrypt-backfill -- --dry-run      # counts only
npm run chat:encrypt-backfill                   # encrypts, sets body=NULL
```
Optional `--thread-id <uuid>` to scope. Prints counts only.

## Rotate
1. Generate new key. Set `CHAT_ENCRYPTION_PREVIOUS_KEYS=<oldVersion>:<oldKey>` (append to existing list), `CHAT_ENCRYPTION_KEY=<new>`, `CHAT_ENCRYPTION_KEY_VERSION=<old+1>`. Deploy API + worker.
2. New messages use the new version; old ones still decrypt.
3. Run `npm run chat:encrypt-backfill` to re-encrypt old-version rows (reported as `rotated`).
4. When `select count(*) from chat_messages where key_version <> <new>` is 0, remove the old key from `PREVIOUS_KEYS`.
Rotate on suspected compromise immediately; otherwise yearly (DRAFT cadence).

## Retention
DEC-PROD-056: the worker job `chat-retention` (every `CHAT_RETENTION_PURGE_INTERVAL_MS`, default 1 h) deletes chat messages older than the admin setting `CHAT_RETENTION_DAYS` (default 90, ASSUMED dispute/refund window), in batches of 5,000. Rows also cascade with their ride/order.

## Staff review (safety/disputes)
Content is staff-reviewable by design (the server holds the key). Staff with the `chat.review` permission can open the decrypted thread of one ride/order from the Admin ride, food-order or support-ticket page after typing a reason (`POST /v1/ops/chat-review`). Decryption happens on the server; every view is written to the ops audit log with the reason and optional ticket id.

## Changing the dev key
If `CHAT_ENCRYPTION_KEY` changes, keep the old key in `CHAT_ENCRYPTION_PREVIOUS_KEYS` (`<version>:<base64>`) and bump `CHAT_ENCRYPTION_KEY_VERSION`; old rows stay readable. Plaintext rows from before encryption can be converted with `scripts/chat-encrypt-backfill.ts`. On a throwaway dev database, deleting old dev chat rows is also fine.
