export * from './identity.module.js';
export * from './identity.constants.js';
export * from './auth.controller.js';
export * from './auth.dto.js';
export * from './access-auth.guard.js';
export * from './phone-auth.service.js';
export * from './session.service.js';
export * from './passkey.service.js';
export * from './email-verification.service.js';
export * from './email-password-auth.service.js';
export * from './ops-auth.service.js';
export * from './role-grants.service.js';
export * from './identity.repository.js';
export * from './current-user.service.js';
export * from './driver-presence.service.js';

export { OpsPermissionGuard } from './ops-rbac/ops-permission.guard.js';
export { RequireOpsPermission } from './ops-rbac/ops-permission.decorator.js';
export { OPS_ROLE_PERMISSIONS, OPS_STAFF_ROLES, OPS_PERMISSIONS } from './ops-rbac/ops-permissions.js';
