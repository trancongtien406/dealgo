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
import { FoodModule } from '../../../src/modules/food-order/food.module.js';
import { FOOD_REPOSITORY } from '../../../src/modules/food-order/food.constants.js';
import { MemoryFoodRepository } from '../../../src/modules/food-order/food.repository.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { LEDGER_REPOSITORY } from '../../../src/modules/ledger/ledger.constants.js';
import { MemoryLedgerRepository } from '../../../src/modules/ledger/ledger.repository.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { RIDE_CLOCK, RIDE_REPOSITORY, type RideClock } from '../../../src/modules/ride/ride.constants.js';
import { RideModule } from '../../../src/modules/ride/ride.module.js';
import { MemoryRideRepository } from '../../../src/modules/ride/ride.repository.js';
import { ChatModule } from '../../../src/modules/communication/chat/chat.module.js';
import { CHAT_REPOSITORY } from '../../../src/modules/communication/chat/chat.constants.js';
import { MemoryChatRepository } from '../../../src/modules/communication/chat/chat.repository.js';

const CLOCK_START = new Date('2026-10-14T12:00:00.000Z');
const pickup = { lat: 10.776889, lng: 106.700806, label: 'District 1' };
const dropoff = { lat: 10.823099, lng: 106.629664, label: 'Airport' };

class ManualClock implements RideClock {
  constructor(private current: Date) {}
  now(): Date {
    return this.current;
  }
}

describe('transaction chat http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let sms: MockSmsSender;
  let phoneSerial = 500;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    sms = new MockSmsSender('test');
    const clock = new ManualClock(CLOCK_START);

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
              PUSH_PROVIDER: 'mock',
              PARTNER_ELIGIBILITY_BYPASS: 'true',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        RideModule,
        FoodModule,
        ChatModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(RIDE_REPOSITORY)
      .useValue(new MemoryRideRepository())
      .overrideProvider(FOOD_REPOSITORY)
      .useValue(new MemoryFoodRepository())
      .overrideProvider(CHAT_REPOSITORY)
      .useValue(new MemoryChatRepository())
      .overrideProvider(LEDGER_REPOSITORY)
      .useValue(new MemoryLedgerRepository())
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(new MemoryPartnerRepository())
      .overrideProvider(RIDE_CLOCK)
      .useValue(clock)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  async function login(): Promise<{ token: string; userId: string }> {
    phoneSerial += 1;
    const phone = `091${String(phoneSerial).padStart(7, '0')}`;
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

  it('allows ride participants to post and list text messages without phone fields', async () => {
    const customer = await login();
    const stranger = await login();
    const created = await request(app.getHttpServer())
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'chat-ride-1')
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(200);
    const rideId = created.body.data.id as string;

    const posted = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/messages`)
      .set('Authorization', `Bearer ${customer.token}`)
      .send({ body: 'I am at the lobby' })
      .expect(200);
    expect(posted.body.data.body).toBe('I am at the lobby');
    expect(posted.body.data.senderUserId).toBe(customer.userId);
    expect(posted.body.data).not.toHaveProperty('phone');

    const listed = await request(app.getHttpServer())
      .get(`/v1/rides/${rideId}/messages`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(listed.body.data.items).toHaveLength(1);
    expect(listed.body.data.items[0]).not.toHaveProperty('phone');

    const denied = await request(app.getHttpServer())
      .post(`/v1/rides/${rideId}/messages`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .send({ body: 'hello' });
    expect(denied.status).toBe(403);
    expect(denied.body.errorCode).toBe('CHAT_FORBIDDEN');
  });
});
