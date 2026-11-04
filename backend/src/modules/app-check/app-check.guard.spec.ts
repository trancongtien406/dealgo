import { describe, it, expect, vi, beforeEach } from 'vitest';
import type { ExecutionContext } from '@nestjs/common';
import { HttpException } from '@nestjs/common';
import { AppCheckGuard, APP_CHECK_FAILED } from './app-check.guard.js';
import { AppCheckService } from './app-check.service.js';
import type { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';

describe('AppCheckGuard', () => {
  let mockSettings: Partial<PlatformSettingsService>;
  let appCheckService: AppCheckService;
  let guard: AppCheckGuard;

  const createMockContext = (url: string, headers: Record<string, string | undefined>): ExecutionContext => {
    const req = {
      url,
      originalUrl: url,
      headers,
      ip: '127.0.0.1',
      socket: { remoteAddress: '127.0.0.1' },
    };
    return {
      getType: () => 'http',
      switchToHttp: () => ({
        getRequest: () => req,
      }),
    } as unknown as ExecutionContext;
  };

  beforeEach(() => {
    mockSettings = {
      getString: vi.fn(async (key: string) => {
        if (key === 'APP_CHECK_MODE') return 'ENFORCE';
        if (key === 'APP_CHECK_DEBUG_TOKENS') return 'test-debug-token,secret-debug';
        if (key === 'APP_CHECK_PROJECT_NUMBER') return '123456789';
        return '';
      }),
    };
    appCheckService = new AppCheckService(mockSettings as PlatformSettingsService);
    guard = new AppCheckGuard(appCheckService);
  });

  it('bypasses exempt paths such as /health and /docs', async () => {
    const ctxHealth = createMockContext('/health', {});
    const ctxDocs = createMockContext('/docs', {});
    const ctxOps = createMockContext('/v1/ops/login', {});

    expect(await guard.canActivate(ctxHealth)).toBe(true);
    expect(await guard.canActivate(ctxDocs)).toBe(true);
    expect(await guard.canActivate(ctxOps)).toBe(true);
  });

  it('allows request when APP_CHECK_MODE is OFF', async () => {
    mockSettings.getString = vi.fn(async () => 'OFF');
    const ctx = createMockContext('/v1/auth/phone/challenges', {});
    expect(await guard.canActivate(ctx)).toBe(true);
  });

  it('allows request in AUDIT mode even if token is missing', async () => {
    mockSettings.getString = vi.fn(async (key: string) => (key === 'APP_CHECK_MODE' ? 'AUDIT' : ''));
    const ctx = createMockContext('/v1/auth/phone/challenges', {});
    expect(await guard.canActivate(ctx)).toBe(true);
  });

  it('blocks request in ENFORCE mode when token is missing', async () => {
    const ctx = createMockContext('/v1/auth/phone/challenges', {});
    await expect(guard.canActivate(ctx)).rejects.toThrow(HttpException);
    try {
      await guard.canActivate(ctx);
    } catch (err) {
      const resp = (err as HttpException).getResponse() as { errorCode: string };
      expect(resp.errorCode).toBe(APP_CHECK_FAILED);
    }
  });

  it('allows valid debug token in ENFORCE mode', async () => {
    const ctx = createMockContext('/v1/auth/phone/challenges', {
      'x-firebase-appcheck': 'test-debug-token',
    });
    expect(await guard.canActivate(ctx)).toBe(true);
  });

  it('allows valid unexpired JWT token matching project number', async () => {
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({
        iss: 'https://firebaseappcheck.googleapis.com/123456789',
        sub: 'projects/123456789/apps/dealgo',
        exp: Math.floor(Date.now() / 1000) + 3600,
      }),
    ).toString('base64url');
    const token = `${header}.${payload}.mock-signature`;

    const ctx = createMockContext('/v1/auth/phone/challenges', {
      'x-firebase-appcheck': token,
    });
    expect(await guard.canActivate(ctx)).toBe(true);
  });

  it('blocks expired token in ENFORCE mode', async () => {
    const header = Buffer.from(JSON.stringify({ alg: 'RS256', typ: 'JWT' })).toString('base64url');
    const payload = Buffer.from(
      JSON.stringify({
        iss: 'https://firebaseappcheck.googleapis.com/123456789',
        sub: 'projects/123456789/apps/dealgo',
        exp: Math.floor(Date.now() / 1000) - 3600,
      }),
    ).toString('base64url');
    const token = `${header}.${payload}.mock-signature`;

    const ctx = createMockContext('/v1/auth/phone/challenges', {
      'x-firebase-appcheck': token,
    });
    await expect(guard.canActivate(ctx)).rejects.toThrow(HttpException);
  });
});
