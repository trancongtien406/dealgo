import { HttpException, Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { type AppEnv } from '../../platform/config/env.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { missingCarExtraDocs, resolveCarExtraDocsGate } from './partner-car-docs-gate.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { PARTNER_REPOSITORY } from './partner.constants.js';
import { partnerError } from './partner.error.js';
import { shopPinFromMetadata } from './partner-shop-pin.js';
import {
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
    @Optional() private readonly settings?: PlatformSettingsService,
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
      await this.assertCarExtraDocsIfRequired(application);
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
    if (this.bypassEnabled()) {
      return vehicleClassCodeFromMetadata(application.metadata);
    }
    if (application.status !== 'APPROVED') {
      return null;
    }
    // t90u: a car driver missing the car documents (gate on) is not dispatchable — no
    // push/socket offer, no job detail, no bid — matching requireEligibleDriver.
    if ((await this.carDocsMissing(application)).length > 0) {
      return null;
    }
    return vehicleClassCodeFromMetadata(application.metadata);
  }

  /** t90u: single answer for "may this driver be offered / shown jobs?". */
  async driverDispatchEligible(userId: string): Promise<boolean> {
    return Boolean(await this.driverVehicleClassCode(userId).catch(() => null));
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

  /** t90u: admin setting DRIVER_CAR_EXTRA_DOCS_REQUIRED (env fallback without settings). */
  carExtraDocsGateEnabled(): Promise<boolean> {
    return resolveCarExtraDocsGate(this.settings, this.config);
  }

  private async carDocsMissing(application: PartnerApplicationRecord): Promise<string[]> {
    const missing = missingCarExtraDocs(application.metadata, application.documents);
    if (missing.length === 0 || !(await this.carExtraDocsGateEnabled())) {
      return [];
    }
    return missing;
  }

  private async assertCarExtraDocsIfRequired(application: PartnerApplicationRecord): Promise<void> {
    const missing = await this.carDocsMissing(application);
    if (missing.length > 0) {
      throw new HttpException(
        {
          message: `Car KYC documents required: ${missing.join(', ')}`,
          errorCode: 'PARTNER_KYC_REQUIRED',
          details: { reason: 'CAR_DOCS_REQUIRED', missing },
        },
        403,
      );
    }
  }
}
