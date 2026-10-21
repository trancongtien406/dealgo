-- Customer ratings for finished rides and delivered food orders (one per subject).
-- Stars are validated 1..5 in the API. Additive only.
-- CreateEnum
CREATE TYPE "RatingSubjectType" AS ENUM ('RIDE', 'FOOD_ORDER');

-- CreateTable
CREATE TABLE "service_ratings" (
    "id" UUID NOT NULL,
    "subjectType" "RatingSubjectType" NOT NULL,
    "subjectId" UUID NOT NULL,
    "raterId" UUID NOT NULL,
    "driverId" UUID,
    "storeId" UUID,
    "driverStars" SMALLINT,
    "storeStars" SMALLINT,
    "tags" VARCHAR(40)[],
    "comment" VARCHAR(500),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "service_ratings_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "service_ratings_driverId_createdAt_idx" ON "service_ratings"("driverId", "createdAt" DESC);

-- CreateIndex
CREATE INDEX "service_ratings_storeId_idx" ON "service_ratings"("storeId");

-- CreateIndex
CREATE UNIQUE INDEX "service_ratings_subjectType_subjectId_key" ON "service_ratings"("subjectType", "subjectId");

-- AddForeignKey
ALTER TABLE "service_ratings" ADD CONSTRAINT "service_ratings_raterId_fkey" FOREIGN KEY ("raterId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

