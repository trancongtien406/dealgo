-- AlterTable
ALTER TABLE "food_stores" ADD COLUMN "lat" DOUBLE PRECISION,
ADD COLUMN "lng" DOUBLE PRECISION;

-- CreateEnum
CREATE TYPE "OpsAuditEntityType" AS ENUM ('RIDE', 'FOOD_ORDER');

-- CreateEnum
CREATE TYPE "OpsAuditAction" AS ENUM ('CANCEL', 'REASSIGN');

-- CreateTable
CREATE TABLE "driver_presence" (
    "userId" UUID NOT NULL,
    "online" BOOLEAN NOT NULL,
    "lat" DOUBLE PRECISION,
    "lng" DOUBLE PRECISION,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "driver_presence_pkey" PRIMARY KEY ("userId")
);

-- CreateTable
CREATE TABLE "ops_audit_logs" (
    "id" UUID NOT NULL,
    "actorUserId" UUID NOT NULL,
    "action" "OpsAuditAction" NOT NULL,
    "entityType" "OpsAuditEntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ops_audit_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "driver_presence_online_updatedAt_idx" ON "driver_presence"("online", "updatedAt");

-- CreateIndex
CREATE INDEX "ops_audit_logs_entityType_entityId_createdAt_idx" ON "ops_audit_logs"("entityType", "entityId", "createdAt");

-- CreateIndex
CREATE INDEX "ops_audit_logs_actorUserId_createdAt_idx" ON "ops_audit_logs"("actorUserId", "createdAt");

-- AddForeignKey
ALTER TABLE "driver_presence" ADD CONSTRAINT "driver_presence_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ops_audit_logs" ADD CONSTRAINT "ops_audit_logs_actorUserId_fkey" FOREIGN KEY ("actorUserId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
