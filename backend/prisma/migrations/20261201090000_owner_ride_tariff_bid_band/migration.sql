-- Owner tariff (pure per-km): MOTORBIKE 5k/km min 10k, CAR_4 9k/km min 20k, CAR_7 13k/km min 25k.
-- Bids and counters stay within +/-30% of the app (reference) fare. All values remain Admin-editable.
UPDATE "ride_vehicle_classes"
SET "baseFareVnd" = 0, "perMinuteVnd" = 0, "perKmVnd" = 5000, "minFareVnd" = 10000, "updatedAt" = CURRENT_TIMESTAMP
WHERE "code" = 'MOTORBIKE';
UPDATE "ride_vehicle_classes"
SET "baseFareVnd" = 0, "perMinuteVnd" = 0, "perKmVnd" = 9000, "minFareVnd" = 20000, "updatedAt" = CURRENT_TIMESTAMP
WHERE "code" = 'CAR_4';
UPDATE "ride_vehicle_classes"
SET "baseFareVnd" = 0, "perMinuteVnd" = 0, "perKmVnd" = 13000, "minFareVnd" = 25000, "updatedAt" = CURRENT_TIMESTAMP
WHERE "code" = 'CAR_7';

INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_FARE_FLOOR_PERCENT_OF_REFERENCE', '70', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO UPDATE SET "value" = '70', "updatedAt" = CURRENT_TIMESTAMP;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_BID_CEILING_PERCENT_OF_REFERENCE', '130', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO UPDATE SET "value" = '130', "updatedAt" = CURRENT_TIMESTAMP;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_MIN_FARE_VND', '10000', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO UPDATE SET "value" = '10000', "updatedAt" = CURRENT_TIMESTAMP;
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt")
VALUES (gen_random_uuid(), 'RIDE_REFERENCE_VND_PER_KM', '5000', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO UPDATE SET "value" = '5000', "updatedAt" = CURRENT_TIMESTAMP;
