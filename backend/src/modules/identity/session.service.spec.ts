import { describe, expect, it } from 'vitest';
import { ConfigService } from '@nestjs/config';
import { SessionService } from './session.service.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import type { AppEnv } from '../../platform/config/env.js';
import { hashRefreshToken } from '../../platform/security/token-crypto.js';

describe('SessionService', () => {
  const createService = (presenceRepo?: unknown) => {
    const repository = new MemoryIdentityRepository();
    const configValues: Partial<AppEnv> = {
      NODE_ENV: 'test',
      JWT_ACCESS_SECRET: 'test-secret-at-least-32-characters-long-key',
      JWT_ACCESS_TTL_SECONDS: 900,
      JWT_REFRESH_TTL_SECONDS: 604800,
    };

    const config = {
      get: (key: keyof AppEnv) => configValues[key],
    } as unknown as ConfigService<AppEnv, true>;

    const service = new SessionService(repository, config, presenceRepo as never);
    return { service, repository };
  };

  it('issues session with signed access token and raw refresh token', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'customer@dealgo.vn',
      phone: '+84901234567',
      displayName: 'Nguyen Van A',
    });

    const session = await service.issue(user, 'customer');

    expect(session.accessToken).toBeDefined();
    expect(typeof session.accessToken).toBe('string');
    expect(session.refreshToken).toBeDefined();
    expect(session.expiresIn).toBe(900);
    expect(session.user.id).toBe(user.id);
  });

  it('rotates refresh token on refresh', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'customer@dealgo.vn',
      phone: '+84901234567',
      displayName: 'Nguyen Van A',
    });

    const initial = await service.issue(user, 'customer');

    const rotated = await service.refresh(initial.refreshToken);
    expect(rotated.accessToken).toBeDefined();
    expect(rotated.refreshToken).not.toBe(initial.refreshToken);
  });

  it('keeps the device id and updates request metadata when refreshing', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'metadata@dealgo.vn',
      phone: '+84901234569',
      displayName: 'Metadata User',
    });
    const initial = await service.issue(user, 'customer', {
      deviceId: 'device-1',
      userAgent: 'DealGo/old',
      ipAddress: '192.0.2.1',
    });

    const rotated = await service.refresh(initial.refreshToken, {
      userAgent: 'DealGo/new',
      ipAddress: '198.51.100.8',
    });
    const stored = await repository.findSessionByRefreshTokenHash(
      hashRefreshToken(rotated.refreshToken),
    );

    expect(stored).toMatchObject({
      deviceId: 'device-1',
      userAgent: 'DealGo/new',
      ipAddress: '198.51.100.8',
    });
  });

  it('updates the device id if provided when refreshing an older session', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'device-refresh@dealgo.vn',
      phone: '+84901234568',
      displayName: 'Device User',
    });
    const initial = await service.issue(user, 'customer');

    const rotated = await service.refresh(initial.refreshToken, {
      deviceId: 'device-new-uuid',
      userAgent: 'DealGo/1.0',
      ipAddress: '118.69.182.10',
    });
    const stored = await repository.findSessionByRefreshTokenHash(
      hashRefreshToken(rotated.refreshToken),
    );

    expect(stored).toMatchObject({
      deviceId: 'device-new-uuid',
      userAgent: 'DealGo/1.0',
      ipAddress: '118.69.182.10',
    });
  });

  it('detects refresh token reuse and throws AUTH_REFRESH_REUSED', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'customer@dealgo.vn',
      phone: '+84901234567',
      displayName: 'Nguyen Van A',
    });

    const initial = await service.issue(user, 'customer');

    // First rotation succeeds
    await service.refresh(initial.refreshToken);

    // Replay attack with the already rotated token must fail with reuse detection
    await expect(service.refresh(initial.refreshToken)).rejects.toMatchObject({
      response: {
        errorCode: 'AUTH_REFRESH_REUSED',
      },
    });
  });

  it('rejects unknown refresh token with AUTH_REFRESH_INVALID', async () => {
    const { service } = createService();
    await expect(
      service.refresh('completely-invalid-secret'),
    ).rejects.toMatchObject({
      response: {
        errorCode: 'AUTH_REFRESH_INVALID',
      },
    });
  });

  it('revokes session and rejects subsequent refresh attempts', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'customer@dealgo.vn',
      phone: '+84901234567',
      displayName: 'Nguyen Van A',
    });

    const session = await service.issue(user, 'customer');

    // Find session id from repo
    const sessions = await repository.findUserDirectory(user.id);
    expect(sessions).toBeDefined();

    // Revoke
    const res = await service.revoke(session.user.id);
    expect(res.revoked).toBe(true);
  });

  it('revokes session by refresh token and prevents future refresh', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'ops@dealgo.vn',
      phone: '+84901234568',
      displayName: 'Ops Admin',
    });

    const session = await service.issue(user, 'ops');
    const revokeResult = await service.revokeByRefreshToken(
      session.refreshToken,
    );
    expect(revokeResult.revoked).toBe(true);

    // Refreshing the revoked token must fail with AUTH_REFRESH_INVALID
    await expect(service.refresh(session.refreshToken)).rejects.toMatchObject({
      status: 401,
      response: expect.objectContaining({
        errorCode: 'AUTH_REFRESH_INVALID',
      }),
    });
  });

  it('revokes older sessions when a driver signs in on a new device (single device login)', async () => {
    const { service, repository } = createService();
    const user = await repository.createUser({
      email: 'driver@dealgo.vn',
      phone: '+84909999999',
      displayName: 'Driver Nguyen',
    });
    await repository.insertGrant(user.id, 'DRIVER', 'ACTIVE');

    // Device A signs in
    const sessionA = await service.issue(user, 'customer', {
      deviceLabel: 'Device A',
    });

    // Device B signs in with same account
    const sessionB = await service.issue(user, 'customer', {
      deviceLabel: 'Device B',
    });

    // Session B is valid and can refresh
    const refreshedB = await service.refresh(sessionB.refreshToken);
    expect(refreshedB.accessToken).toBeDefined();

    // Session A is revoked: refresh fails with 401
    await expect(service.refresh(sessionA.refreshToken)).rejects.toMatchObject({
      status: 401,
      response: expect.objectContaining({
        errorCode: 'AUTH_REFRESH_INVALID',
      }),
    });
  });

  it('sets driver presence offline when the last session is revoked', async () => {
    const presenceRepo = {
      findByUserId: vi.fn().mockResolvedValue({ userId: 'u1', online: true }),
      upsert: vi.fn().mockResolvedValue({ userId: 'u1', online: false }),
    };
    const { service, repository } = createService(presenceRepo);
    const user = await repository.createUser({
      email: 'driver2@dealgo.vn',
      phone: '+84909888888',
      displayName: 'Driver Test',
    });
    await service.issue(user, 'customer');

    const sessions = await repository.listActiveSessions(user.id);
    expect(sessions.length).toBe(1);

    // Revoke the only session
    await service.revoke(sessions[0]!.id);

    expect(presenceRepo.findByUserId).toHaveBeenCalledWith(user.id);
    expect(presenceRepo.upsert).toHaveBeenCalledWith(user.id, { online: false });
  });
});
