-- Per-user in-app notification inbox fed by the outbox relay. Additive only.
-- CreateTable
CREATE TABLE "user_notifications" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "category" VARCHAR(24) NOT NULL,
    "title" VARCHAR(160) NOT NULL,
    "body" TEXT NOT NULL,
    "data" JSONB,
    "sourceEventKey" VARCHAR(200) NOT NULL,
    "readAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_notifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "user_notifications_userId_createdAt_idx" ON "user_notifications"("userId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "user_notifications_userId_readAt_idx" ON "user_notifications"("userId", "readAt");

-- CreateIndex
CREATE UNIQUE INDEX "user_notifications_userId_sourceEventKey_key" ON "user_notifications"("userId", "sourceEventKey");

-- AddForeignKey
ALTER TABLE "user_notifications" ADD CONSTRAINT "user_notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

