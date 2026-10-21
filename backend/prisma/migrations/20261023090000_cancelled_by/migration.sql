-- DEC-PROD-035: record who cancelled a ride / food order.
-- CreateEnum
CREATE TYPE "CancelActor" AS ENUM ('CUSTOMER', 'DRIVER', 'MERCHANT', 'OPS', 'SYSTEM');

-- AlterTable
ALTER TABLE "food_orders" ADD COLUMN     "cancelledBy" "CancelActor";

-- AlterTable
ALTER TABLE "rides" ADD COLUMN     "cancelledBy" "CancelActor";

-- Backfill existing cancellations. Ops cancels are in the audit log; otherwise a ride
-- can only have been cancelled by its customer, and a food order by its customer
-- (no reason stored) or its merchant (reject stores cancelReasonCode).
UPDATE "rides" r SET "cancelledBy" = CASE
    WHEN EXISTS (
      SELECT 1 FROM "ops_audit_logs" a
      WHERE a."entityType" = 'RIDE' AND a."entityId" = r.id AND a.action = 'CANCEL'
    ) THEN 'OPS'::"CancelActor"
    ELSE 'CUSTOMER'::"CancelActor"
  END
WHERE r.status = 'CANCELLED';

UPDATE "food_orders" o SET "cancelledBy" = CASE
    WHEN EXISTS (
      SELECT 1 FROM "ops_audit_logs" a
      WHERE a."entityType" = 'FOOD_ORDER' AND a."entityId" = o.id AND a.action = 'CANCEL'
    ) THEN 'OPS'::"CancelActor"
    WHEN o."cancelReasonCode" IS NOT NULL THEN 'MERCHANT'::"CancelActor"
    ELSE 'CUSTOMER'::"CancelActor"
  END
WHERE o.status = 'CANCELLED';
