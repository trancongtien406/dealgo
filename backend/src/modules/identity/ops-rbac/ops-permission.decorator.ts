import { SetMetadata } from '@nestjs/common';
import type { OpsPermission } from './ops-permissions.js';

export const OPS_PERMISSION_KEY = 'opsPermission';

/** Require one ops permission (superAdmin always passes). */
export const RequireOpsPermission = (permission: OpsPermission) =>
  SetMetadata(OPS_PERMISSION_KEY, permission);
