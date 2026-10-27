-- R19: ops audit actions for driver balance payments (gap 8) and merchant payouts (gap 15),
-- and STORE as an audited entity (gap 13 store location / gap 15 statements).
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'DRIVER_BALANCE_PAYMENT';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'MERCHANT_PAYOUT_RECORD';
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'STORE';
