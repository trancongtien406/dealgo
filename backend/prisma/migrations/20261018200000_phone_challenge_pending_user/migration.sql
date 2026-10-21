-- Phone OTP no longer creates a user before the code is verified.
-- Challenges for unknown phones keep userId NULL; existing rows are unchanged.
ALTER TABLE "phone_challenges" ALTER COLUMN "userId" DROP NOT NULL;
