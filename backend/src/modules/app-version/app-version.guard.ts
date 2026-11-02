import { type CanActivate, type ExecutionContext, HttpException, Injectable } from '@nestjs/common';
import { parseAppBuild, parseAppPlatform } from '../../platform/settings/index.js';
import { AppVersionService } from './app-version.service.js';

export const APP_UPDATE_REQUIRED = 'APP_UPDATE_REQUIRED';

/** Paths an outdated app must still reach (the policy itself, health, public pages). */
const EXEMPT = [/^\/v1\/app\//, /^\/health/, /^\/v1\/public\//, /^\/\.well-known\//];

/**
 * t82u: global guard. Apps send `X-App-Platform` + `X-App-Build`; when the build is below the
 * platform's minBuild (and enforceApi is on) the call fails with 426 APP_UPDATE_REQUIRED, which
 * the app maps to its blocking update screen. Calls without the headers (web, admin, old
 * builds) are untouched.
 */
@Injectable()
export class AppVersionGuard implements CanActivate {
  constructor(private readonly versions: AppVersionService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    if (context.getType() !== 'http') return true;
    const req = context.switchToHttp().getRequest<{ headers: Record<string, unknown>; url?: string; originalUrl?: string }>();
    const platform = parseAppPlatform(req.headers['x-app-platform']);
    const build = parseAppBuild(req.headers['x-app-build']);
    if (!platform || build === null) return true;
    const path = (req.originalUrl ?? req.url ?? '').split('?')[0] ?? '';
    if (EXEMPT.some((re) => re.test(path))) return true;
    if (await this.versions.blocks(platform, build)) {
      throw new HttpException(
        { message: 'This app version is no longer supported. Please update.', errorCode: APP_UPDATE_REQUIRED },
        426,
      );
    }
    return true;
  }
}
