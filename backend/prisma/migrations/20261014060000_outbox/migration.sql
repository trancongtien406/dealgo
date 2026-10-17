-- CreateTable
CREATE TABLE "outbox_messages" (
    "id" UUID NOT NULL,
    "eventKey" VARCHAR(200) NOT NULL,
    "aggregateType" VARCHAR(64) NOT NULL,
    "aggregateId" UUID NOT NULL,
    "eventType" VARCHAR(120) NOT NULL,
    "payload" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processedAt" TIMESTAMP(3),
    "attempts" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "outbox_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "outbox_messages_eventKey_key" ON "outbox_messages"("eventKey");

-- CreateIndex
CREATE INDEX "outbox_messages_processedAt_createdAt_idx" ON "outbox_messages"("processedAt", "createdAt");
