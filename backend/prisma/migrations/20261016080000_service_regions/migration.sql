-- Admin-managed service zones (OPEN-001). Replaces the hard-coded TS catalog as source of truth.
-- Existing serviceRegionCode columns on rides/food_*/driver_presence keep working unchanged
-- (they already store these codes); rows here are never deleted, only set to PLANNED.
ALTER TYPE "OpsAuditEntityType" ADD VALUE IF NOT EXISTS 'SERVICE_REGION';
ALTER TYPE "OpsAuditAction" ADD VALUE IF NOT EXISTS 'SERVICE_REGION_UPDATE';

CREATE TYPE "ServiceRegionStatus" AS ENUM ('ACTIVE', 'PLANNED');

CREATE TABLE "service_regions" (
    "id" UUID NOT NULL,
    "code" VARCHAR(8) NOT NULL,
    "label" VARCHAR(80) NOT NULL,
    "centerLat" DOUBLE PRECISION NOT NULL,
    "centerLng" DOUBLE PRECISION NOT NULL,
    "minLat" DOUBLE PRECISION NOT NULL,
    "maxLat" DOUBLE PRECISION NOT NULL,
    "minLng" DOUBLE PRECISION NOT NULL,
    "maxLng" DOUBLE PRECISION NOT NULL,
    "status" "ServiceRegionStatus" NOT NULL DEFAULT 'PLANNED',
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "service_regions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "service_regions_code_key" ON "service_regions"("code");
CREATE INDEX "service_regions_status_sortOrder_idx" ON "service_regions"("status", "sortOrder");

-- Bootstrap with the former catalog (same codes, bbox and order).
INSERT INTO "service_regions"
  ("id", "code", "label", "centerLat", "centerLng", "minLat", "maxLat", "minLng", "maxLng", "status", "sortOrder", "updatedAt")
VALUES
  (gen_random_uuid(), 'DN',  'Đà Nẵng',         16.0544, 108.2022, 15.95, 16.22, 108.05, 108.35, 'ACTIVE',  0,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'HCM', 'TP. Hồ Chí Minh', 10.8231, 106.6297, 10.35, 11.15, 106.35, 107.05, 'ACTIVE',  1,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'HN',  'Hà Nội',          21.0285, 105.8542, 20.85, 21.25, 105.7,  106.1,  'ACTIVE',  2,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'HP',  'Hải Phòng',       20.8449, 106.6881, 20.7,  21.05, 106.5,  106.9,  'ACTIVE',  3,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'CT',  'Cần Thơ',         10.0452, 105.7469, 9.95,  10.2,  105.65, 105.9,  'PLANNED', 4,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'HUE', 'Huế',             16.4637, 107.5909, 16.35, 16.55, 107.45, 107.7,  'PLANNED', 5,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'NT',  'Nha Trang',       12.2388, 109.1967, 12.15, 12.35, 109.1,  109.3,  'PLANNED', 6,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'VT',  'Vũng Tàu',        10.346,  107.0843, 10.25, 10.45, 107.0,  107.2,  'PLANNED', 7,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DAD', 'Đà Lạt',          11.9404, 108.4583, 11.85, 12.05, 108.35, 108.55, 'PLANNED', 8,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'QNI', 'Quy Nhơn',        13.782,  109.2197, 13.7,  13.9,  109.1,  109.3,  'PLANNED', 9,  CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'BD',  'Bình Dương',      11.004,  106.659,  10.85, 11.25, 106.55, 106.85, 'PLANNED', 10, CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'DNA', 'Đồng Nai',        10.9574, 106.8426, 10.8,  11.15, 106.7,  107.1,  'PLANNED', 11, CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;

-- PILOT_ZONE_LABEL was a free-text duplicate of the zone list; the label is now derived from ACTIVE zones.
DELETE FROM "platform_settings" WHERE "key" = 'PILOT_ZONE_LABEL';
