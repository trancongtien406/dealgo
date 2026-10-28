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
});
