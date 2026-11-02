-- Đà Nẵng (merged with former Quảng Nam since 2025): extend the DN bbox south/east to
-- cover Hội An (phố cổ, An Bàng, Cửa Đại) and Điện Bàn. Only touches the row while it
-- still has the bootstrap bbox, so an Admin-edited region is left alone.
UPDATE "service_regions"
SET "minLat" = 15.84, "maxLng" = 108.42, "updatedAt" = CURRENT_TIMESTAMP
WHERE "code" = 'DN' AND "minLat" = 15.95 AND "maxLng" = 108.35;
