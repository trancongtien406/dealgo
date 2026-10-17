-- Speeds ops overview directory COUNTs (CUSTOMER/DRIVER ACTIVE grants).
CREATE INDEX IF NOT EXISTS "role_grants_role_status_idx" ON "role_grants" ("role", "status");
