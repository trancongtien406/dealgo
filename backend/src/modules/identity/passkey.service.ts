import { Inject, Injectable, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  generateAuthenticationOptions,
  generateRegistrationOptions,
  verifyAuthenticationResponse,
  verifyRegistrationResponse,
} from '@simplewebauthn/server';
import type {
  AuthenticationResponseJSON,
  PublicKeyCredentialRequestOptionsJSON,
  RegistrationResponseJSON,
} from '@simplewebauthn/server';
import type { AppEnv } from '../../platform/config/env.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { authError } from './auth-error.js';
import { AuthMethodPolicyService } from './auth-method-policy.service.js';
import {
  IDENTITY_REPOSITORY,
  MAX_ACCOUNTS_PER_DEVICE,
  PASSKEY_CHALLENGE_TTL_MS,
} from './identity.constants.js';
import {
  UniqueConflictError,
  type IdentityRepository,
} from './identity.repository.js';
import {
  SessionService,
  type SessionClientContext,
  type SessionResult,
} from './session.service.js';
import { webauthnExpectedOrigins } from '../app-links/app-links.js';

@Injectable()
export class PasskeyService {
  constructor(
    @Inject(IDENTITY_REPOSITORY)
    private readonly repository: IdentityRepository,
    private readonly sessions: SessionService,
    private readonly config: ConfigService<AppEnv, true>,
    private readonly authMethods: AuthMethodPolicyService,
    @Optional() private readonly platformSettings?: PlatformSettingsService,
  ) {}

  async registrationOptions(
    userId: string,
  ): Promise<Awaited<ReturnType<typeof generateRegistrationOptions>>> {
    await this.authMethods.assertEnabled('PASSKEY');
    const user = await this.requireVerifiedUser(userId);
    const existing = await this.repository.listPasskeys(user.id);
    const options = await generateRegistrationOptions({
      ...(await this.relyingParty()),
      userName:
        (user.phoneVerifiedAt ? user.phone : null) ??
        (user.emailVerifiedAt ? user.email : null) ??
        user.id,
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
    const user = await this.requireVerifiedUser(userId);
    const ceremony = await this.repository.findOpenPasskeyChallenge(
      user.id,
      'REGISTRATION',
    );
    if (!ceremony || ceremony.expiresAt <= new Date()) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }

    const relyingParty = await this.relyingParty();
    let verification: Awaited<ReturnType<typeof verifyRegistrationResponse>>;
    try {
      verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: relyingParty.origins,
        expectedRPID: relyingParty.rpID,
        requireUserVerification: true,
      });
    } catch {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    if (!verification.verified) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }

