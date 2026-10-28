-- Account deletion re-authentication with one of the user's own passkeys (DEC-PROD-037/052).
ALTER TYPE "AccountDeletionMethod" ADD VALUE 'PASSKEY';
