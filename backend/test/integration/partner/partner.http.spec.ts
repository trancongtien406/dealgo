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
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { PartnerModule } from '../../../src/modules/partner/partner.module.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('partner application http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let partners: MemoryPartnerRepository;
  let sms: MockSmsSender;
  let phoneSerial = 700;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    partners = new MemoryPartnerRepository();
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
              KYC_STORAGE_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PartnerModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(partners)
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

  it('submits KYC, lists for ops, approves to ACTIVE grant, rejects to SUSPENDED', async () => {
    const driver = await login('+84907' + String(phoneSerial++).padStart(5, '0'));
    const submitted = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({
        role: 'DRIVER',
        metadata: { fullName: 'Nguyen Van A', licenseNumber: 'B2-123' },
        documents: [{ label: 'id-front.jpg', contentType: 'image/jpeg' }],
      })
      .expect(200);

    expect(submitted.body.data).toMatchObject({
      role: 'DRIVER',
      status: 'SUBMITTED',
      metadata: { fullName: 'Nguyen Van A', licenseNumber: 'B2-123' },
    });
    expect(submitted.body.data.documents[0].key).toMatch(/^mock:\/\//);

    const mine = await request(app.getHttpServer())
      .get('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(mine.body.data.applications).toHaveLength(1);

    const ops = await opsLogin();
    const queue = await request(app.getHttpServer())
      .get('/v1/ops/partner-applications')
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(queue.body.data.applications.some((row: { id: string }) => row.id === submitted.body.data.id)).toBe(
      true,
    );

    const single = await request(app.getHttpServer())
      .get(`/v1/ops/partner-applications/${submitted.body.data.id}`)
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(single.body.data.id).toBe(submitted.body.data.id);

    const approved = await request(app.getHttpServer())
      .post(`/v1/ops/partner-applications/${submitted.body.data.id}/approve`)
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(approved.body.data.status).toBe('APPROVED');
    expect(approved.body.data.reviewedBy).toBeTruthy();
    expect(approved.body.data.reviewedAt).toBeTruthy();

    const grants = await identity.listGrants(driver.userId);
    expect(grants.find((grant) => grant.role === 'DRIVER')?.status).toBe('ACTIVE');

    const merchant = await login('+84907' + String(phoneSerial++).padStart(5, '0'));
    const merchantApp = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ role: 'MERCHANT', metadata: { shopName: 'Bun Bo' } })
      .expect(200);

    const rejected = await request(app.getHttpServer())
      .post(`/v1/ops/partner-applications/${merchantApp.body.data.id}/reject`)
      .set('Authorization', `Bearer ${ops.token}`)
      .send({ reason: 'Incomplete KYB documents' })
      .expect(200);
    expect(rejected.body.data).toMatchObject({
      status: 'REJECTED',
      reason: 'Incomplete KYB documents',
    });
    const merchantGrants = await identity.listGrants(merchant.userId);
    expect(merchantGrants.find((grant) => grant.role === 'MERCHANT')?.status).toBe('SUSPENDED');
  });

  async function login(phone: string): Promise<{ token: string; userId: string }> {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return {
      token: verified.body.data.accessToken as string,
      userId: verified.body.data.user.id as string,
    };
  }

  async function opsLogin(): Promise<{ token: string }> {
    const response = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    return { token: response.body.data.accessToken as string };
  }
});
