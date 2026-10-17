-- CreateTable
CREATE TABLE "chat_threads" (
    "id" UUID NOT NULL,
    "rideId" UUID,
    "foodOrderId" UUID,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "chat_threads_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_messages" (
    "id" UUID NOT NULL,
    "threadId" UUID NOT NULL,
    "senderUserId" UUID NOT NULL,
    "body" VARCHAR(2000) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id")
);

-- Exactly one transaction context per thread (DEC-PROD-007).
ALTER TABLE "chat_threads"
ADD CONSTRAINT "chat_threads_one_context_check"
CHECK (
  ("rideId" IS NOT NULL AND "foodOrderId" IS NULL)
  OR ("rideId" IS NULL AND "foodOrderId" IS NOT NULL)
);

-- CreateIndex
CREATE UNIQUE INDEX "chat_threads_rideId_key" ON "chat_threads"("rideId");

-- CreateIndex
CREATE UNIQUE INDEX "chat_threads_foodOrderId_key" ON "chat_threads"("foodOrderId");

-- CreateIndex
CREATE INDEX "chat_messages_threadId_createdAt_idx" ON "chat_messages"("threadId", "createdAt");

-- CreateIndex
CREATE INDEX "rides_status_updatedAt_idx" ON "rides"("status", "updatedAt");

-- CreateIndex
CREATE INDEX "food_orders_status_updatedAt_idx" ON "food_orders"("status", "updatedAt");

-- AddForeignKey
ALTER TABLE "chat_threads" ADD CONSTRAINT "chat_threads_rideId_fkey" FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_threads" ADD CONSTRAINT "chat_threads_foodOrderId_fkey" FOREIGN KEY ("foodOrderId") REFERENCES "food_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_threadId_fkey" FOREIGN KEY ("threadId") REFERENCES "chat_threads"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_senderUserId_fkey" FOREIGN KEY ("senderUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
