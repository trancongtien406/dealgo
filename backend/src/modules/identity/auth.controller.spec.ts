import { describe, expect, it, vi } from 'vitest';
import { AuthController } from './auth.controller.js';

describe('AuthController listMethods', () => {
  it('serves the public (enabled-only) list, never the ops list', async () => {
    const mockAuthMethods = {
      list: vi.fn(),
      listPublic: vi.fn().mockResolvedValue([{ method: 'PASSKEY' }]),
    };

    const controller = new AuthController(
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      mockAuthMethods as any,
    );

    expect(await controller.listMethods()).toEqual([{ method: 'PASSKEY' }]);
    expect(mockAuthMethods.list).not.toHaveBeenCalled();
  });

  it('forwards deviceId and ip address when starting phone challenge', async () => {
    const mockPhoneAuth = {
      createChallenge: vi.fn().mockResolvedValue({ challengeId: 'c-1', expiresAt: '2026-11-05T00:00:00Z' }),
    };

    const controller = new AuthController(
      mockPhoneAuth as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
    );

    await controller.createPhoneChallenge(
      { phone: '+84901234567' },
      'dev-header-id',
      '118.69.182.10',
    );

    expect(mockPhoneAuth.createChallenge).toHaveBeenCalledWith('+84901234567', {
      deviceId: 'dev-header-id',
      ipAddress: '118.69.182.10',
    });
  });

  it('forwards deviceId, userAgent, and ip address when verifying phone challenge', async () => {
    const mockPhoneAuth = {
      verify: vi.fn().mockResolvedValue({ accessToken: 'at', refreshToken: 'rt' }),
    };

    const controller = new AuthController(
      mockPhoneAuth as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
    );

    await controller.verifyPhoneChallenge(
      'uuid-challenge',
      { code: '123456' },
      'device-uuid-1',
      'DealGo/1.0.0 (iPhone; iOS 17.5)',
      '118.69.182.10',
    );

    expect(mockPhoneAuth.verify).toHaveBeenCalledWith('uuid-challenge', '123456', {
      deviceId: 'device-uuid-1',
      userAgent: 'DealGo/1.0.0 (iPhone; iOS 17.5)',
      ipAddress: '118.69.182.10',
    });
  });

  it('forwards deviceId, userAgent, and ip address on session refresh', async () => {
    const mockSessions = {
      refresh: vi.fn().mockResolvedValue({ accessToken: 'at-2', refreshToken: 'rt-2' }),
    };

    const controller = new AuthController(
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      {} as any,
      mockSessions as any,
      {} as any,
    );

    await controller.refresh(
      { refreshToken: 'rt-old' },
      'DealGo/1.0.0 (Android 14)',
      'device-uuid-android',
      '118.69.182.10',
    );

    expect(mockSessions.refresh).toHaveBeenCalledWith('rt-old', {
      deviceId: 'device-uuid-android',
      userAgent: 'DealGo/1.0.0 (Android 14)',
      ipAddress: '118.69.182.10',
    });
  });
});
