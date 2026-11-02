import type { ExecutionContext } from '@nestjs/common';
import { AppVersionGuard } from './app-version.guard.js';
import type { AppVersionService } from './app-version.service.js';

function ctx(headers: Record<string, string>, url = '/v1/rides'): ExecutionContext {
  return {
    getType: () => 'http',
    switchToHttp: () => ({ getRequest: () => ({ headers, originalUrl: url }) }),
  } as unknown as ExecutionContext;
}

describe('AppVersionGuard (t82u)', () => {
  const versions = { blocks: async (_p: string, b: number) => b < 20 } as unknown as AppVersionService;
  const guard = new AppVersionGuard(versions);

  it('passes calls without app headers (web/admin/old builds)', async () => {
    await expect(guard.canActivate(ctx({}))).resolves.toBe(true);
  });

  it('rejects a blocked build with 426 APP_UPDATE_REQUIRED', async () => {
    await expect(guard.canActivate(ctx({ 'x-app-platform': 'ios', 'x-app-build': '19' }))).rejects.toMatchObject({
      status: 426,
      response: { errorCode: 'APP_UPDATE_REQUIRED' },
    });
  });

  it('lets a blocked build reach the policy endpoint', async () => {
    await expect(
      guard.canActivate(ctx({ 'x-app-platform': 'ios', 'x-app-build': '19' }, '/v1/app/version-policy?x=1')),
    ).resolves.toBe(true);
  });

  it('passes a current build', async () => {
    await expect(guard.canActivate(ctx({ 'x-app-platform': 'android', 'x-app-build': '25' }))).resolves.toBe(true);
  });
});
