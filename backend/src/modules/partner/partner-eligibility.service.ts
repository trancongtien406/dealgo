import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { PARTNER_REPOSITORY } from './partner.constants.js';
import { partnerError } from './partner.error.js';
import type { PartnerRepository, PartnerRoleName } from './partner.repository.js';

@Injectable()
export class PartnerEligibilityService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(PARTNER_REPOSITORY) private readonly partners: PartnerRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async requireEligibleDriver(userId: string): Promise<void> {
    await this.requireEligible(userId, 'DRIVER');
  }

  async requireEligible(userId: string, role: PartnerRoleName): Promise<void> {
    const grants = await this.identity.listGrants(userId);
    const active = grants.some((grant) => grant.role === role && grant.status === 'ACTIVE');
    if (!active) {
      throw partnerError(403, 'ROLE_NOT_ACTIVE', `An active ${role.toLowerCase()} role is required`);
    }
    if (this.bypassEnabled()) {
      return;
    }
    const application = await this.partners.findByUserAndRole(userId, role);
    if (!application || application.status !== 'APPROVED') {
      throw partnerError(
        403,
        'PARTNER_KYC_REQUIRED',
        `An approved ${role === 'DRIVER' ? 'KYC' : 'KYB'} application is required`,
      );
    }
  }

  bypassEnabled(): boolean {
    const explicit = this.config.get('PARTNER_ELIGIBILITY_BYPASS', { infer: true });
    if (explicit !== undefined) {
      return explicit;
    }
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    return nodeEnv !== 'production';
  }
}
