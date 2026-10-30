import type { Request } from 'express';
import { authError } from '../identity/auth-error.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
export { OpsSessionGuard } from '../identity/access-auth.guard.js';

export function currentActorFromRequest(req: Request): RequestActor {
  const actor = (req as Request & { actor?: RequestActor }).actor;
  if (!actor) throw authError(401, 'UNAUTHORIZED', 'Authentication required');
  return actor;
}
