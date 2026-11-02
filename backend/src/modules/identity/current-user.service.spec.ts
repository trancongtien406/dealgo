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
      contactPhone: null,
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

  it('saving the current unverified email mails nothing; a different address starts verification', async () => {
    const repository = new MemoryIdentityRepository();
    const user = await repository.createUser({ phone: null, email: 'lan@x.vn', displayName: 'Lan' });
    const emailVerification = {
      request: vi.fn().mockResolvedValue({
        verificationId: 'ver-2',
        expiresAt: '2026-11-02T12:10:00.000Z',
        resendAvailableAt: '2026-11-02T12:01:00.000Z',
      }),
    };
    const service = new CurrentUserService(repository, emailVerification as any, { get: vi.fn() } as any);

    const same = await service.updateProfile(user.id, { displayName: 'Lan', email: ' Lan@X.vn ' });
    expect(emailVerification.request).not.toHaveBeenCalled();
    expect(same.pendingEmailVerification).toBeUndefined();

    const changed = await service.updateProfile(user.id, { email: 'lan.new@x.vn' });
    expect(emailVerification.request).toHaveBeenCalledWith(user.id, 'lan.new@x.vn');
    expect(changed.pendingEmailVerification?.verificationId).toBe('ver-2');
    expect(changed.email).toBe('lan@x.vn');
  });

  describe('contact phone at profile completion (no OTP)', () => {
    const make = () => {
      const repository = new MemoryIdentityRepository();
      const config = { get: vi.fn(() => undefined) };
      const service = new CurrentUserService(repository, { request: vi.fn() } as any, config as any);
      return { repository, service };
    };

    it('an email account with a name still needs setup until it has a phone', async () => {
      const { repository, service } = make();
      const user = await repository.createUser({ phone: null, email: 'a@x.vn', displayName: 'Lan' });
      expect((await service.getProfile(user.id)).needsProfileSetup).toBe(true);

      const saved = await service.updateProfile(user.id, { contactPhone: '0912 345 678' });
      expect(saved.contactPhone).toBe('+84912345678');
      expect(saved.needsProfileSetup).toBe(false);
      // A typed contact number is never a verified sign-in phone.
      expect(saved.phone).toBeNull();
      expect(saved.phoneVerifiedAt).toBeNull();
    });

    it('refuses to drop the only phone on an email or passkey account', async () => {
      const { repository, service } = make();
      const user = await repository.createUser({ phone: null, email: 'c@x.vn', displayName: 'Lan' });
      await service.updateProfile(user.id, { contactPhone: '0901234567' });
      await expect(service.updateProfile(user.id, { contactPhone: null })).rejects.toMatchObject({
        response: expect.objectContaining({ errorCode: 'VALIDATION_ERROR' }),
      });
      expect((await service.getProfile(user.id)).contactPhone).toBe('+84901234567');
    });

    it('rejects a non-Vietnamese or malformed number', async () => {
      const { repository, service } = make();
      const user = await repository.createUser({ phone: null, email: 'b@x.vn', displayName: 'B' });
      for (const bad of [
        '12345',
        '+14155550100',
        '0212345678',
        '091234567',
        '0301234567',
        '0712345678',
        '0801234567',
        '0951234567',
        '+840901234567',
      ]) {
        await expect(service.updateProfile(user.id, { contactPhone: bad })).rejects.toMatchObject({
          response: expect.objectContaining({ errorCode: 'VALIDATION_ERROR' }),
        });
      }
    });

    it('a phone-OTP account does not need a contact number', async () => {
      const { repository, service } = make();
      const user = await repository.createUser({ phone: '+84901111112', email: null, displayName: 'C' });
      expect((await service.getProfile(user.id)).needsProfileSetup).toBe(false);
    });
  });
});
