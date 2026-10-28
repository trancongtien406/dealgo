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
import { IntegrationsAdminModule } from '../../../src/modules/integrations-admin/integrations-admin.module.js';
import { INTEGRATIONS_FETCH } from '../../../src/modules/integrations-admin/integrations-admin.service.js';
import { INTEGRATION_SETTINGS_REPOSITORY } from '../../../src/platform/integration-settings/integration-settings.constants.js';
import { MemoryIntegrationSettingsRepository } from '../../../src/platform/integration-settings/integration-settings.repository.js';

const OPS_EMAIL = 'ops-integrations@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';
const SMTP_SECRET = 'app-password-under-test';
const PK = 'pk.public-token-under-test-1234';
const GOOGLE = 'AIza-google-key-under-test-9876';

describe('ops integrations http (email + map keys)', () => {
  let app: INestApplication;
  let policies: MemoryAuthMethodPolicyRepository;
  let settingsRepo: MemoryIntegrationSettingsRepository;
  let mail: MockMailSender;
  let token: string;
  const fetched: string[] = [];

  beforeAll(async () => {
    policies = new MemoryAuthMethodPolicyRepository();
    settingsRepo = new MemoryIntegrationSettingsRepository();
    mail = new MockMailSender('test');
    const fakeFetch = async (url: string) => {
      fetched.push(url);
      const body = url.includes('api.mapbox.com/tokens') ? { code: 'TokenValid' } : { status: 'REQUEST_DENIED' };
      return { ok: true, status: 200, json: async () => body };
    };

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
              SECRETS_ENCRYPTION_KEY: Buffer.alloc(32, 7).toString('base64'),
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        OpsModule,
        IntegrationsAdminModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(new MockSmsSender('test'))
      .overrideProvider(MAIL_SENDER)
      .useValue(mail)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(new MemoryIdentityRepository())
      .overrideProvider(AUTH_METHOD_POLICY_REPOSITORY)
      .useValue(policies)
      .overrideProvider(INTEGRATION_SETTINGS_REPOSITORY)
      .useValue(settingsRepo)
      .overrideProvider(INTEGRATIONS_FETCH)
      .useValue(fakeFetch)
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

  const http = () => request(app.getHttpServer());
  const auth = { Authorization: '' };
  beforeEach(() => {
    auth.Authorization = `Bearer ${token}`;
  });

  it('requires an operator session', async () => {
    await http().get('/v1/ops/integrations/email').expect(401);
  });

  it('shows the effective email config with secrets masked', async () => {
    const res = await http().get('/v1/ops/integrations/email').set(auth).expect(200);
    expect(res.body.data).toMatchObject({
      canStoreSecrets: true,
      provider: 'mock',
      providers: ['smtp', 'ses', 'disabled'],
      smtp: { host: 'smtp.gmail.com', port: 587, passwordSet: false },
      status: { configured: true, verified: true },
      webhookPath: '/v1/webhooks/ses',
    });
  });

  it('rejects invalid values and refuses an unusable provider while email login is on', async () => {
    await http().put('/v1/ops/integrations/email').set(auth).send({ provider: 'pigeon', reason: 'thử' }).expect(400);
    await http()
      .put('/v1/ops/integrations/email')
      .set(auth)
      .send({ fromAddress: 'not-an-email', reason: 'thử địa chỉ' })
      .expect(400);
    const refused = await http()
      .put('/v1/ops/integrations/email')
      .set(auth)
      .send({ provider: 'disabled', reason: 'tắt email' })
      .expect(409);
    expect(refused.body.error?.errorCode ?? refused.body.errorCode).toBe('EMAIL_LOGIN_NEEDS_PROVIDER');
  });

  it('stores Gmail SMTP credentials encrypted, never echoes them, and a passing test verifies them', async () => {
    const saved = await http()
      .put('/v1/ops/integrations/email')
      .set(auth)
      .send({
        provider: 'smtp',
        fromAddress: 'no-reply@dealgo.test',
        smtpUser: 'sender@dealgo.test',
        smtpPassword: SMTP_SECRET,
        reason: 'chuyển sang Gmail SMTP',
      })
      .expect(200);
    expect(JSON.stringify(saved.body)).not.toContain(SMTP_SECRET);
    expect(saved.body.data).toMatchObject({
      provider: 'smtp',
      smtp: { passwordSet: true, user: 'sender@dealgo.test' },
      status: { configured: true, verified: false },
    });
    expect(saved.body.data.sources.smtpPassword).toBe('admin');
    const row = await settingsRepo.find('EMAIL');
    expect(row?.secretsCiphertext).toBeTruthy();
    expect(row?.secretsCiphertext).not.toContain(SMTP_SECRET);
    expect(settingsRepo.audits.at(-1)).toMatchObject({
      action: 'INTEGRATION_SETTING_UPDATE',
      reason: 'chuyển sang Gmail SMTP',
      metadata: { secrets: { smtpPassword: 'set' } },
    });

    await http()
      .post('/v1/ops/integrations/email/test')
      .set(auth)
      .send({ to: 'bad', reason: 'gửi thử' })
      .expect(400);
    const tested = await http()
      .post('/v1/ops/integrations/email/test')
      .set(auth)
      .send({ to: 'owner@dealgo.test', reason: 'gửi thử' })
      .expect(200);
    expect(tested.body.data).toMatchObject({ ok: true, error: null, view: { status: { verified: true } } });
    expect(mail.testEmails.at(-1)).toBe('owner@dealgo.test');

    // Changing a credential invalidates the passed test.
    const changed = await http()
      .put('/v1/ops/integrations/email')
      .set(auth)
      .send({ smtpPassword: 'another-app-password', reason: 'đổi mật khẩu ứng dụng' })
      .expect(200);
    expect(changed.body.data.status.verified).toBe(false);
  });

  it('manages map keys: pk.* only for the public token, masked view, public client config, key test', async () => {
    await http()
      .put('/v1/ops/integrations/maps')
      .set(auth)
      .send({ mapboxPublicToken: 'sk.secret', reason: 'đặt token' })
      .expect(400);
    const saved = await http()
      .put('/v1/ops/integrations/maps')
      .set(auth)
      .send({ mapboxPublicToken: PK, googleMapsApiKey: GOOGLE, reason: 'đặt key bản đồ' })
      .expect(200);
    expect(JSON.stringify(saved.body)).not.toContain(GOOGLE);
    expect(saved.body.data.keys).toEqual([
      { field: 'mapboxPublicToken', set: true, source: 'admin', hint: '…1234' },
      { field: 'mapboxServerToken', set: false, source: 'unset', hint: null },
      { field: 'googleMapsApiKey', set: true, source: 'admin', hint: '…9876' },
    ]);

    const pub = await http().get('/v1/public/client-config').expect(200);
    expect(pub.body.data).toEqual({ mapboxPublicToken: PK });

    const tested = await http().post('/v1/ops/integrations/maps/test').set(auth).send({ reason: 'thử key' }).expect(200);
    expect(tested.body.data.results).toEqual([
      { field: 'mapboxPublicToken', ok: true, detail: 'TokenValid' },
      { field: 'mapboxServerToken', ok: false, detail: 'unset' },
      { field: 'googleMapsApiKey', ok: false, detail: 'REQUEST_DENIED' },
    ]);
    expect(fetched.some((u) => u.startsWith('https://api.mapbox.com/tokens/v2'))).toBe(true);

    const cleared = await http()
      .put('/v1/ops/integrations/maps')
      .set(auth)
      .send({ googleMapsApiKey: null, reason: 'gỡ key Google' })
      .expect(200);
    expect(cleared.body.data.keys[2]).toMatchObject({ set: false, source: 'unset' });
  });
});
