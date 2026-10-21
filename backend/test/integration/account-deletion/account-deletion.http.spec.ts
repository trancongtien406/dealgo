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
import { PasswordHasher } from '../../../src/platform/security/password-hasher.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { MemoryPlatformSettingsRepository } from '../../../src/platform/settings/platform-settings.repository.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { IdentityModule } from '../../../src/modules/identity/identity.module.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { AccountDeletionModule } from '../../../src/modules/account-deletion/account-deletion.module.js';
import { AccountDeletionService } from '../../../src/modules/account-deletion/account-deletion.service.js';
import {
  ACCOUNT_DELETION_REPOSITORY,
  DELETED_USER_DISPLAY_NAME,
  MemoryAccountDeletionRepository,
} from '../../../src/modules/account-deletion/account-deletion.repository.js';

const OPS = { email: 'ops@dealgo.test', password: 'ops-password-123' };
const DAY = 24 * 60 * 60 * 1000;

describe('S027 account deletion (DEC-PROD-037)', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let deletion: MemoryAccountDeletionRepository;
  let sms: MockSmsSender;
  let opsToken: string;

  const http = () => request(app.getHttpServer());

  async function phoneLogin(phone: string, status: number) {
    const created = await http().post('/v1/auth/phone/challenges').send({ phone }).expect(200);
    const code = sms.sent.at(-1)!.code;
    return http()
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(status);
  }

  async function signedIn(phone: string) {
    const res = await phoneLogin(phone, 200);
    return {
      token: res.body.data.accessToken as string,
      refresh: res.body.data.refreshToken as string,
      userId: res.body.data.user.id as string,
    };
  }

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    deletion = new MemoryAccountDeletionRepository(identity);
    sms = new MockSmsSender('test');
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
              SMS_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        IdentityModule,
        AccountDeletionModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(ACCOUNT_DELETION_REPOSITORY)
      .useValue(deletion)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(new MemoryPlatformSettingsRepository())
      .compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    await app.get(OpsAuthService).ensureOperator(OPS.email, OPS.password, 'test');
    const ops = await http().post('/v1/ops/sessions').send(OPS).expect(200);
    opsToken = ops.body.data.accessToken;
  });

  afterAll(async () => {
    await app.close();
  });

  it('OTP re-auth → soft-delete + sessions revoked → Ops restore → purge after grace', async () => {
    const phone = '0907000001';
    const user = await signedIn(phone);
    const auth = { Authorization: `Bearer ${user.token}` };

    const overview = await http().get('/v1/me/account-deletion').set(auth).expect(200);
    expect(overview.body.data).toMatchObject({
      status: 'NONE',
      graceDays: 7,
      method: 'PHONE_OTP',
      blockers: [],
      purgeAfter: null,
    });
    expect(overview.body.data.phoneMasked).not.toContain('7000001');

    const started = await http().post('/v1/me/account-deletion').set(auth).expect(201);
    expect(started.body.data).toMatchObject({ method: 'PHONE_OTP', graceDays: 7 });
    const requestId = started.body.data.requestId as string;
    const code = sms.sent.at(-1)!.code;
    expect(JSON.stringify(started.body)).not.toContain(code);

    const wrong = await http()
      .post(`/v1/me/account-deletion/${requestId}/confirm`)
      .set(auth)
      .send({ code: code === '000000' ? '111111' : '000000' })
      .expect(401);
    expect(wrong.body.errorCode).toBe('AUTH_CODE_INVALID');

    const confirmed = await http()
      .post(`/v1/me/account-deletion/${requestId}/confirm`)
      .set(auth)
      .send({ code })
      .expect(200);
    expect(confirmed.body.data).toMatchObject({ status: 'SCHEDULED', graceDays: 7 });
    const purgeAfter = new Date(confirmed.body.data.purgeAfter).getTime();
    expect(purgeAfter - Date.now()).toBeGreaterThan(6.9 * DAY);

    // Every session is gone, refresh is dead and signing in again is refused.
    await http().get('/v1/me/account-deletion').set(auth).expect(401);
    await http().post('/v1/auth/sessions/refresh').send({ refreshToken: user.refresh }).expect(401);
    const relogin = await phoneLogin(phone, 403);
    expect(relogin.body.errorCode).toBe('ACCOUNT_DELETED');

    // Admin sees the status and can restore inside the grace period (audited).
    const view = await http()
      .get(`/v1/ops/customers/${user.userId}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(view.body.data.deletion).toMatchObject({ status: 'SCHEDULED', purgedAt: null });
    await http()
      .post(`/v1/ops/users/${user.userId}/account-deletion/cancel`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ reason: 'Khách gọi hotline xin khôi phục' })
      .expect(200);
    expect(deletion.audits.at(-1)).toMatchObject({
      action: 'ACCOUNT_DELETION_CANCEL',
      entityId: user.userId,
    });
    const back = await signedIn(phone);
    expect(back.userId).toBe(user.userId);

    // Delete again; the purge worker anonymizes once the grace period is over.
    const again = await http()
      .post('/v1/me/account-deletion')
      .set('Authorization', `Bearer ${back.token}`)
      .expect(201);
    await http()
      .post(`/v1/me/account-deletion/${again.body.data.requestId}/confirm`)
      .set('Authorization', `Bearer ${back.token}`)
      .send({ code: sms.sent.at(-1)!.code })
      .expect(200);
    const service = app.get(AccountDeletionService);
    expect(await service.purgeDue(new Date())).toBe(0);
    expect(await service.purgeDue(new Date(Date.now() + 8 * DAY))).toBe(1);

    const purged = await identity.findUserById(user.userId);
    expect(purged).toMatchObject({
      phone: null,
      email: null,
      displayName: DELETED_USER_DISPLAY_NAME,
      avatarUrl: null,
    });
    const purgedView = await http()
      .get(`/v1/ops/customers/${user.userId}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(purgedView.body.data.deletion.status).toBe('PURGED');
    // Too late to restore; the phone number is free for a brand-new account.
    await http()
      .post(`/v1/ops/users/${user.userId}/account-deletion/cancel`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ reason: 'too late' })
      .expect(409);
    const fresh = await signedIn(phone);
    expect(fresh.userId).not.toBe(user.userId);
  });

  it('blocks deletion while a job is open or COD fees are unsettled', async () => {
    const user = await signedIn('0907000002');
    const auth = { Authorization: `Bearer ${user.token}` };

    deletion.setBlockers(user.userId, [{ code: 'ACTIVE_RIDE', count: 1 }]);
    const blocked = await http().post('/v1/me/account-deletion').set(auth).expect(409);
    expect(blocked.body.errorCode).toBe('ACCOUNT_DELETION_BLOCKED');
    expect(blocked.body.details.blockers).toEqual([{ code: 'ACTIVE_RIDE', count: 1 }]);

    // A blocker that appears between request and confirm is caught at confirm too.
    deletion.setBlockers(user.userId, []);
    const started = await http().post('/v1/me/account-deletion').set(auth).expect(201);
    deletion.setDriverFee(user.userId, 12_000);
    const late = await http()
      .post(`/v1/me/account-deletion/${started.body.data.requestId}/confirm`)
      .set(auth)
      .send({ code: sms.sent.at(-1)!.code })
      .expect(409);
    expect(late.body.details.blockers).toEqual([{ code: 'UNSETTLED_COD', amountVnd: 12_000 }]);

    // Ops records the cash settlement (audited); nothing left to settle afterwards.
    const ops = { Authorization: `Bearer ${opsToken}` };
    const balance = await http().get(`/v1/ops/users/${user.userId}/fee-balance`).set(ops).expect(200);
    expect(balance.body.data).toEqual({ amountVnd: 12_000, settledThrough: null });
    const settled = await http()
      .post(`/v1/ops/users/${user.userId}/fee-settlements`)
      .set(ops)
      .send({ reason: 'Tài xế nộp tiền mặt tại văn phòng' })
      .expect(201);
    expect(settled.body.data.amountVnd).toBe(12_000);
    const again = await http()
      .post(`/v1/ops/users/${user.userId}/fee-settlements`)
      .set(ops)
      .send({ reason: 'twice' })
      .expect(409);
    expect(again.body.errorCode).toBe('DRIVER_FEE_NOTHING_OUTSTANDING');

    const restart = await http().post('/v1/me/account-deletion').set(auth).expect(201);
    await http()
      .post(`/v1/me/account-deletion/${restart.body.data.requestId}/confirm`)
      .set(auth)
      .send({ code: sms.sent.at(-1)!.code })
      .expect(200);
    // The superseded request cannot be confirmed any more.
    await http()
      .post(`/v1/me/account-deletion/${started.body.data.requestId}/confirm`)
      .set(auth)
      .send({ code: '123456' })
      .expect(401);
  });

  it('uses the account password when there is no verified phone, and locks after 5 misses', async () => {
    const hasher = app.get(PasswordHasher);
    const email = 'pw-only@dealgo.test';
    await identity.createEmailPasswordUser({
      email,
      displayName: 'Pw Only',
      passwordHash: await hasher.hash('correct-horse-1'),
      verifiedAt: new Date(),
    });
    const login = await http()
      .post('/v1/auth/email/login')
      .send({ email, password: 'correct-horse-1' })
      .expect(200);
    const auth = { Authorization: `Bearer ${login.body.data.accessToken}` };

    const started = await http().post('/v1/me/account-deletion').set(auth).expect(201);
    expect(started.body.data).toMatchObject({ method: 'PASSWORD', phoneMasked: null });
    const id = started.body.data.requestId as string;
    for (let i = 0; i < 4; i += 1) {
      const miss = await http()
        .post(`/v1/me/account-deletion/${id}/confirm`)
        .set(auth)
        .send({ password: 'wrong-password' })
        .expect(401);
      expect(miss.body.errorCode).toBe('AUTH_PASSWORD_INVALID');
    }
    await http()
      .post(`/v1/me/account-deletion/${id}/confirm`)
      .set(auth)
      .send({ password: 'wrong-password' })
      .expect(429);
    await http()
      .post(`/v1/me/account-deletion/${id}/confirm`)
      .set(auth)
      .send({ password: 'correct-horse-1' })
      .expect(429);

    const retry = await http().post('/v1/me/account-deletion').set(auth).expect(201);
    await http()
      .post(`/v1/me/account-deletion/${retry.body.data.requestId}/confirm`)
      .set(auth)
      .send({ password: 'correct-horse-1' })
      .expect(200);
    const relogin = await http()
      .post('/v1/auth/email/login')
      .send({ email, password: 'correct-horse-1' })
      .expect(403);
    expect(relogin.body.errorCode).toBe('ACCOUNT_DELETED');
  });

  it('refuses for staff accounts and for ops channel tokens', async () => {
    await http()
      .get('/v1/me/account-deletion')
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(403);
    const user = await signedIn('0907000003');
    await http()
      .post(`/v1/ops/users/${user.userId}/account-deletion/cancel`)
      .set('Authorization', `Bearer ${user.token}`)
      .send({ reason: 'not ops' })
      .expect(403);
  });
});
