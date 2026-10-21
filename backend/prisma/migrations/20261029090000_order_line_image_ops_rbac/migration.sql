-- DEC-PROD-043: snapshot item image on order lines; ops staff role scopes.
ALTER TABLE "food_order_lines" ADD COLUMN "imageUrl" VARCHAR(400);

CREATE TYPE "OpsStaffRole" AS ENUM ('ADMIN', 'SUPPORT', 'OPERATIONS', 'FINANCE');

ALTER TABLE "ops_credentials" ADD COLUMN "staffRole" "OpsStaffRole" NOT NULL DEFAULT 'SUPPORT';

ALTER TYPE "OpsAuditAction" ADD VALUE 'OPS_STAFF_ROLE_ASSIGN';
