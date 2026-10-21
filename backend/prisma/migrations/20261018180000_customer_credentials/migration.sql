-- CreateTable
CREATE TABLE "customer_credentials" (
    "userId" UUID NOT NULL,
    "passwordHash" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "customer_credentials_pkey" PRIMARY KEY ("userId")
);

-- AddForeignKey
ALTER TABLE "customer_credentials" ADD CONSTRAINT "customer_credentials_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
