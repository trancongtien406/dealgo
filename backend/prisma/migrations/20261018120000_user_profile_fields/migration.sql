-- CreateEnum
CREATE TYPE "UserGender" AS ENUM ('MALE', 'FEMALE', 'OTHER');

-- AlterTable
ALTER TABLE "users" ADD COLUMN "dateOfBirth" TIMESTAMP(3),
ADD COLUMN "gender" "UserGender",
ADD COLUMN "avatarUrl" TEXT;
