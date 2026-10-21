-- Email challenges can also activate an existing account whose email was never verified.
-- CreateEnum
CREATE TYPE "EmailChallengePurpose" AS ENUM ('SIGNUP', 'ACTIVATE_EXISTING');

-- AlterTable
ALTER TABLE "email_signup_challenges" ADD COLUMN     "purpose" "EmailChallengePurpose" NOT NULL DEFAULT 'SIGNUP',
ADD COLUMN     "userId" UUID;

-- AddForeignKey
ALTER TABLE "email_signup_challenges" ADD CONSTRAINT "email_signup_challenges_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

