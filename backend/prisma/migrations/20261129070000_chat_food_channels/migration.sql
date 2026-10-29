-- Food orders get two separate chat threads: customer↔driver (DRIVER) and
-- customer↔shop (MERCHANT). Existing food threads were customer↔driver only.
ALTER TABLE "chat_threads" ADD COLUMN "channel" VARCHAR(16) NOT NULL DEFAULT 'DRIVER';

ALTER TABLE "chat_threads"
ADD CONSTRAINT "chat_threads_channel_check"
CHECK ("channel" IN ('DRIVER', 'MERCHANT') AND ("channel" = 'DRIVER' OR "foodOrderId" IS NOT NULL));

DROP INDEX "chat_threads_foodOrderId_key";

CREATE UNIQUE INDEX "chat_threads_foodOrderId_channel_key" ON "chat_threads"("foodOrderId", "channel");
