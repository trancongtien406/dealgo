-- In-app voice calls (DEC-PROD-007): call state for customer ↔ assigned driver per trip.
CREATE TABLE "voice_calls" (
    "id" UUID NOT NULL,
    "aggregateType" VARCHAR(32) NOT NULL,
    "aggregateId" UUID NOT NULL,
    "roomName" VARCHAR(160) NOT NULL,
    "callerUserId" UUID NOT NULL,
    "calleeUserId" UUID NOT NULL,
    "callerRole" VARCHAR(16) NOT NULL,
    "status" VARCHAR(16) NOT NULL,
    "ringUntil" TIMESTAMP(3) NOT NULL,
    "answeredAt" TIMESTAMP(3),
    "endedAt" TIMESTAMP(3),
    "endReason" VARCHAR(32),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "voice_calls_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "voice_calls_aggregateType_aggregateId_createdAt_idx" ON "voice_calls"("aggregateType", "aggregateId", "createdAt");
CREATE INDEX "voice_calls_calleeUserId_createdAt_idx" ON "voice_calls"("calleeUserId", "createdAt");

-- At most one ringing or connected call per ride / food order.
CREATE UNIQUE INDEX "voice_calls_one_open_per_aggregate" ON "voice_calls"("aggregateType", "aggregateId") WHERE "status" IN ('RINGING', 'ACCEPTED');

-- Admin toggle for in-app calls (default on).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'VOICE_CALLS_ENABLED', 'true', 'json', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
