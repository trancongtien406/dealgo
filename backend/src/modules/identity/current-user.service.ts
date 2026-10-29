import { Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { EmailVerificationService } from './email-verification.service.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import type {
  IdentityRepository,
  UserGenderName,
  UserRecord,
} from './identity.repository.js';
import { normalizeEmail, normalizeVnMobile } from './phone-number.js';

/** Placeholder assigned at phone signup; treated as missing meaningful name. */
const DEFAULT_DISPLAY_NAMES = new Set(['dealgo user']);

export type CurrentUserResult = {
  id: string;
  phone: string | null;
  email: string | null;
  displayName: string;
  dateOfBirth: string | null;
  gender: UserGenderName | null;
  avatarUrl: string | null;
  phoneVerifiedAt: string | null;
  emailVerifiedAt: string | null;
  /** Unverified contact number (accounts without a verified phone). */
  contactPhone: string | null;
  needsProfileSetup: boolean;
  grants: Array<{ role: string; status: 'ACTIVE' }>;
};

export type UpdateMeInput = {
  displayName?: string;
  email?: string;
  contactPhone?: string | null;
  dateOfBirth?: string | null;
  gender?: UserGenderName | null;
};

export type UpdateMeResult = CurrentUserResult & {
  pendingEmailVerification?: { verificationId: string; expiresAt: string };
};

@Injectable()
export class CurrentUserService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly emailVerification: EmailVerificationService,
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() private readonly authMethods?: AuthMethodPolicyService,
  ) {}

  async getProfile(userId: string): Promise<CurrentUserResult> {
    const user = await this.requireUser(userId);
    return this.toResult(user);
  }

  async updateProfile(userId: string, input: UpdateMeInput): Promise<UpdateMeResult> {
    const before = await this.requireUser(userId);
    // Email is a sign-in method: while it is off, a new address is refused like an unknown
    // property, before any write and without a verification email. Re-sending the current
    // verified address (older app builds do) stays a no-op.
    if (
      input.email !== undefined &&
      !(before.email === normalizeEmail(input.email) && before.emailVerifiedAt !== null) &&
      this.authMethods &&
      !(await this.authMethods.isEnabled('EMAIL_LOGIN_IDENTIFIER'))
    ) {
      throw authError(400, 'VALIDATION_ERROR', 'property email should not exist');
    }

    const profilePatch: {
      displayName?: string;
      dateOfBirth?: Date | null;
      gender?: UserGenderName | null;
      contactPhone?: string | null;
    } = {};

    if (input.contactPhone !== undefined) {
      if (input.contactPhone === null) {
        profilePatch.contactPhone = null;
      } else {
        const phone = normalizeVnMobile(input.contactPhone);
        if (!phone) {
          throw authError(400, 'VALIDATION_ERROR', 'contactPhone must be a Vietnamese mobile number');
        }
        profilePatch.contactPhone = phone;
      }
    }

    if (input.displayName !== undefined) {
      const displayName = input.displayName.trim();
      if (!displayName) {
        throw authError(400, 'VALIDATION_ERROR', 'displayName must not be empty');
      }
      profilePatch.displayName = displayName;
    }

    if (input.dateOfBirth !== undefined) {
      if (input.dateOfBirth === null) {
        profilePatch.dateOfBirth = null;
      } else {
        const parsed = new Date(input.dateOfBirth);
        if (Number.isNaN(parsed.getTime())) {
          throw authError(400, 'VALIDATION_ERROR', 'dateOfBirth must be a valid ISO-8601 date');
        }
        profilePatch.dateOfBirth = parsed;
      }
    }

    if (input.gender !== undefined) {
      profilePatch.gender = input.gender;
    }

    if (Object.keys(profilePatch).length > 0) {
      await this.repository.updateUserProfile(userId, profilePatch);
    }

    let pendingEmailVerification: { verificationId: string; expiresAt: string } | undefined;
    if (input.email !== undefined) {
      const email = normalizeEmail(input.email);
      const current = await this.requireUser(userId);
      const alreadyVerified = current.email === email && current.emailVerifiedAt !== null;
      if (!alreadyVerified) {
        pendingEmailVerification = await this.emailVerification.request(userId, email);
      }
    }

    const profile = await this.getProfile(userId);
    return pendingEmailVerification ? { ...profile, pendingEmailVerification } : profile;
  }

  private async requireUser(userId: string): Promise<UserRecord> {
    const user = await this.repository.findUserById(userId);
    if (!user) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    return user;
  }

  private async toResult(user: UserRecord): Promise<CurrentUserResult> {
    const grants = await this.repository.listGrants(user.id);
    return {
      id: user.id,
      phone: user.phone,
      email: user.email,
      displayName: user.displayName,
      dateOfBirth: user.dateOfBirth?.toISOString() ?? null,
      gender: user.gender,
      avatarUrl: user.avatarUrl,
      phoneVerifiedAt: user.phoneVerifiedAt?.toISOString() ?? null,
      emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
      contactPhone: user.contactPhone ?? null,
      needsProfileSetup: needsProfileSetup(user.displayName) || !hasPhone(user),
      grants: grants
        .filter((grant) => grant.status === 'ACTIVE')
        .map((grant) => ({ role: grant.role, status: 'ACTIVE' as const })),
    };
  }
}

/**
 * Profile completion also asks for a phone number when the account has none
 * (email / passkey sign-up). A typed contact number is enough — no OTP.
 */
export function hasPhone(user: Pick<UserRecord, 'phone' | 'contactPhone'>): boolean {
  return Boolean(user.phone || user.contactPhone);
}

export function needsProfileSetup(displayName: string): boolean {
  const trimmed = displayName.trim();
  if (!trimmed) {
    return true;
  }
  return DEFAULT_DISPLAY_NAMES.has(trimmed.toLowerCase());
}

