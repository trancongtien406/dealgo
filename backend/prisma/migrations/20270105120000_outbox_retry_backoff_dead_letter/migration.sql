-- REL-001: bounded outbox retries with backoff and a dead-letter state.
ALTER TABLE "outbox_messages" ADD COLUMN "nextAttemptAt" TIMESTAMP(3);
ALTER TABLE "outbox_messages" ADD COLUMN "deadLetteredAt" TIMESTAMP(3);
ALTER TABLE "outbox_messages" ADD COLUMN "lastError" TEXT;
CREATE INDEX "outbox_messages_deadLetteredAt_idx" ON "outbox_messages"("deadLetteredAt");
