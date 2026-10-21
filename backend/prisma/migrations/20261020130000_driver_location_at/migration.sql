-- DEC-PROD-031: when the driver last reported lat/lng (customer live tracking freshness).
ALTER TABLE "driver_presence" ADD COLUMN     "locationAt" TIMESTAMP(3);
