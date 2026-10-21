import { describe, expect, it, vi } from 'vitest';
import { AuthController } from './auth.controller.js';

describe('AuthController listMethods', () => {
  it('returns auth methods from AuthMethodPolicyService', async () => {
    const mockAuthMethods = {
      list: vi.fn().mockResolvedValue([
        {
          method: 'PASSKEY',
          enabled: true,
          updatedAt: '2026-10-18T00:00:00.000Z',
          updatedByUserId: null,
        },
        {
          method: 'PHONE_SMS',
          enabled: true,
          updatedAt: '2026-10-18T00:00:00.000Z',
          updatedByUserId: null,
        },
        {
          method: 'EMAIL_LOGIN_IDENTIFIER',
          enabled: true,
          updatedAt: '2026-10-18T00:00:00.000Z',
          updatedByUserId: null,
        },
      ]),
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

    const result = await controller.listMethods();
    expect(result).toHaveLength(3);
    expect(mockAuthMethods.list).toHaveBeenCalled();
  });
});
