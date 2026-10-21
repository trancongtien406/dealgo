import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { IDENTITY_REPOSITORY, MAIL_SENDER, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { IdentityModule } from '../../../src/modules/identity/identity.module.js';
import { MockMailSender } from '../../../src/integrations/email/mail-sender.js';
import { PasswordHasher } from '../../../src/platform/security/password-hasher.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('identity http', () => {
  let app: INestApplication;
  let repository: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let mail: MockMailSender;

  beforeAll(async () => {
    repository = new MemoryIdentityRepository();
    sms = new MockSmsSender('test');
    mail = new MockMailSender('test');

    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              JWT_ACCESS_SECRET: 'test-access-secret',
              JWT_ACCESS_TTL_SECONDS: '900',
              WEBAUTHN_RP_ID: 'localhost',
              WEBAUTHN_RP_NAME: 'DealGo',
              WEBAUTHN_ORIGIN: 'http://localhost:3000',
              SMS_PROVIDER: 'mock',
              EMAIL_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        IdentityModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(MAIL_SENDER)
      .useValue(mail)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(repository)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();

    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('issues a session for a valid phone code and rejects a second verify', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '0901234567' })
      .expect(200);
    expect(await repository.findUserByPhone('+84901234567')).toBeNull();

    const code = sms.sent.at(-1)?.code;
    expect(code).toMatch(/^\d{6}$/);
    expect(JSON.stringify(created.body)).not.toContain(code);
    expect(created.body.data).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
    });

    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);

    expect(verified.body.data).toEqual({
      accessToken: expect.any(String),
      refreshToken: expect.any(String),
      expiresIn: 900,
      user: {
        id: expect.any(String),
        phone: '+84901234567',
        email: null,
      },
    });

    const replay = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(401);
    expect(replay.body.errorCode).toBe('AUTH_CODE_INVALID');

    const profile = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .expect(200);
    expect(profile.body.data).toMatchObject({
      id: verified.body.data.user.id,
      phone: '+84901234567',
      email: null,
      displayName: 'DealGo user',
      dateOfBirth: null,
      gender: null,
      avatarUrl: null,
      phoneVerifiedAt: expect.any(String),
      emailVerifiedAt: null,
      needsProfileSetup: true,
      grants: [{ role: 'CUSTOMER', status: 'ACTIVE' }],
    });

    const customerGrant = (await repository.listGrants(verified.body.data.user.id)).find(
      (grant) => grant.role === 'CUSTOMER',
    );
    await repository.updateGrantStatus(customerGrant!.id, 'SUSPENDED');
    await repository.insertGrant(verified.body.data.user.id, 'DRIVER', 'ACTIVE');
    const filtered = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .expect(200);
    expect(filtered.body.data.grants).toEqual([{ role: 'DRIVER', status: 'ACTIVE' }]);

    const options = await request(app.getHttpServer())
      .post('/v1/auth/passkeys/registration/options')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .expect(200);
    expect(options.body.data.challenge).toEqual(expect.any(String));
    expect(options.body.data.rp).toEqual({ id: 'localhost', name: 'DealGo' });
  });

  it('locks a phone challenge after five wrong codes', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84902222222' })
      .expect(200);
    const challengeId = created.body.data.challengeId as string;
    const realCode = sms.sent.at(-1)?.code ?? '';
    const wrongCode = realCode === '000000' ? '111111' : '000000';

    for (let attempt = 1; attempt <= 4; attempt += 1) {
      const response = await request(app.getHttpServer())
        .post(`/v1/auth/phone/challenges/${challengeId}/verify`)
        .send({ code: wrongCode })
        .expect(401);
      expect(response.body.errorCode).toBe('AUTH_CODE_INVALID');
    }

    const locked = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${challengeId}/verify`)
      .send({ code: wrongCode })
      .expect(429);
    expect(locked.body.errorCode).toBe('AUTH_CODE_LOCKED');
  });

  it('rotates refresh tokens and revokes the family when a rotated token is reused', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '0903333333' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);

    const firstRefresh = verified.body.data.refreshToken as string;
    const rotated = await request(app.getHttpServer())
      .post('/v1/auth/sessions/refresh')
      .send({ refreshToken: firstRefresh })
      .expect(200);
    expect(rotated.body.data.refreshToken).not.toBe(firstRefresh);
    expect(rotated.body.data.accessToken).toEqual(expect.any(String));

    const reused = await request(app.getHttpServer())
      .post('/v1/auth/sessions/refresh')
      .send({ refreshToken: firstRefresh })
      .expect(401);
    expect(reused.body.errorCode).toBe('AUTH_REFRESH_REUSED');

    const successor = await request(app.getHttpServer())
      .post('/v1/auth/sessions/refresh')
      .send({ refreshToken: rotated.body.data.refreshToken })
      .expect(401);
    expect(successor.body.errorCode).toBe('AUTH_REFRESH_REUSED');
  });

  it('caps SMS OTP sends per phone number (DEC-PROD-044)', async () => {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await request(app.getHttpServer())
        .post('/v1/auth/phone/challenges')
        .send({ phone: '+84909990001' })
        .expect(200);
    }
    // Same number written differently is still the same number.
    await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '0909990001' })
      .expect(429);
    await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84909990002' })
      .expect(200);
  });

  it('throttles Admin login per email, not per IP (DEC-PROD-044)', async () => {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      await request(app.getHttpServer())
        .post('/v1/ops/sessions')
        .send({ email: 'Brute@DealGo.test', password: `guess-${attempt}-password` })
        .expect(401);
    }
    await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: 'brute@dealgo.test', password: 'guess-final-password' })
      .expect(429);
    // Another operator behind the same website IP is not locked out.
    await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: 'someone-else@dealgo.test', password: 'whatever-password' })
      .expect(401);
  });

  it('rejects unknown and wrong ops passwords the same way and accepts the bootstrap operator', async () => {
    const unknown = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: 'missing@dealgo.test', password: OPS_PASSWORD })
      .expect(401);
    const wrong = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: 'wrong-password-1' })
      .expect(401);

    expect(unknown.status).toBe(wrong.status);
    expect(unknown.body.errorCode).toBe(wrong.body.errorCode);
    expect(unknown.body.errorCode).toBe('AUTH_INVALID_CREDENTIALS');
    expect(unknown.body.message).toBe(wrong.body.message);

    const loggedIn = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    expect(loggedIn.body.data.user.email).toBe(OPS_EMAIL);
    expect(loggedIn.body.data).not.toHaveProperty('password');

    const profile = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${loggedIn.body.data.accessToken}`)
      .expect(200);
    expect(profile.body.data.phoneVerifiedAt).toBeNull();
    expect(profile.body.data.grants).toEqual([{ role: 'OPS', status: 'ACTIVE' }]);

    const passkey = await request(app.getHttpServer())
      .post('/v1/auth/passkeys/registration/options')
      .set('Authorization', `Bearer ${loggedIn.body.data.accessToken}`)
      .expect(403);
    expect(passkey.body.errorCode).toBe('FORBIDDEN');
  });

  it('requires a bearer token for /v1/me', async () => {
    const response = await request(app.getHttpServer()).get('/v1/me').expect(401);
    expect(response.body).toMatchObject({
      success: false,
      statusCode: 401,
      errorCode: 'UNAUTHORIZED',
    });
  });

  it('patches profile fields, starts email verification, (avatar upload: avatar.http.spec)', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84907777777' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    const token = verified.body.data.accessToken as string;

    const patched = await request(app.getHttpServer())
      .patch('/v1/me')
      .set('Authorization', `Bearer ${token}`)
      .send({
        displayName: 'Le Thi C',
        gender: 'FEMALE',
        dateOfBirth: '1998-03-15T00:00:00.000Z',
        email: 'c@dealgo.test',
      })
      .expect(200);

    expect(patched.body.data).toMatchObject({
      displayName: 'Le Thi C',
      gender: 'FEMALE',
      dateOfBirth: '1998-03-15T00:00:00.000Z',
      email: null,
      needsProfileSetup: false,
      pendingEmailVerification: {
        verificationId: expect.any(String),
        expiresAt: expect.any(String),
      },
    });
    expect(mail.sent.at(-1)?.email).toBe('c@dealgo.test');

    const me = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(me.body.data.avatarUrl).toBeNull();
    expect(me.body.data.needsProfileSetup).toBe(false);
  });

  it('starts identifierless passkey sign-in and contact-less sign-up', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84908888888' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    const userId = verified.body.data.user.id as string;

    await repository.setEmailVerified(userId, 'passkey@dealgo.test', new Date());
    await repository.savePasskey({
      userId,
      credentialId: 'cred-email-1',
      publicKey: new Uint8Array([1, 2, 3, 4]),
      counter: 0,
      transports: ['internal'],
      deviceType: 'platform',
      backedUp: false,
    });

    const authentication = await request(app.getHttpServer())
      .post('/v1/auth/passkeys/authentication/options')
      .send({})
      .expect(200);
    expect(authentication.body.data.challenge).toEqual(expect.any(String));
    expect(authentication.body.data.ceremonyId).toEqual(expect.any(String));
    expect(authentication.body.data).not.toHaveProperty('allowCredentials');

    const signup = await request(app.getHttpServer())
      .post('/v1/auth/passkeys/signup/options')
      .send({})
      .expect(200);
    expect(signup.body.data.challenge).toEqual(expect.any(String));
    expect(signup.body.data.ceremonyId).toEqual(expect.any(String));
    expect(signup.body.data.authenticatorSelection).toMatchObject({
      residentKey: 'required',
      userVerification: 'required',
    });
  });

  it('confirms an email token and does not return it from the request', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84904444444' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);

    const requested = await request(app.getHttpServer())
      .post('/v1/auth/email/verifications')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .send({ email: 'rider@dealgo.test' })
      .expect(200);
    const token = mail.sent.at(-1)?.token;
    expect(token).toEqual(expect.any(String));
    expect(JSON.stringify(requested.body)).not.toContain(token);
    expect(requested.body.data).toEqual({
      verificationId: expect.any(String),
      expiresAt: expect.any(String),
    });

    await request(app.getHttpServer())
      .post(`/v1/auth/email/verifications/${requested.body.data.verificationId}/confirm`)
      .send({ token: 'not-the-real-token-value-here' })
      .expect(401);

    await request(app.getHttpServer())
      .post(`/v1/auth/email/verifications/${requested.body.data.verificationId}/confirm`)
      .send({ token })
      .expect(200);

    const profile = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .expect(200);
    expect(profile.body.data.email).toBe('rider@dealgo.test');
    expect(profile.body.data.emailVerifiedAt).toEqual(expect.any(String));
  });

  it('refuses the local ops bootstrap password in production', async () => {
    await expect(
      app.get(OpsAuthService).ensureOperator('ops@dealgo.test', 'change-me-dev-only', 'production'),
    ).rejects.toThrow(/change-me-dev-only/);
  });

  it('lists and requests role grants for a customer session and auto-activates in test', async () => {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84905555555' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    const token = verified.body.data.accessToken as string;

    const initial = await request(app.getHttpServer())
      .get('/v1/me/role-grants')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(initial.body.data).toEqual({
      grants: [{ id: expect.any(String), role: 'CUSTOMER', status: 'ACTIVE' }],
    });

    const requested = await request(app.getHttpServer())
      .post('/v1/me/role-grants')
      .set('Authorization', `Bearer ${token}`)
      .send({ role: 'CUSTOMER' })
      .expect(200);
    expect(requested.body.data).toEqual({
      id: expect.any(String),
      role: 'CUSTOMER',
      status: 'ACTIVE',
    });

    const driver = await request(app.getHttpServer())
      .post('/v1/me/role-grants')
      .set('Authorization', `Bearer ${token}`)
      .send({ role: 'DRIVER' })
      .expect(200);
    expect(driver.body.data.status).toBe('ACTIVE');

    const listed = await request(app.getHttpServer())
      .get('/v1/me/role-grants')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(listed.body.data.grants).toEqual(
      expect.arrayContaining([
        { id: requested.body.data.id, role: 'CUSTOMER', status: 'ACTIVE' },
        { id: driver.body.data.id, role: 'DRIVER', status: 'ACTIVE' },
      ]),
    );

    const profile = await request(app.getHttpServer())
      .get('/v1/me')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(profile.body.data.grants).toEqual(
      expect.arrayContaining([
        { role: 'CUSTOMER', status: 'ACTIVE' },
        { role: 'DRIVER', status: 'ACTIVE' },
      ]),
    );
  });

  it('requires auth for role grants and restricts ops review to operator sessions', async () => {
    await request(app.getHttpServer()).get('/v1/me/role-grants').expect(401);
    await request(app.getHttpServer())
      .post('/v1/me/role-grants')
      .send({ role: 'CUSTOMER' })
      .expect(401);

    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84906666666' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    const customerToken = verified.body.data.accessToken as string;
    const pending = await repository.insertGrant(verified.body.data.user.id, 'MERCHANT', 'PENDING');

    const customerDenied = await request(app.getHttpServer())
      .post(`/v1/ops/role-grants/${pending.id}/approve`)
      .set('Authorization', `Bearer ${customerToken}`)
      .expect(403);
    expect(customerDenied.body.errorCode).toBe('FORBIDDEN');

    const opsLogin = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    const opsToken = opsLogin.body.data.accessToken as string;

    const opsDenied = await request(app.getHttpServer())
      .get('/v1/me/role-grants')
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(403);
    expect(opsDenied.body.errorCode).toBe('FORBIDDEN');

    const approved = await request(app.getHttpServer())
      .post(`/v1/ops/role-grants/${pending.id}/approve`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(approved.body.data).toEqual({
      id: pending.id,
      role: 'MERCHANT',
      status: 'ACTIVE',
    });

    const otherPending = await repository.insertGrant(
      verified.body.data.user.id,
      'DRIVER',
      'PENDING',
    );
    const rejected = await request(app.getHttpServer())
      .post(`/v1/ops/role-grants/${otherPending.id}/reject`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(rejected.body.data.status).toBe('SUSPENDED');

    const invalidRole = await request(app.getHttpServer())
      .post('/v1/me/role-grants')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ role: 'OPS' })
      .expect(400);
    expect(invalidRole.body.errorCode).toBe('VALIDATION_ERROR');

    const reopen = await request(app.getHttpServer())
      .post('/v1/me/role-grants')
      .set('Authorization', `Bearer ${customerToken}`)
      .send({ role: 'DRIVER' })
      .expect(403);
    expect(reopen.body.errorCode).toBe('ROLE_GRANT_SUSPENDED');
  });

  it('signs up with email only after the emailed OTP is verified', async () => {
    const server = app.getHttpServer();
    const started = await request(server)
      .post('/v1/auth/email/register')
      .send({ email: 'Signup@DealGo.test', password: 'password123', displayName: 'Signup' })
      .expect(200);
    expect(started.body.data).toEqual({
      challengeId: expect.any(String),
      expiresAt: expect.any(String),
      resendAvailableAt: expect.any(String),
    });
    expect(await repository.findUserByEmail('signup@dealgo.test')).toBeNull();
    const code = mail.signupCodes.at(-1)!.code;
    expect(JSON.stringify(started.body)).not.toContain(code);

    const earlyLogin = await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'signup@dealgo.test', password: 'password123' })
      .expect(401);
    expect(earlyLogin.body.errorCode).toBe('AUTH_INVALID_CREDENTIALS');

    const cooldown = await request(server)
      .post(`/v1/auth/email/register/${started.body.data.challengeId}/resend`)
      .expect(429);
    expect(cooldown.body.errorCode).toBe('AUTH_OTP_RESEND_COOLDOWN');

    const wrong = await request(server)
      .post(`/v1/auth/email/register/${started.body.data.challengeId}/verify`)
      .send({ code: code === '000000' ? '111111' : '000000' })
      .expect(401);
    expect(wrong.body.errorCode).toBe('AUTH_CODE_INVALID');

    const verified = await request(server)
      .post(`/v1/auth/email/register/${started.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    expect(verified.body.data).toEqual({
      accessToken: expect.any(String),
      refreshToken: expect.any(String),
      expiresIn: 900,
      user: { id: expect.any(String), phone: null, email: 'signup@dealgo.test' },
    });
    const user = await repository.findUserByEmail('signup@dealgo.test');
    expect(user?.emailVerifiedAt).toBeInstanceOf(Date);
    expect(await repository.listGrants(user!.id)).toEqual([
      expect.objectContaining({ role: 'CUSTOMER', status: 'ACTIVE' }),
    ]);

    await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'signup@dealgo.test', password: 'password123' })
      .expect(200);

    const again = await request(server)
      .post('/v1/auth/email/register')
      .send({ email: 'signup@dealgo.test', password: 'other-password' })
      .expect(200);
    expect(Object.keys(again.body.data).sort()).toEqual(Object.keys(started.body.data).sort());
    expect(mail.signupAccountExists.at(-1)).toBe('signup@dealgo.test');

    await request(server)
      .post('/v1/auth/email/register/not-a-uuid/verify')
      .send({ code })
      .expect(400);
  });

  it('resets a forgotten password with an emailed 6-digit code (DEC-PROD-045)', async () => {
    const server = app.getHttpServer();
    const started = await request(server)
      .post('/v1/auth/email/register')
      .send({ email: 'forgot@dealgo.test', password: 'password123' })
      .expect(200);
    await request(server)
      .post(`/v1/auth/email/register/${started.body.data.challengeId}/verify`)
      .send({ code: mail.signupCodes.at(-1)!.code })
      .expect(200);

    const unknown = await request(server)
      .post('/v1/auth/email/password-resets')
      .send({ email: 'nobody-here@dealgo.test' })
      .expect(200);
    const sentBefore = mail.passwordResets.length;
    const real = await request(server)
      .post('/v1/auth/email/password-resets')
      .send({ email: 'Forgot@DealGo.test' })
      .expect(200);
    expect(Object.keys(real.body.data).sort()).toEqual(Object.keys(unknown.body.data).sort());
    expect(mail.passwordResets).toHaveLength(sentBefore + 1);
    const code = mail.passwordResets.at(-1)!.code;
    expect(JSON.stringify(real.body)).not.toContain(code);

    // The retired link-token body is rejected by validation.
    await request(server)
      .post(`/v1/auth/email/password-resets/${real.body.data.challengeId}/confirm`)
      .send({ token: 'x'.repeat(43), password: 'brand-new-password' })
      .expect(400);
    const cooldown = await request(server)
      .post(`/v1/auth/email/password-resets/${real.body.data.challengeId}/resend`)
      .expect(429);
    expect(cooldown.body.errorCode).toBe('AUTH_OTP_RESEND_COOLDOWN');
    const wrong = await request(server)
      .post(`/v1/auth/email/password-resets/${real.body.data.challengeId}/confirm`)
      .send({ code: code === '000000' ? '111111' : '000000', password: 'brand-new-password' })
      .expect(401);
    expect(wrong.body.errorCode).toBe('AUTH_CODE_INVALID');
    await request(server)
      .post(`/v1/auth/email/password-resets/${real.body.data.challengeId}/confirm`)
      .send({ code, password: 'brand-new-password' })
      .expect(200);
    await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'forgot@dealgo.test', password: 'brand-new-password' })
      .expect(200);
  });

  it('activates a never-verified email account with an OTP sent on login', async () => {
    const server = app.getHttpServer();
    const legacy = await repository.createUser({
      email: 'legacy@dealgo.test',
      phone: null,
      displayName: 'Legacy',
    });
    await repository.saveCustomerCredential(
      legacy.id,
      await app.get(PasswordHasher).hash('password123'),
    );
    const sentBefore = mail.signupCodes.length;

    const wrongPassword = await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'legacy@dealgo.test', password: 'wrong-password' })
      .expect(401);
    expect(wrongPassword.body).not.toHaveProperty('details');
    expect(mail.signupCodes).toHaveLength(sentBefore);

    const blocked = await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'legacy@dealgo.test', password: 'password123' })
      .expect(403);
    expect(blocked.body).toMatchObject({
      success: false,
      errorCode: 'AUTH_EMAIL_NOT_VERIFIED',
      details: {
        challengeId: expect.any(String),
        expiresAt: expect.any(String),
        resendAvailableAt: expect.any(String),
      },
    });
    const code = mail.signupCodes.at(-1)!.code;
    expect(JSON.stringify(blocked.body)).not.toContain(code);

    const verified = await request(server)
      .post(`/v1/auth/email/register/${blocked.body.details.challengeId}/verify`)
      .send({ code })
      .expect(200);
    expect(verified.body.data.user).toEqual({
      id: legacy.id,
      phone: null,
      email: 'legacy@dealgo.test',
    });
    expect((await repository.findUserById(legacy.id))?.emailVerifiedAt).toBeInstanceOf(Date);
    expect(await repository.listGrants(legacy.id)).toEqual([
      expect.objectContaining({ role: 'CUSTOMER', status: 'ACTIVE' }),
    ]);

    await request(server)
      .post('/v1/auth/email/login')
      .send({ email: 'legacy@dealgo.test', password: 'password123' })
      .expect(200);
  });
});
