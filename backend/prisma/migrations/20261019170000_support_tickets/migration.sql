-- Help-center support tickets (S021–S023, public /support form).
-- CreateEnum
CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');

-- CreateEnum
CREATE TYPE "SupportTicketCategory" AS ENUM ('RIDE', 'FOOD', 'PAYMENT', 'ACCOUNT', 'SAFETY', 'OTHER');

-- CreateEnum
CREATE TYPE "SupportTicketPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');

-- CreateEnum
CREATE TYPE "SupportTicketChannel" AS ENUM ('APP', 'WEB');

-- CreateEnum
CREATE TYPE "SupportTicketRelatedType" AS ENUM ('RIDE', 'FOOD_ORDER');

-- CreateEnum
CREATE TYPE "SupportMessageAuthor" AS ENUM ('REQUESTER', 'STAFF');

-- AlterEnum
ALTER TYPE "OpsAuditAction" ADD VALUE 'SUPPORT_TICKET_UPDATE';

-- AlterEnum
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'SUPPORT_TICKET';

-- CreateTable
CREATE TABLE "support_tickets" (
    "id" UUID NOT NULL,
    "code" VARCHAR(20) NOT NULL,
    "channel" "SupportTicketChannel" NOT NULL,
    "requesterUserId" UUID,
    "requesterRole" VARCHAR(16) NOT NULL,
    "contactName" VARCHAR(80),
    "contact" VARCHAR(120),
    "category" "SupportTicketCategory" NOT NULL,
    "relatedType" "SupportTicketRelatedType",
    "relatedId" UUID,
    "externalRef" VARCHAR(50),
    "subject" VARCHAR(120) NOT NULL,
    "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
    "priority" "SupportTicketPriority" NOT NULL DEFAULT 'NORMAL',
    "lastMessageAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastAuthor" "SupportMessageAuthor" NOT NULL DEFAULT 'REQUESTER',
    "resolvedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "support_ticket_messages" (
    "id" UUID NOT NULL,
    "ticketId" UUID NOT NULL,
    "authorType" "SupportMessageAuthor" NOT NULL,
    "authorUserId" UUID,
    "body" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_ticket_messages_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "support_tickets_code_key" ON "support_tickets"("code");

-- CreateIndex
CREATE INDEX "support_tickets_requesterUserId_createdAt_idx" ON "support_tickets"("requesterUserId", "createdAt");

-- CreateIndex
CREATE INDEX "support_tickets_status_lastMessageAt_idx" ON "support_tickets"("status", "lastMessageAt");

-- CreateIndex
CREATE INDEX "support_tickets_contact_createdAt_idx" ON "support_tickets"("contact", "createdAt");

-- CreateIndex
CREATE INDEX "support_ticket_messages_ticketId_createdAt_idx" ON "support_ticket_messages"("ticketId", "createdAt");

-- AddForeignKey
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_requesterUserId_fkey" FOREIGN KEY ("requesterUserId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "support_ticket_messages" ADD CONSTRAINT "support_ticket_messages_ticketId_fkey" FOREIGN KEY ("ticketId") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- Support limits (Admin-editable settings).
INSERT INTO "platform_settings" ("id", "key", "value", "valueType", "updatedAt") VALUES
  (gen_random_uuid(), 'SUPPORT_TICKET_MAX_OPEN_PER_USER', '5', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY', '3', 'number', CURRENT_TIMESTAMP),
  (gen_random_uuid(), 'SUPPORT_TICKET_TEXT_MAX_CHARS', '2000', 'number', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;
