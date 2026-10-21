import { Inject, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from '@simplewebauthn/server';
import type {
  AuthenticationResponseJSON,
  RegistrationResponseJSON,
} from '@simplewebauthn/server';
import type { AppEnv } from '../../platform/config/env.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import { IDENTITY_REPOSITORY, PASSKEY_CHALLENGE_TTL_MS } from './identity.constants.js';
import { UniqueConflictError, type IdentityRepository } from './identity.repository.js';
import { SessionService, type SessionResult } from './session.service.js';

@Injectable()
export class PasskeyService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
    private readonly sessions: SessionService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
  ) {}

  async registrationOptions(userId: string): Promise<Awaited<ReturnType<typeof generateRegistrationOptions>>> {
    await this.authMethods.assertEnabled('PASSKEY');
    const user = await this.requirePhoneUser(userId);
    const existing = await this.repository.listPasskeys(user.id);
    const options = await generateRegistrationOptions({
      ...this.relyingParty(),
      userName: user.phone ?? user.id,
      userDisplayName: user.displayName,
      userID: Buffer.from(user.id),
      attestationType: 'none',
      authenticatorSelection: {
        residentKey: 'required',
        userVerification: 'required',
      },
      excludeCredentials: existing.map((passkey) => ({
        id: passkey.credentialId,
        transports: passkey.transports,
      })),
    });
    await this.repository.replacePasskeyChallenge({
      userId: user.id,
      kind: 'REGISTRATION',
      challenge: options.challenge,
      expiresAt: new Date(Date.now() + PASSKEY_CHALLENGE_TTL_MS),
    });
    return options;
  }

  async verifyRegistration(
    userId: string,
    response: RegistrationResponseJSON,
  ): Promise<{ credentialId: string }> {
    await this.authMethods.assertEnabled('PASSKEY');
    const user = await this.requirePhoneUser(userId);
    const ceremony = await this.repository.findOpenPasskeyChallenge(user.id, 'REGISTRATION');
    if (!ceremony || ceremony.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const relyingParty = this.relyingParty();
    let verification: Awaited<ReturnType<typeof verifyRegistrationResponse>>;
    try {
      verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: relyingParty.origin,
        expectedRPID: relyingParty.rpID,
        requireUserVerification: true,
      });
    } catch {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    if (!verification.verified) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const consumed = await this.repository.consumePasskeyChallenge(ceremony.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const credential = verification.registrationInfo.credential;
    try {
      await this.repository.savePasskey({
        userId: user.id,
        credentialId: credential.id,
        publicKey: new Uint8Array(credential.publicKey),
        counter: credential.counter,
        transports: credential.transports ?? [],
        deviceType: verification.registrationInfo.credentialDeviceType,
        backedUp: verification.registrationInfo.credentialBackedUp,
      });
    } catch (error) {
      if (error instanceof UniqueConflictError) {
        throw authError(409, 'AUTH_PASSKEY_EXISTS', 'Passkey is already registered');
      }
      throw error;
    }
    return { credentialId: credential.id };
  }

  async authenticationOptions(): Promise<Awaited<ReturnType<typeof generateAuthenticationOptions>> & { ceremonyId: string }> {
    await this.authMethods.assertEnabled('PASSKEY');
    const options = await generateAuthenticationOptions({
      rpID: this.relyingParty().rpID,
      userVerification: 'required',
    });
    const ceremony = await this.repository.replacePasskeyChallenge({
      userId: null,
      kind: 'AUTHENTICATION',
      challenge: options.challenge,
      expiresAt: new Date(Date.now() + PASSKEY_CHALLENGE_TTL_MS),
    });
    return { ...options, ceremonyId: ceremony.id };
  }

  async verifyAuthentication(ceremonyId: string, response: AuthenticationResponseJSON): Promise<SessionResult> {
    await this.authMethods.assertEnabled('PASSKEY');
    const passkey = await this.repository.findPasskeyByCredentialId(response.id);
    if (!passkey) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    const ceremony = await this.repository.findPasskeyChallenge(ceremonyId);
    if (!ceremony || ceremony.kind !== 'AUTHENTICATION' || ceremony.consumedAt ||
        ceremony.expiresAt <= new Date() || (ceremony.userId !== null && ceremony.userId !== passkey.userId)) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const relyingParty = this.relyingParty();
    let verification: Awaited<ReturnType<typeof verifyAuthenticationResponse>>;
    try {
      verification = await verifyAuthenticationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: relyingParty.origin,
        expectedRPID: relyingParty.rpID,
        requireUserVerification: true,
        credential: {
          id: passkey.credentialId,
          publicKey: copyBytes(passkey.publicKey),
          counter: passkey.counter,
          transports: passkey.transports,
        },
      });
    } catch {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    if (!verification.verified) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const user = await this.repository.findUserById(passkey.userId);
    if (!user) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }

    const consumed = await this.repository.consumePasskeyChallenge(ceremony.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    await this.repository.updatePasskeyCounter(passkey.id, verification.authenticationInfo.newCounter);

    return this.sessions.issue(user, 'customer');
  }

  async signupOptions(): Promise<Awaited<ReturnType<typeof generateRegistrationOptions>> & { ceremonyId: string }> {
    await this.authMethods.assertEnabled('PASSKEY');
    const options = await generateRegistrationOptions({
      ...this.relyingParty(),
      userName: 'New DealGo account',
      userDisplayName: 'DealGo user',
      attestationType: 'none',
      authenticatorSelection: { residentKey: 'required', userVerification: 'required' },
    });
    const ceremony = await this.repository.replacePasskeyChallenge({
      userId: null,
      kind: 'REGISTRATION',
      challenge: options.challenge,
      expiresAt: new Date(Date.now() + PASSKEY_CHALLENGE_TTL_MS),
    });
    return { ...options, ceremonyId: ceremony.id };
  }

  async verifySignup(ceremonyId: string, response: RegistrationResponseJSON): Promise<SessionResult> {
    await this.authMethods.assertEnabled('PASSKEY');
    const ceremony = await this.repository.findPasskeyChallenge(ceremonyId);
    if (!ceremony || ceremony.kind !== 'REGISTRATION' || ceremony.userId !== null ||
        ceremony.consumedAt || ceremony.expiresAt <= new Date()) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    let verification: Awaited<ReturnType<typeof verifyRegistrationResponse>>;
    try {
      const rp = this.relyingParty();
      verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: rp.origin,
        expectedRPID: rp.rpID,
        requireUserVerification: true,
      });
    } catch {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    if (!verification.verified) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    const consumed = await this.repository.consumePasskeyChallenge(ceremony.id, new Date());
    if (!consumed) {
      throw authError(401, 'AUTH_PASSKEY_INVALID', 'Passkey verification failed');
    }
    const credential = verification.registrationInfo.credential;
    try {
      const user = await this.repository.createPasskeyUser({
        credentialId: credential.id,
        publicKey: new Uint8Array(credential.publicKey),
        counter: credential.counter,
        transports: credential.transports ?? [],
        deviceType: verification.registrationInfo.credentialDeviceType,
        backedUp: verification.registrationInfo.credentialBackedUp,
      });
      return this.sessions.issue(user, 'customer');
    } catch (error) {
      if (error instanceof UniqueConflictError) {
        throw authError(409, 'AUTH_PASSKEY_EXISTS', 'Passkey is already registered');
      }
      throw error;
    }
  }

  private async requirePhoneUser(userId: string) {
    const user = await this.repository.findUserById(userId);
    if (!user || !user.phoneVerifiedAt) {
      throw authError(403, 'FORBIDDEN', 'A verified phone session is required');
    }
    return user;
  }

  private relyingParty(): { rpID: string; rpName: string; origin: string } {
    const rpID = this.config.get('WEBAUTHN_RP_ID', { infer: true });
    const rpName = this.config.get('WEBAUTHN_RP_NAME', { infer: true });
    const origin = this.config.get('WEBAUTHN_ORIGIN', { infer: true });
    if (!rpID || !rpName || !origin) {
      throw authError(500, 'WEBAUTHN_NOT_CONFIGURED', 'Passkey is not configured');
    }
    return { rpID, rpName, origin };
  }
}

function copyBytes(value: Uint8Array): Uint8Array<ArrayBuffer> {
  const buffer = new ArrayBuffer(value.byteLength);
  const copy = new Uint8Array(buffer);
  copy.set(value);
  return copy;
}
