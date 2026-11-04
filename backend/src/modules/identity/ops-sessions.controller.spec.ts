import { describe, expect, it, vi } from 'vitest';
import { OpsSessionsController } from './ops-sessions.controller.js';

describe('OpsSessionsController', () => {
  it('forwards ipAddress, userAgent, and deviceId to opsAuth.login', async () => {
    const mockOpsAuth = {
      login: vi.fn().mockResolvedValue({
        accessToken: 'ops-access-token',
        refreshToken: 'ops-refresh-token',
      }),
    };
    const mockSessions = {
      revoke: vi.fn(),
      revokeByRefreshToken: vi.fn(),
    };
    const mockConfig = {
      get: vi.fn(),
    };

    const controller = new OpsSessionsController(
      mockOpsAuth as any,
      mockSessions as any,
      mockConfig as any,
    );

    const result = await controller.login(
      { email: 'admin@dealgo.vn', password: 'Password123@' },
      '118.69.182.10',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      'ops-workstation-1',
    );

    expect(result).toEqual({
      accessToken: 'ops-access-token',
      refreshToken: 'ops-refresh-token',
    });
    expect(mockOpsAuth.login).toHaveBeenCalledWith(
      'admin@dealgo.vn',
      'Password123@',
      {
        deviceId: 'ops-workstation-1',
        userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
        ipAddress: '118.69.182.10',
      },
    );
  });
});
