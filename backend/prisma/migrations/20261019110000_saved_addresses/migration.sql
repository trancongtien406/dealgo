-- Customer address book (saved addresses). Additive only; rules (limit 20, one HOME/WORK,
-- single default) are enforced in the service under a per-user row lock.
-- CreateEnum
CREATE TYPE "SavedAddressKind" AS ENUM ('HOME', 'WORK', 'OTHER');

-- CreateTable
CREATE TABLE "saved_addresses" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "kind" "SavedAddressKind" NOT NULL,
    "label" VARCHAR(60) NOT NULL,
    "addressLine" VARCHAR(300) NOT NULL,
    "note" VARCHAR(200),
    "lat" DOUBLE PRECISION,
    "lng" DOUBLE PRECISION,
    "isDefault" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "saved_addresses_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "saved_addresses_userId_createdAt_idx" ON "saved_addresses"("userId", "createdAt" DESC);

-- AddForeignKey
ALTER TABLE "saved_addresses" ADD CONSTRAINT "saved_addresses_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

