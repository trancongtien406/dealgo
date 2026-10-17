import { Inject, Injectable } from '@nestjs/common';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import type { IdentityRepository } from './identity.repository.js';

export type CurrentUserResult = {
  id: string;
  phone: string | null;
  email: string | null;
  phoneVerifiedAt: string | null;
  emailVerifiedAt: string | null;
  grants: Array<{ role: string; status: 'ACTIVE' }>;
};

@Injectable()
export class CurrentUserService {
  constructor(@Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository) {}

  async getProfile(userId: string): Promise<CurrentUserResult> {
    const user = await this.repository.findUserById(userId);
    if (!user) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    const grants = await this.repository.listGrants(userId);
    return {
      id: user.id,
      phone: user.phone,
      email: user.email,
      phoneVerifiedAt: user.phoneVerifiedAt?.toISOString() ?? null,
      emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
      grants: grants
        .filter((grant) => grant.status === 'ACTIVE')
        .map((grant) => ({ role: grant.role, status: 'ACTIVE' as const })),
    };
  }
}
