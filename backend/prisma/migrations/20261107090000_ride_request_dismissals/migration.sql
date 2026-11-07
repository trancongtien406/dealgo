CREATE TABLE "ride_request_dismissals" (
    "rideId" UUID NOT NULL,
    "driverId" UUID NOT NULL,
    "dismissedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ride_request_dismissals_pkey" PRIMARY KEY ("rideId", "driverId")
);

CREATE INDEX "ride_request_dismissals_driverId_dismissedAt_idx"
    ON "ride_request_dismissals"("driverId", "dismissedAt" DESC);

ALTER TABLE "ride_request_dismissals"
    ADD CONSTRAINT "ride_request_dismissals_rideId_fkey"
    FOREIGN KEY ("rideId") REFERENCES "rides"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ride_request_dismissals"
    ADD CONSTRAINT "ride_request_dismissals_driverId_fkey"
    FOREIGN KEY ("driverId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
