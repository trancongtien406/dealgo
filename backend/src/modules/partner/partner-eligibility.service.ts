import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type AppEnv } from '../../platform/config/env.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import {
  PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS,
  PARTNER_REPOSITORY,
} from './partner.constants.js';
import { partnerError } from './partner.error.js';
import { shopPinFromMetadata } from './partner-shop-pin.js';
import {
  isCarVehicleClassCode,
  MOTORBIKE_CLASS_CODE,
  vehicleClassCodeFromMetadata,
} from '../ride-vehicle/ride-vehicle-class.js';
import type {
  PartnerApplicationRecord,
  PartnerRepository,
  PartnerRoleName,
} from './partner.repository.js';

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
    if (role === 'DRIVER') {
      this.assertCarExtraDocsIfRequired(application);
    }
  }

  /**
   * Class a driver may bid on (DG-DEC-VEH-001).
   * Fail closed: missing application, non-APPROVED (when bypass off), or missing /
   * unknown vehicleClassCode → null. Callers must skip listOpen / refuse offer.
   * Never silent-default to MOTORBIKE.
   */
  /**
   * FOOD is motorbike-only: offers, push/socket fan-out, the READY room and claim all ask
   * this. Fail closed: no application, not approved, unknown class, CAR_4/CAR_7 or any
   * other class → false.
   */
  async canDeliverFood(userId: string): Promise<boolean> {
    const code = await this.driverVehicleClassCode(userId).catch(() => null);
    return code === MOTORBIKE_CLASS_CODE;
  }

  async driverVehicleClassCode(userId: string): Promise<string | null> {
    const application = await this.partners.findByUserAndRole(userId, 'DRIVER');
    if (!application) {
      return null;
    }
    if (!this.bypassEnabled() && application.status !== 'APPROVED') {
      return null;
    }
    return vehicleClassCodeFromMetadata(application.metadata);
  }

  /** The pin from the merchant's KYB application, used to seed a store without coordinates. */
  async merchantShopPin(userId: string): Promise<{ lat: number; lng: number; label: string | null } | null> {
    const application = await this.partners.findByUserAndRole(userId, 'MERCHANT');
    return application ? shopPinFromMetadata(application.metadata) : null;
  }

  bypassEnabled(): boolean {
    const explicit = this.config.get('PARTNER_ELIGIBILITY_BYPASS', { infer: true });
    // t61u (DEC-PROD-070): never on by default — a local developer opts in with
    // PARTNER_ELIGIBILITY_BYPASS=true (rejected at boot in production).
    return explicit === true;
  }

  /**
   * OPEN-006 scaffold: fail closed for Car when gate is on and insurance missing.
   * Does not invent regulatory claims or vendor secrets.
   */
  carExtraDocsGateEnabled(): boolean {
    const explicit = this.config.get('PARTNER_CAR_KYC_EXTRA_DOCS', { infer: true });
    if (explicit !== undefined) {
      return explicit;
    }
    return this.config.get('NODE_ENV', { infer: true }) === 'production';
  }

  private assertCarExtraDocsIfRequired(application: PartnerApplicationRecord): void {
    if (!this.carExtraDocsGateEnabled()) {
      return;
    }
    const code = vehicleClassCodeFromMetadata(application.metadata);
    if (!code || !isCarVehicleClassCode(code)) {
      return;
    }
    const onFile = new Set(
      (application.documents ?? [])
        .map((doc) => doc.kind)
        .filter((kind): kind is string => typeof kind === 'string' && kind.length > 0),
    );
    const missing = PARTNER_DRIVER_CAR_EXTRA_DOCUMENTS.filter((kind) => !onFile.has(kind));
    if (missing.length > 0) {
      throw partnerError(
        403,
        'PARTNER_KYC_REQUIRED',
        `Car KYC documents required: ${missing.join(', ')}`,
      );
    }
  }
}
