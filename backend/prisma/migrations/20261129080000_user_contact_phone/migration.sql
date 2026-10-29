-- Contact number from profile completion (no OTP, not a sign-in identifier).
ALTER TABLE "users" ADD COLUMN "contactPhone" VARCHAR(16);
