import { Inject, Injectable } from '@nestjs/common';
import { PasswordHasher } from '../../platform/security/password-hasher.js';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import type { IdentityRepository } from './identity.repository.js';
import {
  OPS_PERMISSIONS,
  permissionsForRole,
  type OpsStaffRoleName,
} from './ops-rbac/ops-permissions.js';

export type OpsStaffSelf = {
  id: string;
  superAdmin: boolean;
  staffRole: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE' | null;
  permissions: string[];
};

/**
 * DEC-PROD-036: Admin password recovery. There is no self-service reset for ops
 * accounts; a super-admin sets a new password for another operator, which revokes
 * all of that operator's Admin sessions and is written to the ops audit log.
 */
@Injectable()
export class OpsStaffSecurityService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly passwords: PasswordHasher,
  ) {}

  async self(actorUserId: string): Promise<OpsStaffSelf> {
    const credential = await this.repository.findOpsCredential(actorUserId);
    if (!credential) {
      return { id: actorUserId, superAdmin: false, staffRole: null, permissions: [] };
    }
    const permissions = credential.superAdmin
      ? [...OPS_PERMISSIONS]
      : [...permissionsForRole(credential.staffRole)];
    return {
      id: actorUserId,
      superAdmin: credential.superAdmin === true,
      staffRole: credential.staffRole,
      permissions,
    };
  }

  async setStaffRole(input: {
    actorUserId: string;
    targetUserId: string;
    staffRole: OpsStaffRoleName;
    reason: string;
  }): Promise<{ userId: string; staffRole: OpsStaffRoleName }> {
    const actor = await this.repository.findOpsCredential(input.actorUserId);
    if (!actor?.superAdmin) {
      throw authError(403, 'OPS_SUPER_ADMIN_REQUIRED', 'Only a super-admin can assign staff roles');
    }
    const target = await this.repository.findOpsCredential(input.targetUserId);
    if (target?.superAdmin) {
      throw authError(400, 'OPS_SUPER_ADMIN_ROLE_CHANGE_FORBIDDEN', 'Cannot change role of super-admin');
    }
    const grants = await this.repository.listGrants(input.targetUserId);
    if (!grants.some((grant) => grant.role === 'OPS')) {
      throw authError(404, 'OPS_STAFF_NOT_FOUND', 'Ops staff member not found');
    }
    const result = await this.repository.setOpsStaffRole({
      targetUserId: input.targetUserId,
      staffRole: input.staffRole,
      actorUserId: input.actorUserId,
      reason: input.reason.trim(),
    });
    if (result === 'no_credential') {
      throw authError(409, 'OPS_NO_PASSWORD_LOGIN', 'This staff member has no Admin password login');
    }
    return { userId: input.targetUserId, staffRole: input.staffRole };
  }

  async resetPassword(input: {
    actorUserId: string;
    targetUserId: string;
    newPassword: string;
    reason: string;
  }): Promise<{ userId: string; sessionsRevoked: true }> {
    if (input.actorUserId === input.targetUserId) {
      throw authError(400, 'OPS_RESET_SELF', 'Use change password for your own account');
    }
    const actor = await this.repository.findOpsCredential(input.actorUserId);
    if (!actor?.superAdmin) {
      throw authError(403, 'OPS_SUPER_ADMIN_REQUIRED', 'Only a super-admin can reset passwords');
    }
    const grants = await this.repository.listGrants(input.targetUserId);
    if (!grants.some((grant) => grant.role === 'OPS')) {
      throw authError(404, 'OPS_STAFF_NOT_FOUND', 'Ops staff member not found');
    }
    const target = await this.repository.findOpsCredential(input.targetUserId);
    if (!target) {
      throw authError(409, 'OPS_NO_PASSWORD_LOGIN', 'This staff member has no Admin password login');
    }
    await this.repository.resetOpsPassword({
      targetUserId: input.targetUserId,
      passwordHash: await this.passwords.hash(input.newPassword),
      actorUserId: input.actorUserId,
      reason: input.reason.trim(),
      at: new Date(),
    });
    return { userId: input.targetUserId, sessionsRevoked: true };
  }

  /** Minimal super-admin management: grant the flag; super-admin cannot be revoked; audited. */
  async setSuperAdmin(input: {
    actorUserId: string;
    targetUserId: string;
    superAdmin: boolean;
    reason: string;
  }): Promise<{ userId: string; superAdmin: boolean }> {
    if (!input.superAdmin) {
      throw authError(400, 'OPS_SUPER_ADMIN_REVOKE_FORBIDDEN', 'Super-admin cannot be revoked');
    }
    const actor = await this.repository.findOpsCredential(input.actorUserId);
    if (!actor?.superAdmin) {
      throw authError(403, 'OPS_SUPER_ADMIN_REQUIRED', 'Only a super-admin can change super-admins');
    }
    const grants = await this.repository.listGrants(input.targetUserId);
    const opsGrant = grants.find((grant) => grant.role === 'OPS');
    if (!opsGrant) {
      throw authError(404, 'OPS_STAFF_NOT_FOUND', 'Ops staff member not found');
    }
    if (input.superAdmin && opsGrant.status !== 'ACTIVE') {
      throw authError(409, 'OPS_STAFF_NOT_ACTIVE', 'Only an active staff member can be super-admin');
    }
    const result = await this.repository.changeOpsSuperAdmin({
      targetUserId: input.targetUserId,
      superAdmin: input.superAdmin,
      actorUserId: input.actorUserId,
      reason: input.reason.trim(),
    });
    if (result === 'no_credential') {
      throw authError(409, 'OPS_NO_PASSWORD_LOGIN', 'This staff member has no Admin password login');
    }
    if (result === 'last') {
      throw authError(409, 'OPS_LAST_SUPER_ADMIN', 'At least one super-admin must remain');
    }
    return { userId: input.targetUserId, superAdmin: input.superAdmin };
  }
}
