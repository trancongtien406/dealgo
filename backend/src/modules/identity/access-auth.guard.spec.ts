import { ExecutionContext } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AccessAuthGuard, OpsSessionGuard } from './access-auth.guard.js';
import type { IdentityRepository, SessionRecord, RoleGrantRecord } from './identity.repository.js';
import { signAccessToken } from '../../platform/security/token-crypto.js';

describe('AccessAuthGuard and OpsSessionGuard', () => {
  const secret = 'test-access-secret-32-chars-long!!';
  const config = {
    get: (key: string) => {
      if (key === 'JWT_ACCESS_SECRET') return secret;
      if (key === 'NODE_ENV') return 'test';
      return undefined;
    },
  } as unknown as ConfigService<any, true>;

  const findSessionByIdMock = vi.fn();
  const listGrantsMock = vi.fn();

  const mockRepo = {
    findSessionById: findSessionByIdMock,
    listGrants: listGrantsMock,
  } as unknown as IdentityRepository;

  const accessGuard = new AccessAuthGuard(mockRepo, config);
  const opsGuard = new OpsSessionGuard(accessGuard, mockRepo);

  function makeContext(authHeader?: string) {
    const request: Record<string, unknown> = {
      headers: authHeader ? { authorization: authHeader } : {},
    };
    return {
      switchToHttp: () => ({
        getRequest: () => request,
      }),
      request,
    };
  }

  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('rejects expired session even if access token is signed correctly', async () => {
    const expiredDate = new Date(Date.now() - 1000);
    const now = Math.floor(Date.now() / 1000);
    const token = signAccessToken(
      { sub: 'user-1', sid: 'sess-expired', ch: 'customer', iat: now, exp: now + 3600 },
      secret,
    );

    findSessionByIdMock.mockResolvedValueOnce({
      id: 'sess-expired',
      userId: 'user-1',
      channel: 'CUSTOMER',
      expiresAt: expiredDate,
      revokedAt: null,
    } as unknown as SessionRecord);

    const { switchToHttp } = makeContext(`Bearer ${token}`);
    await expect(
      accessGuard.canActivate({ switchToHttp } as unknown as ExecutionContext),
    ).rejects.toMatchObject({ status: 401 });
  });

  it('allows active valid session in AccessAuthGuard', async () => {
    const futureDate = new Date(Date.now() + 60_000);
    const now = Math.floor(Date.now() / 1000);
    const token = signAccessToken(
      { sub: 'user-1', sid: 'sess-valid', ch: 'customer', iat: now, exp: now + 3600 },
      secret,
    );

    findSessionByIdMock.mockResolvedValueOnce({
      id: 'sess-valid',
      userId: 'user-1',
      channel: 'CUSTOMER',
      expiresAt: futureDate,
      revokedAt: null,
    } as unknown as SessionRecord);

    const { switchToHttp, request } = makeContext(`Bearer ${token}`);
    const result = await accessGuard.canActivate({ switchToHttp } as unknown as ExecutionContext);
    expect(result).toBe(true);
    expect(request.actor).toEqual({
      userId: 'user-1',
      sessionId: 'sess-valid',
      channel: 'customer',
    });
  });

  it('rejects OpsSessionGuard if operator does not have ACTIVE OPS grant', async () => {
    const futureDate = new Date(Date.now() + 60_000);
    const now = Math.floor(Date.now() / 1000);
    const token = signAccessToken(
      { sub: 'operator-1', sid: 'sess-ops-1', ch: 'ops', iat: now, exp: now + 3600 },
      secret,
    );

    findSessionByIdMock.mockResolvedValueOnce({
      id: 'sess-ops-1',
      userId: 'operator-1',
      channel: 'OPS',
      expiresAt: futureDate,
      revokedAt: null,
    } as unknown as SessionRecord);

    // Operator grant is SUSPENDED
    listGrantsMock.mockResolvedValueOnce([
      { role: 'OPS', status: 'SUSPENDED' } as unknown as RoleGrantRecord,
    ]);

    const { switchToHttp } = makeContext(`Bearer ${token}`);
    await expect(
      opsGuard.canActivate({ switchToHttp } as unknown as ExecutionContext),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('allows OpsSessionGuard if operator has ACTIVE OPS grant', async () => {
    const futureDate = new Date(Date.now() + 60_000);
    const now = Math.floor(Date.now() / 1000);
    const token = signAccessToken(
      { sub: 'operator-1', sid: 'sess-ops-2', ch: 'ops', iat: now, exp: now + 3600 },
      secret,
    );

    findSessionByIdMock.mockResolvedValueOnce({
      id: 'sess-ops-2',
      userId: 'operator-1',
      channel: 'OPS',
      expiresAt: futureDate,
      revokedAt: null,
    } as unknown as SessionRecord);

    listGrantsMock.mockResolvedValueOnce([
      { role: 'OPS', status: 'ACTIVE' } as unknown as RoleGrantRecord,
    ]);

    const { switchToHttp, request } = makeContext(`Bearer ${token}`);
    const result = await opsGuard.canActivate({ switchToHttp } as unknown as ExecutionContext);
    expect(result).toBe(true);
    expect(request.actor).toEqual({
      userId: 'operator-1',
      sessionId: 'sess-ops-2',
      channel: 'ops',
    });
  });
});
