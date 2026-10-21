import { describe, expect, it, vi } from 'vitest';
import { CurrentUserService, needsProfileSetup } from './current-user.service.js';
import { MemoryIdentityRepository } from './identity.repository.js';

describe('needsProfileSetup', () => {
  it('is true for empty and default DealGo user names', () => {
    expect(needsProfileSetup('')).toBe(true);
    expect(needsProfileSetup('   ')).toBe(true);
    expect(needsProfileSetup('DealGo user')).toBe(true);
    expect(needsProfileSetup('dealgo user')).toBe(true);
  });

  it('is false for a meaningful display name', () => {
    expect(needsProfileSetup('Nguyen Van A')).toBe(false);
  });
});

describe('CurrentUserService', () => {
  it('returns full profile shape including needsProfileSetup', async () => {
    const repository = new MemoryIdentityRepository();
    const user = await repository.createUser({
      phone: '+84901111111',
      email: null,
      displayName: 'DealGo user',
    });
    await repository.markPhoneVerified(user.id, new Date('2026-10-01T00:00:00.000Z'));
    await repository.insertGrant(user.id, 'CUSTOMER', 'ACTIVE');

    const emailVerification = {
      request: vi.fn(),
    };
    const config = {
      get: vi.fn((key: string) => {
        if (key === 'KYC_STORAGE_PROVIDER') return 'mock';
        if (key === 'NODE_ENV') return 'test';
        return undefined;
      }),
    };

    const service = new CurrentUserService(
      repository,
      emailVerification as any,
      config as any,
    );

    const profile = await service.getProfile(user.id);
    expect(profile).toEqual({
      id: user.id,
      phone: '+84901111111',
      email: null,
      displayName: 'DealGo user',
      dateOfBirth: null,
      gender: null,
      avatarUrl: null,
      phoneVerifiedAt: '2026-10-01T00:00:00.000Z',
      emailVerifiedAt: null,
      needsProfileSetup: true,
      grants: [{ role: 'CUSTOMER', status: 'ACTIVE' }],
    });
  });

  it('updates profile fields and starts email verification without setting email', async () => {
    const repository = new MemoryIdentityRepository();
    const user = await repository.createUser({
      phone: '+84902222222',
      email: null,
      displayName: 'DealGo user',
    });

    const emailVerification = {
      request: vi.fn().mockResolvedValue({
        verificationId: 'ver-1',
        expiresAt: '2026-10-18T12:00:00.000Z',
      }),
    };
    const config = {
      get: vi.fn(() => 'mock'),
    };

    const service = new CurrentUserService(
      repository,
      emailVerification as any,
      config as any,
    );

    const updated = await service.updateProfile(user.id, {
      displayName: 'Tran Van B',
      gender: 'MALE',
      dateOfBirth: '1995-05-20T00:00:00.000Z',
      email: 'b@dealgo.test',
    });

    expect(emailVerification.request).toHaveBeenCalledWith(user.id, 'b@dealgo.test');
    expect(updated.displayName).toBe('Tran Van B');
    expect(updated.gender).toBe('MALE');
    expect(updated.dateOfBirth).toBe('1995-05-20T00:00:00.000Z');
    expect(updated.needsProfileSetup).toBe(false);
    expect(updated.email).toBeNull();
    expect(updated.pendingEmailVerification).toEqual({
      verificationId: 'ver-1',
      expiresAt: '2026-10-18T12:00:00.000Z',
    });

    const stored = await repository.findUserById(user.id);
    expect(stored?.email).toBeNull();
    expect(stored?.displayName).toBe('Tran Van B');
  });
});
