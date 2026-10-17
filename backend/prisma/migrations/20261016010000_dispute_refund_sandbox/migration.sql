-- AlterEnum
ALTER TYPE "LedgerEntityType" ADD VALUE 'DISPUTE';
ALTER TYPE "LedgerJournalEvent" ADD VALUE 'SANDBOX_REFUND_RECORDED';

-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'DISPUTE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'DISPUTE_RESOLVE';

-- CreateEnum
CREATE TYPE "DisputeStatus" AS ENUM ('OPEN', 'AWAITING_RESPONSE', 'INVESTIGATING', 'RESOLVED', 'PENDING');
CREATE TYPE "DisputePriority" AS ENUM ('HIGH', 'MEDIUM', 'LOW');
CREATE TYPE "DisputeVerifyStatus" AS ENUM ('INVESTIGATING', 'RESOLVED', 'REJECTED', 'WAITING_MERCHANT');
CREATE TYPE "DisputeResolutionKind" AS ENUM ('PARTIAL_REFUND', 'FULL_REFUND', 'REJECTED', 'EVIDENCE_REQUESTED');
CREATE TYPE "RefundRequestStatus" AS ENUM ('PENDING', 'SANDBOX_RECORDED', 'REJECTED', 'CANCELLED');
CREATE TYPE "RefundRequestKind" AS ENUM ('PARTIAL', 'FULL');

-- CreateTable
CREATE TABLE "dispute_cases" (
    "id" UUID NOT NULL,
    "code" VARCHAR(32) NOT NULL,
    "type" VARCHAR(120) NOT NULL,
    "priority" "DisputePriority" NOT NULL,
    "status" "DisputeStatus" NOT NULL,
    "verifyStatus" "DisputeVerifyStatus" NOT NULL DEFAULT 'INVESTIGATING',
    "orderCode" VARCHAR(64) NOT NULL,
    "orderEntityType" "PaymentEntityType",
    "orderEntityId" UUID,
    "paymentId" VARCHAR(64) NOT NULL,
    "refundCode" VARCHAR(64) NOT NULL,
    "assignee" VARCHAR(120) NOT NULL,
    "slaRemaining" VARCHAR(32) NOT NULL DEFAULT '02:00:00',
    "reporterName" VARCHAR(160) NOT NULL,
    "summary" TEXT NOT NULL,
    "parties" JSONB NOT NULL DEFAULT '[]',
    "timeline" JSONB NOT NULL DEFAULT '[]',
    "messages" JSONB NOT NULL DEFAULT '[]',
    "checklist" JSONB NOT NULL DEFAULT '[]',
    "orderSnapshot" JSONB NOT NULL DEFAULT '{}',
    "resolution" "DisputeResolutionKind",
    "openedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "dispute_cases_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "refund_requests" (
    "id" UUID NOT NULL,
    "code" VARCHAR(32) NOT NULL,
    "disputeId" UUID NOT NULL,
    "kind" "RefundRequestKind" NOT NULL,
    "status" "RefundRequestStatus" NOT NULL DEFAULT 'PENDING',
    "amountVnd" INTEGER NOT NULL,
    "reason" VARCHAR(500) NOT NULL,
    "ledgerJournalId" UUID,
    "createdByUserId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "refund_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "dispute_cases_code_key" ON "dispute_cases"("code");
CREATE INDEX "dispute_cases_status_createdAt_idx" ON "dispute_cases"("status", "createdAt");
CREATE INDEX "dispute_cases_priority_createdAt_idx" ON "dispute_cases"("priority", "createdAt");
CREATE INDEX "dispute_cases_createdAt_idx" ON "dispute_cases"("createdAt");
CREATE UNIQUE INDEX "refund_requests_code_key" ON "refund_requests"("code");
CREATE INDEX "refund_requests_disputeId_createdAt_idx" ON "refund_requests"("disputeId", "createdAt");
CREATE INDEX "refund_requests_status_createdAt_idx" ON "refund_requests"("status", "createdAt");

-- AddForeignKey
ALTER TABLE "refund_requests" ADD CONSTRAINT "refund_requests_disputeId_fkey" FOREIGN KEY ("disputeId") REFERENCES "dispute_cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Sandbox refund chart of accounts
INSERT INTO "ledger_accounts" ("id", "code", "name", "kind", "createdAt")
VALUES
  ('a0000000-0000-4000-8000-000000000003', 'sandbox.refund.payable', 'Sandbox refund payable (ops stub)', 'LIABILITY', CURRENT_TIMESTAMP),
  ('a0000000-0000-4000-8000-000000000004', 'sandbox.refund.clearing', 'Sandbox refund clearing (ops stub)', 'ASSET', CURRENT_TIMESTAMP)
ON CONFLICT ("code") DO NOTHING;
