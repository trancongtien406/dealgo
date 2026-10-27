-- DRAFT: chat at-rest encryption (AES-256-GCM, app-layer). Plaintext `body` becomes nullable;
-- run `npm run chat:encrypt-backfill` with CHAT_ENCRYPTION_KEY set to encrypt legacy rows.
ALTER TABLE "chat_messages" ALTER COLUMN "body" DROP NOT NULL;
ALTER TABLE "chat_messages" ADD COLUMN "body_ciphertext" TEXT;
ALTER TABLE "chat_messages" ADD COLUMN "key_version" INTEGER;
