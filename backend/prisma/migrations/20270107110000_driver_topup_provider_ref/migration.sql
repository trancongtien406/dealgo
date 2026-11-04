-- Provider-side reference used by callbacks (payOS orderCode string, VNPAY vnp_TxnRef).
ALTER TABLE "driver_top_ups" ADD COLUMN "providerRef" VARCHAR(120);

CREATE UNIQUE INDEX "driver_top_ups_provider_providerRef_key"
  ON "driver_top_ups"("provider", "providerRef");

-- At most one payment link waiting for money per driver. Partial index: Prisma cannot
-- express it, so it lives in SQL and is enforced by the database.
CREATE UNIQUE INDEX "driver_top_ups_one_pending_per_driver"
  ON "driver_top_ups"("driverId") WHERE "status" = 'PENDING';
