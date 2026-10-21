import type { INestApplication } from '@nestjs/common';
import { RideShareModule } from '../../../src/modules/ride-share/ride-share.module.js';
import { RIDE_SHARE_VIEW_LIMIT_PER_MIN } from '../../../src/modules/ride-share/share-view-throttler.guard.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

const pickup = { lat: 16.0544, lng: 108.2022, label: 'Cầu Rồng' };
const dropoff = { lat: 16.0471, lng: 108.2068, label: 'Chợ Hàn' };

describe('ride share link http (DEC-PROD-021)', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let serial = 0;

  beforeAll(async () => {
    harness = await createTestApp([RideShareModule]);
    app = harness.app;
  });

  afterAll(async () => {
    await app.close();
  });

  async function ride(customer: TestUser): Promise<string> {
    serial += 1;
    const created = await harness
      .http()
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `share-create-${serial}`)
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(200);
    return created.body.data.id as string;
  }

  it('shares an ongoing trip with a masked driver and hides it from strangers', async () => {
    const customer = await harness.login();
    const driver = await harness.login();
    const stranger = await harness.login();
    await harness.identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    await harness.identity.updateUserProfile(driver.userId, { displayName: 'Nguyễn Văn Bình' });

    const rideId = await ride(customer);
    const tooEarly = await harness
      .http()
      .post(`/v1/rides/${rideId}/share-link`)
      .set('Authorization', `Bearer ${customer.token}`);
    expect(tooEarly.status).toBe(409);
    expect(tooEarly.body.errorCode).toBe('RIDE_SHARE_NOT_ACTIVE');

    const offer = await harness
      .http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 30_000 })
      .expect(200);
    await harness
      .http()
      .post(`/v1/rides/${rideId}/selection`)
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', `share-select-${serial}`)
      .send({ offerId: offer.body.data.offers[0].id })
      .expect(200);

    await harness
      .http()
      .post(`/v1/rides/${rideId}/share-link`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .expect(404);

    const created = await harness
      .http()
      .post(`/v1/rides/${rideId}/share-link`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(201);
    const { url, token } = created.body.data as { url: string; token: string };
    expect(url).toBe(`http://localhost:3000/chia-se-chuyen/${token}`);
    expect(url).not.toContain(rideId);

    const view = await harness.http().get(`/v1/public/ride-shares/${token}`).expect(200);
    expect(view.body.data).toMatchObject({
      status: 'ASSIGNED',
      pickupLabel: 'Cầu Rồng',
      dropoffLabel: 'Chợ Hàn',
      driver: { name: 'Bình N.' },
    });
    expect(JSON.stringify(view.body.data)).not.toContain(customer.userId);
    expect(JSON.stringify(view.body.data)).not.toContain(driver.userId);

    await harness.http().get('/v1/public/ride-shares/not-a-real-token-123456').expect(404);
    await harness.http().get('/v1/public/ride-shares/x').expect(404);

    for (let i = 0; i < 4; i += 1) {
      await harness
        .http()
        .post(`/v1/rides/${rideId}/share-link`)
        .set('Authorization', `Bearer ${customer.token}`)
        .expect(201);
    }
    const capped = await harness
      .http()
      .post(`/v1/rides/${rideId}/share-link`)
      .set('Authorization', `Bearer ${customer.token}`);
    expect(capped.status).toBe(429);
    expect(capped.body.errorCode).toBe('RIDE_SHARE_LIMIT');

    // Views are throttled per token (the website server is one IP for every viewer).
    for (let i = 1; i < RIDE_SHARE_VIEW_LIMIT_PER_MIN; i += 1) {
      await harness.http().get(`/v1/public/ride-shares/${token}`).expect(200);
    }
    await harness.http().get(`/v1/public/ride-shares/${token}`).expect(429);
    await harness.http().get('/v1/public/ride-shares/another-unknown-token-42').expect(404);
  });
});
