-- CreateEnum
CREATE TYPE "LedgerAccountKind" AS ENUM ('ASSET', 'LIABILITY');

-- CreateEnum
CREATE TYPE "LedgerEntryDirection" AS ENUM ('DEBIT', 'CREDIT');

-- CreateEnum
CREATE TYPE "LedgerEntityType" AS ENUM ('RIDE', 'FOOD_ORDER');

-- CreateEnum
CREATE TYPE "LedgerJournalEvent" AS ENUM ('COD_OBLIGATION_POSTED');

-- CreateEnum
CREATE TYPE "LedgerJournalStatus" AS ENUM ('POSTED');

-- CreateTable
CREATE TABLE "ledger_accounts" (
    "id" UUID NOT NULL,
    "code" VARCHAR(80) NOT NULL,
    "name" VARCHAR(160) NOT NULL,
    "kind" "LedgerAccountKind" NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ledger_journals" (
    "id" UUID NOT NULL,
    "entityType" "LedgerEntityType" NOT NULL,
    "entityId" UUID NOT NULL,
    "event" "LedgerJournalEvent" NOT NULL,
    "status" "LedgerJournalStatus" NOT NULL DEFAULT 'POSTED',
    "currency" VARCHAR(3) NOT NULL DEFAULT 'VND',
    "amountVnd" INTEGER NOT NULL,
    "postedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_journals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ledger_entries" (
    "id" UUID NOT NULL,
    "journalId" UUID NOT NULL,
    "accountId" UUID NOT NULL,
    "direction" "LedgerEntryDirection" NOT NULL,
    "amountVnd" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ledger_accounts_code_key" ON "ledger_accounts"("code");

-- CreateIndex
CREATE INDEX "ledger_journals_entityType_entityId_idx" ON "ledger_journals"("entityType", "entityId");

-- CreateIndex
CREATE UNIQUE INDEX "ledger_journals_entityType_entityId_event_key" ON "ledger_journals"("entityType", "entityId", "event");

-- CreateIndex
CREATE INDEX "ledger_entries_journalId_idx" ON "ledger_entries"("journalId");

-- CreateIndex
CREATE INDEX "ledger_entries_accountId_idx" ON "ledger_entries"("accountId");

-- AddForeignKey
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_journalId_fkey" FOREIGN KEY ("journalId") REFERENCES "ledger_journals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "ledger_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Sandbox chart of accounts for COD obligation posting
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000001', 'sandbox.cod.cash_in_transit', 'Sandbox COD cash in transit (driver)', 'ASSET', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000002', 'sandbox.cod.obligation', 'Sandbox COD platform clearing obligation', 'LIABILITY', CURRENT_TIMESTAMP);
