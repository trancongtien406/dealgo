import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { IDENTITY_REPOSITORY } from './identity.constants.js';
import {
  UniqueConflictError,
  type GrantStatusName,
  type IdentityRepository,
  type RoleGrantRecord,
  type RoleName,
} from './identity.repository.js';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';

export type RequestableRole = Extract<RoleName, 'CUSTOMER' | 'DRIVER' | 'MERCHANT'>;

export type RoleGrantView = {
  id: string;
  role: RequestableRole | RoleName;
  status: GrantStatusName;
};

export type OpsRoleGrantView = RoleGrantView & {
  userId: string;
  displayName: string;
  phone: string | null;
  email: string | null;
  createdAt: string;
};

const REQUESTABLE_ROLES = new Set<RequestableRole>(['CUSTOMER', 'DRIVER', 'MERCHANT']);

@Injectable()
export class RoleGrantsService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly config: ConfigService<AppEnv, true>,
  ) {}

  async listMine(userId: string): Promise<{ grants: RoleGrantView[] }> {
    const grants = await this.repository.listGrants(userId);
    return {
      grants: grants.map((grant) => ({
        id: grant.id,
        role: grant.role,
        status: grant.status,
      })),
    };
  }

  async listForOps(
    status: string | undefined,
    page?: number,
    limit?: number,
  ): Promise<PageResult<OpsRoleGrantView>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const grantStatus = normalizeOpsGrantStatus(status);
    const result = await this.repository.listGrantsByStatus(
      grantStatus,
      safePage,
      safeLimit,
    );
    return {
      items: result.items.map((row) => ({
        id: row.id,
        role: row.role,
        status: row.status,
        userId: row.userId,
        displayName: row.displayName,
        phone: row.phone,
        email: row.email,
        createdAt: row.createdAt.toISOString(),
      })),
      page: safePage,
      limit: safeLimit,
      total: result.total,
    };
  }

  async requestRole(userId: string, role: string): Promise<RoleGrantView> {
    if (!isRequestableRole(role)) {
      throw authError(400, 'ROLE_GRANT_INVALID', 'Role cannot be requested');
    }

    const existing = (await this.repository.listGrants(userId)).find(
      (grant) => grant.role === role,
    );
    if (existing) {
      // Suspension (ops reject or enforcement) is lifted only by ops, never by re-requesting.
      if (existing.status === 'SUSPENDED') {
        throw authError(403, 'ROLE_GRANT_SUSPENDED', 'Role grant is suspended');
      }
      return viewOf(existing);
    }

    try {
      const created = await this.repository.insertGrant(userId, role, this.initialStatus());
      return viewOf(created);
    } catch (error) {
      if (!(error instanceof UniqueConflictError)) {
        throw error;
      }
      const raced = (await this.repository.listGrants(userId)).find(
        (grant) => grant.role === role,
      );
      if (!raced) {
        throw authError(409, 'ROLE_GRANT_CONFLICT', 'Role grant could not be created');
      }
      return viewOf(raced);
    }
  }

  async approve(grantId: string): Promise<RoleGrantView> {
    return this.reviewPending(grantId, 'ACTIVE');
  }

  async reject(grantId: string): Promise<RoleGrantView> {
    // Schema has no REJECTED; SUSPENDED is the stub terminal for ops denial.
    return this.reviewPending(grantId, 'SUSPENDED');
  }

  private async reviewPending(
    grantId: string,
    next: Extract<GrantStatusName, 'ACTIVE' | 'SUSPENDED'>,
  ): Promise<RoleGrantView> {
    const grant = await this.repository.findGrantById(grantId);
    if (!grant || !isRequestableRole(grant.role)) {
      throw authError(404, 'ROLE_GRANT_NOT_FOUND', 'Role grant was not found');
    }
    if (grant.status !== 'PENDING') {
      throw authError(409, 'ROLE_GRANT_NOT_PENDING', 'Only pending grants can be reviewed');
    }
    const updated = await this.repository.updateGrantStatus(grant.id, next);
    if (!updated) {
      throw authError(404, 'ROLE_GRANT_NOT_FOUND', 'Role grant was not found');
    }
    return viewOf(updated);
  }

  private initialStatus(): GrantStatusName {
    return this.sandboxAutoApprove() ? 'ACTIVE' : 'PENDING';
  }

  private sandboxAutoApprove(): boolean {
    const nodeEnv = this.config.get('NODE_ENV', { infer: true });
    return nodeEnv === 'development' || nodeEnv === 'test';
  }
}

function isRequestableRole(role: string): role is RequestableRole {
  return REQUESTABLE_ROLES.has(role as RequestableRole);
}

function viewOf(grant: RoleGrantRecord): RoleGrantView {
  return { id: grant.id, role: grant.role, status: grant.status };
}

function normalizeOpsGrantStatus(status: string | undefined): GrantStatusName {
  const raw = (status ?? 'PENDING').trim().toUpperCase();
  if (raw === 'ACTIVE' || raw === 'SUSPENDED' || raw === 'PENDING') {
    return raw;
  }
  return 'PENDING';
}
