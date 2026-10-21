import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import {
  IDENTITY_REPOSITORY,
  SMS_SENDER,
} from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { PROMOTION_REPOSITORY } from '../../../src/modules/promotion/promotion.constants.js';
import { PromotionModule } from '../../../src/modules/promotion/promotion.module.js';
import { MemoryPromotionRepository } from '../../../src/modules/promotion/promotion.repository.js';
import { INITIAL_PROMOTION_SEED } from '../../../src/modules/promotion/promotion.seed.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('promotion http', () => {
  let app: INestApplication;
  let sms: MockSmsSender;

  beforeAll(async () => {
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
              SMS_PROVIDER: 'mock',
              EMAIL_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PromotionModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(new MemoryIdentityRepository())
      .overrideProvider(PROMOTION_REPOSITORY)
      .useValue(new MemoryPromotionRepository(INITIAL_PROMOTION_SEED))
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    await app
      .get(OpsAuthService)
      .ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  async function customerToken(): Promise<string> {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone: '+84907777001' })
      .expect(200);
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code: sms.sent.at(-1)?.code })
      .expect(200);
    return verified.body.data.accessToken as string;
  }

  it('requires a customer session to validate a voucher', async () => {
    const body = {
      voucherCode: 'DEALGO20K',
      serviceType: 'FOOD',
      orderAmount: 100_000,
    };
    await request(app.getHttpServer())
      .post('/v1/promotions/validate')
      .send(body)
      .expect(401);

    const opsLogin = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    await request(app.getHttpServer())
      .post('/v1/promotions/validate')
      .set('Authorization', `Bearer ${opsLogin.body.data.accessToken}`)
      .send(body)
      .expect(403);

    const token = await customerToken();
    const validated = await request(app.getHttpServer())
      .post('/v1/promotions/validate')
      .set('Authorization', `Bearer ${token}`)
      .send(body)
      .expect(200);
    expect(validated.body.data).toMatchObject({
      valid: true,
      discountAmount: 20_000,
      finalAmount: 80_000,
    });
  });

  it('restricts campaign management to operator sessions', async () => {
    await request(app.getHttpServer()).get('/v1/ops/promotions').expect(401);
    const opsLogin = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    const listed = await request(app.getHttpServer())
      .get('/v1/ops/promotions?status=active&limit=5')
      .set('Authorization', `Bearer ${opsLogin.body.data.accessToken}`)
      .expect(200);
    expect(
      listed.body.data.items.every(
        (item: { status: string }) => item.status === 'ACTIVE',
      ),
    ).toBe(true);
    await request(app.getHttpServer())
      .get('/v1/ops/promotions/not-a-uuid')
      .set('Authorization', `Bearer ${opsLogin.body.data.accessToken}`)
      .expect(400);
  });
});
