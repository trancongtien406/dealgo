import {
  UniqueConflictError,
  type IdentityRepository,
} from './identity.repository.js';

/**
 * Self sign-up (phone OTP or email+password) makes the account a customer in every
 * environment. An existing CUSTOMER grant is left untouched, so SUSPENDED stays SUSPENDED.
 */
export async function ensureActiveCustomerGrant(
  repository: IdentityRepository,
  userId: string,
): Promise<void> {
  const grants = await repository.listGrants(userId);
  if (grants.some((grant) => grant.role === 'CUSTOMER')) {
    return;
  }
  try {
    await repository.insertGrant(userId, 'CUSTOMER', 'ACTIVE');
  } catch (error) {
    if (!(error instanceof UniqueConflictError)) {
      throw error;
    }
  }
}
