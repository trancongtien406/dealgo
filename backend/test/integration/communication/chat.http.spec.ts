import { seedMotorbikeOnDriverGrant } from '../food-order/motorbike-drivers.js';
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
import { CatalogModule } from '../../../src/modules/catalog/catalog.module.js';
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
import { PLATFORM_SETTINGS_REPOSITORY } from '../../../src/platform/settings/platform-settings.constants.js';
import { negotiationMechanicsSettings } from '../../support/settings-fixture.js';
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
              FOOD_MIN_DELIVERY_VND: '5000',
              FOOD_MAX_DELIVERY_VND: '100000',
              FOOD_DELIVERY_VND_PER_KM: '3000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        RideModule,
        FoodModule,
        CatalogModule,
        ChatModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(PLATFORM_SETTINGS_REPOSITORY)
      .useValue(await negotiationMechanicsSettings())
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
    seedMotorbikeOnDriverGrant(identity, app);
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
      .send({ pickup, dropoff, offeredFareVnd: 30_000, vehicleClassCode: 'MOTORBIKE'})
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

  const http = () => request(app.getHttpServer());
  const foodDropoff = { lat: 16.047079, lng: 108.20623, label: 'Hải Châu' };

  async function loginPhone(phone: string): Promise<{ token: string; userId: string }> {
    const created = await http().post('/v1/auth/phone/challenges').send({ phone }).expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await http()
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return { token: verified.body.data.accessToken as string, userId: verified.body.data.user.id as string };
  }

  async function onlineDriver(): Promise<{ token: string; userId: string }> {
    const d = await login();
    await identity.insertGrant(d.userId, 'DRIVER', 'ACTIVE');
    await http()
      .post('/v1/me/presence')
      .set('Authorization', `Bearer ${d.token}`)
      .send({ online: true, lat: foodDropoff.lat + 0.002, lng: foodDropoff.lng + 0.002 })
      .expect(200);
    return d;
  }

  async function readyOrder(customer: { token: string }, merchant: { token: string }, key: string) {
    const catalog = await http()
      .get('/v1/food/stores')
      .query({ search: 'Bún Bò Huế', limit: 20 })
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    const storeId = (catalog.body.data.items as { id: string; name: string }[]).find((s) => s.name === 'Bún Bò Huế')!.id;
    const detail = await http().get(`/v1/food/stores/${storeId}`).set('Authorization', `Bearer ${customer.token}`).expect(200);
    const placed = await http()
      .post('/v1/food/orders')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', key)
      .send({ storeId, items: [{ itemId: detail.body.data.items[0].id, quantity: 1 }], dropoff: foodDropoff, deliveryFareVnd: 15_000 })
      .expect(200);
    const orderId = placed.body.data.id as string;
    await http().post(`/v1/food/orders/${orderId}/accept`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    await http().post(`/v1/food/orders/${orderId}/ready`).set('Authorization', `Bearer ${merchant.token}`).expect(200);
    return orderId;
  }

  const say = (token: string, path: string, body: string) =>
    http().post(path).set('Authorization', `Bearer ${token}`).send({ body });
  const read = (token: string, path: string) => http().get(path).set('Authorization', `Bearer ${token}`);

  it('food: customer↔shop and customer↔driver are separate threads, each reaching only its counterpart', async () => {
    const customer = await login();
    const merchant = await loginPhone('0901110001');
    const otherDriver = await onlineDriver();
    const driver = await onlineDriver();
    const orderId = await readyOrder(customer, merchant, 'chat-food-1');
    const driverPath = `/v1/food/orders/${orderId}/messages`;
    const shopPath = `/v1/food/orders/${orderId}/shop-messages`;

    // Shop thread works before any driver; the driver thread waits for assignment.
    expect((await say(customer.token, shopPath, 'Cho ít cay nhé')).status).toBe(200);
    expect((await say(merchant.token, shopPath, 'Dạ quán nhận')).status).toBe(200);
    const early = await say(customer.token, driverPath, 'alo tài xế');
    expect(early.status).toBe(409);
    expect(early.body.errorCode).toBe('CHAT_NO_COUNTERPART');
    // A READY order is visible to every nearby driver; that is not chat access.
    expect((await read(otherDriver.token, driverPath)).status).toBe(403);

    await http().post(`/v1/food/orders/${orderId}/claim`).set('Authorization', `Bearer ${driver.token}`).expect(200);
    expect((await say(customer.token, driverPath, 'Giao cổng sau giúp em')).status).toBe(200);
    expect((await say(driver.token, driverPath, 'Ok anh')).status).toBe(200);

    const shopForCustomer = await read(customer.token, shopPath).expect(200);
    expect(shopForCustomer.body.data.items.map((m: { body: string }) => m.body)).toEqual(['Cho ít cay nhé', 'Dạ quán nhận']);
    const driverForCustomer = await read(customer.token, driverPath).expect(200);
    expect(driverForCustomer.body.data.items.map((m: { body: string }) => m.body)).toEqual(['Giao cổng sau giúp em', 'Ok anh']);
    expect(shopForCustomer.body.data.items[0].threadId).not.toBe(driverForCustomer.body.data.items[0].threadId);

    // Merchant never reads/writes the driver thread; the driver never touches the shop thread.
    expect((await read(merchant.token, driverPath)).status).toBe(403);
    expect((await say(merchant.token, driverPath, 'x')).status).toBe(403);
    expect((await read(driver.token, shopPath)).status).toBe(403);
    expect((await say(driver.token, shopPath, 'x')).status).toBe(403);
    expect((await read(otherDriver.token, driverPath)).status).toBe(403);
    const merchantView = await read(merchant.token, shopPath).expect(200);
    expect(merchantView.body.data.items).toHaveLength(2);
  });
});
