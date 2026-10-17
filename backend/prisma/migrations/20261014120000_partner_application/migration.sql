-- CreateEnum
CREATE TYPE "PartnerApplicationRole" AS ENUM ('DRIVER', 'MERCHANT');

-- CreateEnum
CREATE TYPE "PartnerApplicationStatus" AS ENUM ('DRAFT', 'SUBMITTED', 'APPROVED', 'REJECTED');

-- CreateTable
CREATE TABLE "partner_applications" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "role" "PartnerApplicationRole" NOT NULL,
    "status" "PartnerApplicationStatus" NOT NULL,
    "metadata" JSONB NOT NULL DEFAULT '{}',
    "documents" JSONB NOT NULL DEFAULT '[]',
    "reason" VARCHAR(500),
    "reviewedBy" UUID,
    "reviewedAt" TIMESTAMP(3),
    "submittedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "partner_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "partner_applications_status_submittedAt_idx" ON "partner_applications"("status", "submittedAt");

-- CreateIndex
CREATE UNIQUE INDEX "partner_applications_userId_role_key" ON "partner_applications"("userId", "role");

-- AddForeignKey
ALTER TABLE "partner_applications" ADD CONSTRAINT "partner_applications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "partner_applications" ADD CONSTRAINT "partner_applications_reviewedBy_fkey" FOREIGN KEY ("reviewedBy") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
