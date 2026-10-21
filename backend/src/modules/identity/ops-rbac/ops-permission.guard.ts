import {
  CanActivate,
  ExecutionContext,
  Inject,
  Injectable,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { authError } from '../auth-error.js';
import { IDENTITY_REPOSITORY } from '../identity.constants.js';
import type { IdentityRepository } from '../identity.repository.js';
import { OpsSessionGuard, type RequestActor } from '../access-auth.guard.js';
import { OPS_PERMISSION_KEY } from './ops-permission.decorator.js';
import {
  isOpsStaffRole,
  roleHasPermission,
  type OpsPermission,
  type OpsStaffRoleName,
} from './ops-permissions.js';

type Authed = { actor?: RequestActor };

@Injectable()
export class OpsPermissionGuard implements CanActivate {
  constructor(
    private readonly opsSession: OpsSessionGuard,
    private readonly reflector: Reflector,
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    await this.opsSession.canActivate(context);
    const permission = this.reflector.getAllAndOverride<OpsPermission | undefined>(
      OPS_PERMISSION_KEY,
      [context.getHandler(), context.getClass()],
    );
    if (!permission) {
      return true;
    }
    const request = context.switchToHttp().getRequest<Authed>();
    const userId = request.actor?.userId;
    if (!userId) {
      throw authError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    const cred = await this.repository.findOpsCredential(userId);
    if (!cred) {
      throw authError(403, 'FORBIDDEN', 'Operator credential required');
    }
    if (cred.superAdmin) {
      return true;
    }
    const role: OpsStaffRoleName = isOpsStaffRole(cred.staffRole)
      ? cred.staffRole
      : 'SUPPORT';
    if (!roleHasPermission(role, permission)) {
      throw authError(403, 'OPS_PERMISSION_DENIED', `Missing permission: ${permission}`);
    }
    return true;
  }
}
