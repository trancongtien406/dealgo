-- AlterTable
ALTER TABLE "sessions" ADD COLUMN "deviceId" VARCHAR(128);

-- CreateTable
CREATE TABLE "device_registrations" (
    "id" UUID NOT NULL,
    "deviceId" VARCHAR(128) NOT NULL,
    "userId" UUID NOT NULL,
    "ipAddress" VARCHAR(64),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "device_registrations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "device_registrations_deviceId_idx" ON "device_registrations"("deviceId");

-- CreateIndex
CREATE INDEX "device_registrations_userId_idx" ON "device_registrations"("userId");

-- CreateIndex
CREATE INDEX "sessions_deviceId_idx" ON "sessions"("deviceId");

-- AddForeignKey
ALTER TABLE "device_registrations" ADD CONSTRAINT "device_registrations_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

