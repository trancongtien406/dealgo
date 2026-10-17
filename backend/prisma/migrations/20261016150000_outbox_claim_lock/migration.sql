-- Atomic outbox claim lock (ADR-003, FINDING-002)
-- Enables FOR UPDATE SKIP LOCKED batch claiming and lease timeouts across multiple worker instances.
ALTER TABLE "outbox_messages" ADD COLUMN IF NOT EXISTS "lockedAt" TIMESTAMP(3);

CREATE INDEX IF NOT EXISTS "outbox_messages_processedAt_lockedAt_idx" ON "outbox_messages"("processedAt", "lockedAt");
