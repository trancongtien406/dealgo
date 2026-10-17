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
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
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

  it('blocks passkey registration options when PASSKEY disabled', async () => {
    await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/PASSKEY')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'passkey off' })
      .expect(200);

    const customer = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84908880001' })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${customer.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);

    const passkeyBlocked = await request(app.getHttpServer())
      .post('/v1/auth/passkeys/registration/options')
      .set('Authorization', `Bearer ${verified.body.data.accessToken}`)
      .expect(403);
    expect(passkeyBlocked.body.errorCode).toBe('AUTH_METHOD_DISABLED');
  });

  it('blocks phone challenge when PHONE_SMS disabled', async () => {
    await request(app.getHttpServer())
      .patch('/v1/ops/auth-methods/PHONE_SMS')
      .set('Authorization', `Bearer ${token}`)
      .send({ enabled: false, reason: 'sms off' })
      .expect(200);

    const phoneBlocked = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84908880002' })
      .expect(403);
    expect(phoneBlocked.body.errorCode).toBe('AUTH_METHOD_DISABLED');
  });
});
