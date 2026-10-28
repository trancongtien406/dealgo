import { type CanActivate, type ExecutionContext, Injectable, SetMetadata } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import type { Request } from 'express';
import type { AuthMethodName } from './auth-method.constants.js';
import { AuthMethodPolicyService, authMethodUnavailable } from './auth-method-policy.service.js';

const AUTH_METHOD_KEY = 'dealgo:auth-method';

/** Marks a route as belonging to one sign-in method; AuthMethodEnabledGuard hides it while off. */
export const RequireAuthMethod = (method: AuthMethodName) => SetMetadata(AUTH_METHOD_KEY, method);

/**
 * Class-level guard on AuthController, so it runs before the throttlers, session guards and the
 * validation pipe: a disabled method's routes answer exactly like an unknown route (404
 * `Cannot POST /path`), count no rate-limit hits and never reach a service that sends SMS/email.
 */
@Injectable()
export class AuthMethodEnabledGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const method = this.reflector.get<AuthMethodName | undefined>(
      AUTH_METHOD_KEY,
      context.getHandler(),
    );
    if (!method || (await this.authMethods.isEnabled(method))) {
      return true;
    }
    const request = context.switchToHttp().getRequest<Request>();
    throw authMethodUnavailable(request.method, request.originalUrl || request.url);
  }
}
