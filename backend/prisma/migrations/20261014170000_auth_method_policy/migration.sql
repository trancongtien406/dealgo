-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'AUTH_METHOD_POLICY';

-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'AUTH_METHOD_UPDATE';

-- CreateEnum
CREATE TYPE "AuthMethod" AS ENUM ('PASSKEY', 'PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER');

-- CreateTable
CREATE TABLE "auth_method_policies" (
    "id" UUID NOT NULL,
    "method" "AuthMethod" NOT NULL,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedByUserId" UUID,

    CONSTRAINT "auth_method_policies_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "auth_method_policies_method_key" ON "auth_method_policies"("method");

-- AddForeignKey
ALTER TABLE "auth_method_policies" ADD CONSTRAINT "auth_method_policies_updatedByUserId_fkey" FOREIGN KEY ("updatedByUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
