-- Ops records the manual bank transfer that returns unused prepaid driver credit.
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'DRIVER_CREDIT_REFUND';
