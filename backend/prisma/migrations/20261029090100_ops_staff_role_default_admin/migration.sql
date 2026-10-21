ALTER TABLE "ops_credentials" ALTER COLUMN "staffRole" SET DEFAULT 'ADMIN';
UPDATE "ops_credentials" SET "staffRole" = 'ADMIN' WHERE "staffRole" = 'SUPPORT';
