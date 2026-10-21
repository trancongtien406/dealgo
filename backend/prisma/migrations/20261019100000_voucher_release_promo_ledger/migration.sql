-- Round 3 (proposed decisions): voucher uses are released when a food order is cancelled,
-- and DealGo-funded discounts get their own expense account kind and journal event.
-- Additive only. Enum values are added here and used by the next migration, because
-- Postgres cannot use a new enum value in the transaction that added it.
-- AlterEnum
ALTER TYPE "LedgerAccountKind" ADD VALUE 'EXPENSE';

-- AlterEnum
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'PROMOTION_DISCOUNT_FUNDED';

-- AlterTable
ALTER TABLE "promotion_redemptions" ADD COLUMN     "releasedAt" TIMESTAMP(3);
