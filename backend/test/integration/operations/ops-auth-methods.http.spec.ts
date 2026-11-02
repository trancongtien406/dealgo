import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { MemoryAuthMethodPolicyRepository } from '../../../src/modules/identity/auth-method.repository.js';
import {
  AUTH_METHOD_POLICY_REPOSITORY,
  IDENTITY_REPOSITORY,
  MAIL_SENDER,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockMailSender } from '../../../src/integrations/email/mail-sender.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { OpsModule } from '../../../src/modules/operations/ops.module.js';
import { AccountSettingsModule } from '../../../src/modules/account-settings/account-settings.module.js';

const OPS_EMAIL = 'ops-auth-methods@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('ops auth methods http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let policies: MemoryAuthMethodPolicyRepository;
  let sms: MockSmsSender;
  let mail: MockMailSender;
  let token: string;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    policies = new MemoryAuthMethodPolicyRepository();
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
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
        AccountSettingsModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(MAIL_SENDER)
      .useValue(mail)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(AUTH_METHOD_POLICY_REPOSITORY)
      .useValue(policies)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');

    const loggedIn = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    token = loggedIn.body.data.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  beforeEach(async () => {
    for (const method of ['PASSKEY', 'PHONE_SMS', 'EMAIL_LOGIN_IDENTIFIER'] as const) {
      await policies.setEnabled({
        method,
        enabled: true,
        updatedByUserId: '00000000-0000-0000-0000-000000000001',
        reason: 'test reset',
      });
    }
  });

  it('lists defaults enabled', async () => {
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/auth-methods')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);

    expect(listed.body.data).toEqual([
      expect.objectContaining({ method: 'PASSKEY', enabled: true }),
      expect.objectContaining({ method: 'PHONE_SMS', enabled: true }),
      expect.objectContaining({ method: 'EMAIL_LOGIN_IDENTIFIER', enabled: true }),
    ]);
  });

  it('patches disable and writes audit', async () => {
    const patched = await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/PASSKEY')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'security review' })
      .expect(200);
    expect(patched.body.data).toMatchObject({ method: 'PASSKEY', enabled: false });
    expect(policies.audits.at(-1)).toMatchObject({
      method: 'PASSKEY',
      enabled: false,
      reason: 'security review',
    });
  });

  it('refuses disabling the last enabled method', async () => {
    await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/PASSKEY')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'off passkey' })
      .expect(200);
    await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/EMAIL_LOGIN_IDENTIFIER')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'off email' })
      .expect(200);

    const refused = await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/PHONE_SMS')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'would lock all' })
      .expect(409);
    expect(refused.body.errorCode).toBe('AUTH_METHOD_LAST_ENABLED');
  });

  async function disable(method: string) {
    await request(app.getHttpServer())
      .patch(`/v1/ops/auth-methods/${method}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: `${method} off` })
      .expect(200);
  }

  /** Error body minus the per-request fields, to compare with an unknown route's answer. */
  function stable(body: Record<string, unknown>) {
    const { timestamp: _t, requestId: _r, ...rest } = body;
    return rest;
  }

  async function phoneSession(phone: string) {
    const customer = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${customer.body.data.challengeId}/verify`)
      .send({ code: sms.sent.at(-1)?.code })
      .expect(200);
    return verified.body.data.accessToken as string;
  }

  it('public methods list omits disabled methods and holds no admin fields', async () => {
    await disable('PHONE_SMS');
    await disable('EMAIL_LOGIN_IDENTIFIER');

    const listed = await request(app.getHttpServer()).get('/v1/auth/methods').expect(200);
    expect(listed.body.data).toEqual([{ method: 'PASSKEY' }]);

    const ops = await request(app.getHttpServer())
      .get('/v1/ops/auth-methods')
      .set('Authorization', `Bearer ${token}`)
      .expect(200);
    expect(ops.body.data).toHaveLength(3);
  });

  it('ops list stays admin-only', async () => {
    await request(app.getHttpServer()).get('/v1/ops/auth-methods').expect(401);
  });

  it('disabled phone endpoints answer like an unknown route, before throttling or validation, and send no SMS', async () => {
    await disable('PHONE_SMS');
    const sentBefore = sms.sent.length;
    const id = '00000000-0000-4000-8000-000000000000';

    for (const [path, body] of [
      ['/v1/auth/phone/challenges', { phone: '+84908880002' }],
      ['/v1/auth/phone/challenges', {}],
      [`/v1/auth/phone/challenges/${id}/verify`, { code: '123456' }],
      ['/v1/auth/phone/challenges/not-a-uuid/verify', {}],
    ] as const) {
      const refused = await request(app.getHttpServer()).post(path).send(body).expect(404);
      const unknown = await request(app.getHttpServer()).post(`${path}-x`).send(body).expect(404);
      expect(stable(refused.body)).toEqual({ ...stable(unknown.body), message: `Cannot POST ${path}`, path });
      expect(refused.body.errorCode).toBe('NOT_FOUND');
    }
    expect(sms.sent).toHaveLength(sentBefore);
  });

  it('disabled email endpoints answer 404 and send no email', async () => {
    const session = await phoneSession('+84908880003');
    await disable('EMAIL_LOGIN_IDENTIFIER');
    const id = '00000000-0000-4000-8000-000000000000';
    const mailsBefore = JSON.stringify(mail);

    for (const [path, body] of [
      ['/v1/auth/email/register', { email: 'x@dealgo.test', password: 'password123' }],
      [`/v1/auth/email/register/${id}/verify`, { code: '123456' }],
      [`/v1/auth/email/register/${id}/resend`, {}],
      ['/v1/auth/email/login', { email: 'x@dealgo.test', password: 'password123' }],
      ['/v1/auth/email/verifications', { email: 'x@dealgo.test' }],
      [`/v1/auth/email/verifications/${id}/confirm`, { code: '123456' }],
      ['/v1/auth/email/password-resets', { email: 'x@dealgo.test' }],
      [`/v1/auth/email/password-resets/${id}/resend`, {}],
      [`/v1/auth/email/password-resets/${id}/confirm`, { code: '123456', password: 'password123' }],
    ] as const) {
      const refused = await request(app.getHttpServer())
        .post(path)
        .set('Authorization', `Bearer ${session}`)
        .send(body)
        .expect(404);
      expect(refused.body).toMatchObject({ errorCode: 'NOT_FOUND', message: `Cannot POST ${path}` });
    }

    const profile = await request(app.getHttpServer())
      .patch('/v1/me')
      .set('Authorization', `Bearer ${session}`)
      .send({ email: 'x@dealgo.test' })
      .expect(400);
    expect(profile.body).toMatchObject({ errorCode: 'VALIDATION_ERROR', message: 'property email should not exist' });
    // The email password is part of the email method: changing it is refused the same way.
    const password = await request(app.getHttpServer())
      .post('/v1/me/password')
      .set('Authorization', `Bearer ${session}`)
      .send({ currentPassword: 'password123', newPassword: 'password456' })
      .expect(404);
    expect(password.body).toMatchObject({ errorCode: 'NOT_FOUND', message: 'Cannot POST /v1/me/password' });
    expect(JSON.stringify(mail)).toBe(mailsBefore);
  });

  it('disabled passkey endpoints answer 404, even with a session', async () => {
    const session = await phoneSession('+84908880004');
    await disable('PASSKEY');

    for (const path of [
      '/v1/auth/passkeys/registration/options',
      '/v1/auth/passkeys/registration/verify',
      '/v1/auth/passkeys/authentication/options',
      '/v1/auth/passkeys/authentication/verify',
      '/v1/auth/passkeys/signup/options',
      '/v1/auth/passkeys/signup/verify',
    ]) {
      const refused = await request(app.getHttpServer())
        .post(path)
        .set('Authorization', `Bearer ${session}`)
        .send({})
        .expect(404);
      expect(refused.body).toMatchObject({ errorCode: 'NOT_FOUND', message: `Cannot POST ${path}` });
    }
    // Without a session the answer is the same 404, not 401.
    await request(app.getHttpServer()).post('/v1/auth/passkeys/registration/options').expect(404);
  });
});
