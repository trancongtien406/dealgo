-- DEC-PROD-036: super-admin flag for Admin password resets + audit vocabulary.
-- The bootstrap operator (OPS_BOOTSTRAP_EMAIL) is flagged on API boot and by the seed.
-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'OPS_PASSWORD_RESET';
-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'OPS_STAFF';
-- AlterTable
ALTER TABLE "ops_credentials" ADD COLUMN     "superAdmin" BOOLEAN NOT NULL DEFAULT false;
