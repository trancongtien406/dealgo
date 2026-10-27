-- Ops audit trail for ride vehicle class edits (fare parameters, seats, enable flag, image).
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'RIDE_VEHICLE_CLASS_UPDATE';
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'RIDE_VEHICLE_CLASS';