    const consumed = await this.repository.consumePasskeyChallenge(
      ceremony.id,
      new Date(),
    );
    if (!consumed) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
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
        throw authError(
          409,
          'AUTH_PASSKEY_EXISTS',
          'Passkey is already registered',
        );
      }
      throw error;
    }
    return { credentialId: credential.id };
  }

  async authenticationOptions(): Promise<
    Awaited<ReturnType<typeof generateAuthenticationOptions>> & {
      ceremonyId: string;
    }
  > {
    await this.authMethods.assertEnabled('PASSKEY');
    const rp = await this.relyingParty();
    const options = await generateAuthenticationOptions({
      rpID: rp.rpID,
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

  async verifyAuthentication(
    ceremonyId: string,
    response: AuthenticationResponseJSON,
    clientContext?: SessionClientContext,
  ): Promise<SessionResult> {
    await this.authMethods.assertEnabled('PASSKEY');
    const passkey = await this.repository.findPasskeyByCredentialId(
      response.id,
    );
    if (!passkey) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    const ceremony = await this.repository.findPasskeyChallenge(ceremonyId);
    if (
      !ceremony ||
      ceremony.kind !== 'AUTHENTICATION' ||
      ceremony.consumedAt ||
      ceremony.expiresAt <= new Date() ||
      (ceremony.userId !== null && ceremony.userId !== passkey.userId)
    ) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }

    const relyingParty = await this.relyingParty();
    let verification: Awaited<ReturnType<typeof verifyAuthenticationResponse>>;
    try {
      verification = await verifyAuthenticationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: relyingParty.origins,
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
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    if (!verification.verified) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }

    const user = await this.repository.findUserById(passkey.userId);
    if (!user) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }

    const consumed = await this.repository.consumePasskeyChallenge(
      ceremony.id,
      new Date(),
    );
    if (!consumed) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    await this.repository.updatePasskeyCounter(
      passkey.id,
      verification.authenticationInfo.newCounter,
    );

    return this.sessions.issue(user, 'customer', clientContext);
  }

  /**
   * Step-up re-authentication of a signed-in user (account deletion): assertion options limited
   * to the user's own passkeys. The caller stores the challenge (bound to its own purpose and TTL)
   * and passes a matcher to [verifyReauthentication].
   */
  async reauthenticationOptions(
    userId: string,
  ): Promise<PublicKeyCredentialRequestOptionsJSON> {
    const passkeys = await this.repository.listPasskeys(userId);
    const rp = await this.relyingParty();
    return generateAuthenticationOptions({
      rpID: rp.rpID,
      userVerification: 'required',
      allowCredentials: passkeys.map((passkey) => ({
        id: passkey.credentialId,
        transports: passkey.transports,
      })),
    });
  }

  /** True only for a valid assertion over the expected challenge by one of [userId]'s passkeys. */
  async verifyReauthentication(
    userId: string,
    expectedChallenge: (challenge: string) => boolean,
    response: AuthenticationResponseJSON,
  ): Promise<boolean> {
    const passkey = await this.repository.findPasskeyByCredentialId(
      response.id,
    );
    if (!passkey || passkey.userId !== userId) {
      return false;
    }
    const relyingParty = await this.relyingParty();
    try {
      const verification = await verifyAuthenticationResponse({
        response,
        expectedChallenge,
        expectedOrigin: relyingParty.origins,
        expectedRPID: relyingParty.rpID,
        requireUserVerification: true,
        credential: {
          id: passkey.credentialId,
          publicKey: copyBytes(passkey.publicKey),
          counter: passkey.counter,
          transports: passkey.transports,
        },
      });
      if (!verification.verified) {
        return false;
      }
      await this.repository.updatePasskeyCounter(
        passkey.id,
        verification.authenticationInfo.newCounter,
      );
      return true;
    } catch {
      return false;
    }
  }

  async signupOptions(): Promise<
    Awaited<ReturnType<typeof generateRegistrationOptions>> & {
      ceremonyId: string;
    }
  > {
    await this.authMethods.assertEnabled('PASSKEY');
    const options = await generateRegistrationOptions({
      ...(await this.relyingParty()),
      userName: 'New DealGo account',
      userDisplayName: 'DealGo user',
      attestationType: 'none',
      authenticatorSelection: {
        residentKey: 'required',
        userVerification: 'required',
      },
    });
    const ceremony = await this.repository.replacePasskeyChallenge({
      userId: null,
      kind: 'REGISTRATION',
      challenge: options.challenge,
      expiresAt: new Date(Date.now() + PASSKEY_CHALLENGE_TTL_MS),
    });
    return { ...options, ceremonyId: ceremony.id };
  }

  async verifySignup(
    ceremonyId: string,
    response: RegistrationResponseJSON,
    clientContext?: SessionClientContext,
  ): Promise<SessionResult> {
    await this.authMethods.assertEnabled('PASSKEY');
    const ceremony = await this.repository.findPasskeyChallenge(ceremonyId);
    if (
      !ceremony ||
      ceremony.kind !== 'REGISTRATION' ||
      ceremony.userId !== null ||
      ceremony.consumedAt ||
      ceremony.expiresAt <= new Date()
    ) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    let verification: Awaited<ReturnType<typeof verifyRegistrationResponse>>;
    try {
      const rp = await this.relyingParty();
      verification = await verifyRegistrationResponse({
        response,
        expectedChallenge: ceremony.challenge,
        expectedOrigin: rp.origins,
        expectedRPID: rp.rpID,
        requireUserVerification: true,
      });
    } catch {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    if (!verification.verified) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    const consumed = await this.repository.consumePasskeyChallenge(
      ceremony.id,
      new Date(),
    );
    if (!consumed) {
      throw authError(
        401,
        'AUTH_PASSKEY_INVALID',
        'Passkey verification failed',
      );
    }
    const credential = verification.registrationInfo.credential;
    if (clientContext?.deviceId) {
      const maxLimit =
        (await this.platformSettings?.getNumber('MAX_ACCOUNTS_PER_DEVICE')) ??
        MAX_ACCOUNTS_PER_DEVICE;
      const regCount = await this.repository.countRegistrationsByDeviceId(
        clientContext.deviceId,
      );
      if (regCount >= maxLimit) {
        throw authError(
          429,
          'AUTH_DEVICE_REGISTRATION_LIMIT',
          'Thiết bị này đã vượt quá số lượng tài khoản được phép đăng ký',
        );
      }
    }
    try {
      const user = await this.repository.createPasskeyUser({
        credentialId: credential.id,
        publicKey: new Uint8Array(credential.publicKey),
        counter: credential.counter,
        transports: credential.transports ?? [],
        deviceType: verification.registrationInfo.credentialDeviceType,
        backedUp: verification.registrationInfo.credentialBackedUp,
      });
      if (clientContext?.deviceId) {
        await this.repository.recordDeviceRegistration({
          deviceId: clientContext.deviceId,
          userId: user.id,
          ipAddress: clientContext.ipAddress ?? null,
        });
      }
      return this.sessions.issue(user, 'customer', clientContext);
    } catch (error) {
      if (error instanceof UniqueConflictError) {
        throw authError(
          409,
          'AUTH_PASSKEY_EXISTS',
          'Passkey is already registered',
        );
      }
      throw error;
    }
  }

  /** Passkeys on the account for the security page (no key material). */
  async listForUser(userId: string) {
    const rows = await this.repository.listPasskeys(userId);
    return rows
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((row) => ({
        id: row.id,
        createdAt: row.createdAt.toISOString(),
        deviceType: row.deviceType,
        backedUp: row.backedUp,
        transports: row.transports,
      }));
  }

  /**
   * Removes a passkey. The last one cannot go when it is the only way to sign
   * in (no verified phone or email), so the account is never locked out.
   */
  async remove(userId: string, id: string): Promise<{ removed: true }> {
    const user = await this.repository.findUserById(userId);
    const passkeys = await this.repository.listPasskeys(userId);
    if (!user || !passkeys.some((p) => p.id === id)) {
      throw authError(404, 'AUTH_PASSKEY_NOT_FOUND', 'Passkey not found');
    }
    const hasOtherLogin = Boolean(user.phoneVerifiedAt || user.emailVerifiedAt);
    if (passkeys.length <= 1 && !hasOtherLogin) {
      throw authError(
        409,
        'AUTH_PASSKEY_LAST_CREDENTIAL',
        'The last sign-in method cannot be removed',
      );
    }
    await this.repository.deletePasskey(userId, id);
    return { removed: true };
  }

  private async requireVerifiedUser(userId: string) {
    const user = await this.repository.findUserById(userId);
    // Sign-in methods are independently toggleable (DEC-PROD-052): a verified phone, a verified
    // email or an existing passkey (passkey-only accounts) is enough to bind another passkey.
    const verified =
      user &&
      (user.phoneVerifiedAt ||
        user.emailVerifiedAt ||
        (await this.repository.listPasskeys(user.id)).length > 0);
    if (!user || !verified) {
      throw authError(403, 'FORBIDDEN', 'A verified account is required');
    }
    return user;
  }

  private async relyingParty(): Promise<{
    rpID: string;
    rpName: string;
    origins: string[];
  }> {
    let rpID = this.config.get('WEBAUTHN_RP_ID', { infer: true });
    let rpName = this.config.get('WEBAUTHN_RP_NAME', { infer: true });
    let originsStr = this.config.get('WEBAUTHN_ORIGIN', { infer: true });
    let androidCert = this.config.get('APP_LINKS_ANDROID_CERT_SHA256', {
      infer: true,
    });

    if (this.platformSettings) {
      rpID = (await this.platformSettings.getString('WEBAUTHN_RP_ID')) || rpID;
      rpName =
        (await this.platformSettings.getString('WEBAUTHN_RP_NAME')) || rpName;
      originsStr =
        (await this.platformSettings.getString('WEBAUTHN_ORIGIN')) ||
        originsStr;
      androidCert =
        (await this.platformSettings.getString(
          'APP_LINKS_ANDROID_CERT_SHA256',
        )) || androidCert;
    }

    const origins = webauthnExpectedOrigins(originsStr, {
      APP_LINKS_ANDROID_CERT_SHA256: androidCert,
    });
    if (!rpID || !rpName || origins.length === 0) {
      throw authError(
        500,
        'WEBAUTHN_NOT_CONFIGURED',
        'Passkey is not configured',
      );
    }
    return { rpID, rpName, origins };
  }
}

function copyBytes(value: Uint8Array): Uint8Array<ArrayBuffer> {
  const buffer = new ArrayBuffer(value.byteLength);
  const copy = new Uint8Array(buffer);
  copy.set(value);
  return copy;
}
