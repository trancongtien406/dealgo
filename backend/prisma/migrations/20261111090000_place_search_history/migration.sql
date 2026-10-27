-- Per-user place search history (picked places only). Additive; the service
-- de-duplicates by placeKey and keeps the newest 20 rows per user.
-- CreateTable
CREATE TABLE "place_search_history" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "placeKey" VARCHAR(200) NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "address" VARCHAR(300) NOT NULL,
    "lat" DOUBLE PRECISION NOT NULL,
    "lng" DOUBLE PRECISION NOT NULL,
    "useCount" INTEGER NOT NULL DEFAULT 1,
    "lastUsedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "place_search_history_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "place_search_history_userId_placeKey_key" ON "place_search_history"("userId", "placeKey");

-- CreateIndex
CREATE INDEX "place_search_history_userId_lastUsedAt_idx" ON "place_search_history"("userId", "lastUsedAt" DESC);

-- AddForeignKey
ALTER TABLE "place_search_history" ADD CONSTRAINT "place_search_history_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
