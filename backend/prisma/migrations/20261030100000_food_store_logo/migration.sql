-- M030 (DEC-PROD-045): merchant store logo uploaded through the shared upload port.
ALTER TABLE "food_stores" ADD COLUMN "logoUrl" VARCHAR(400);
