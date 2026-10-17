-- FCM device token registration for PushPort (ADR-006).
CREATE TABLE "push_device_tokens" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "token" VARCHAR(512) NOT NULL,
    "platform" VARCHAR(32) NOT NULL DEFAULT 'unknown',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "push_device_tokens_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "push_device_tokens_userId_token_key" ON "push_device_tokens"("userId", "token");
CREATE INDEX "push_device_tokens_userId_idx" ON "push_device_tokens"("userId");

ALTER TABLE "push_device_tokens" ADD CONSTRAINT "push_device_tokens_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
