import { describe, expect, it, vi } from 'vitest';
import { needsProfileSetup } from './current-user.service.js';
import { MemoryIdentityRepository } from './identity.repository.js';
import { PasskeyService } from './passkey.service.js';

/**
 * "Continue with passkey" (one button): the app tries a discoverable sign-in first and only
 * falls back to a contact-less sign-up when the device has no DealGo passkey or the server
 * does not know the credential. These checks keep that fallback safe.
 */
function setup() {
  const repository = new MemoryIdentityRepository();
  const sessions = { issue: vi.fn(async (user: { id: string }) => ({ accessToken: `a-${user.id}` })) };
  const config = {
    get: vi.fn((key: string) =>
      ({
        WEBAUTHN_RP_ID: 'dealgo.test',
        WEBAUTHN_RP_NAME: 'DealGo',
        WEBAUTHN_ORIGIN: 'https://dealgo.test',
      })[key],
    ),
  };
  const authMethods = { assertEnabled: vi.fn(async () => undefined) };
  const service = new PasskeyService(repository, sessions as any, config as any, authMethods as any);
  return { repository, service, sessions, authMethods };
}

const assertion = (id: string) =>
  ({
    id,
    rawId: id,
    type: 'public-key',
    response: { clientDataJSON: 'x', authenticatorData: 'x', signature: 'x' },
    clientExtensionResults: {},
  }) as any;

const attestation = (id: string) =>
  ({
    id,
    rawId: id,
    type: 'public-key',
    response: { clientDataJSON: 'x', attestationObject: 'x' },
    clientExtensionResults: {},
  }) as any;

const invalid = { response: expect.objectContaining({ errorCode: 'AUTH_PASSKEY_INVALID' }) };

describe('continue with passkey', () => {
  it('an unknown credential gets the same generic 401 as a bad signature (no enumeration)', async () => {
    const { service, sessions } = setup();
    const { ceremonyId } = await service.authenticationOptions();
    await expect(service.verifyAuthentication(ceremonyId, assertion('nobody'))).rejects.toMatchObject(invalid);
    expect(sessions.issue).not.toHaveBeenCalled();
  });

  it('a sign-up ceremony cannot be replayed as a sign-in and vice versa', async () => {
    const { service, repository } = setup();
    const user = await repository.createUser({ phone: null, email: null, displayName: 'DealGo user' });
    await repository.savePasskey({
      userId: user.id,
      credentialId: 'cred-1',
      publicKey: new Uint8Array([1]),
      counter: 0,
      transports: [],
      deviceType: 'multiDevice',
      backedUp: true,
    });
    const signup = await service.signupOptions();
    await expect(service.verifyAuthentication(signup.ceremonyId, assertion('cred-1'))).rejects.toMatchObject(invalid);
    const signin = await service.authenticationOptions();
    await expect(service.verifySignup(signin.ceremonyId, attestation('cred-2'))).rejects.toMatchObject(invalid);
  });

  it('every ceremony gets its own single-use, short-lived challenge', async () => {
    const { service, repository } = setup();
    const a = await service.signupOptions();
    const b = await service.signupOptions();
    expect(a.ceremonyId).not.toBe(b.ceremonyId);
    expect(a.challenge).not.toBe(b.challenge);
    const stored = await repository.findPasskeyChallenge(a.ceremonyId);
    expect(stored?.userId).toBeNull();
    expect(stored!.expiresAt.getTime() - Date.now()).toBeLessThanOrEqual(5 * 60_000);
    // Parallel strangers' ceremonies do not cancel each other.
    expect((await repository.findPasskeyChallenge(a.ceremonyId))?.consumedAt ?? null).toBeNull();
  });

  it('respects the passkey on/off switch on every step', async () => {
    const { service, authMethods } = setup();
    authMethods.assertEnabled.mockRejectedValue(new Error('NOT_FOUND'));
    await expect(service.authenticationOptions()).rejects.toThrow('NOT_FOUND');
    await expect(service.signupOptions()).rejects.toThrow('NOT_FOUND');
  });

  it('a passkey-created account goes to profile completion (name + phone)', async () => {
    const { repository } = setup();
    const user = await repository.createPasskeyUser({
      credentialId: 'new-cred',
      publicKey: new Uint8Array([1]),
      counter: 0,
      transports: [],
      deviceType: 'multiDevice',
      backedUp: true,
    });
    expect(user.phone).toBeNull();
    expect(user.email).toBeNull();
    expect(needsProfileSetup(user.displayName)).toBe(true);
  });
});
