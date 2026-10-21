import { randomUUID } from 'node:crypto';
import type { INestApplication } from '@nestjs/common';
import { DriverCardModule } from '../../../src/modules/driver-card/driver-card.module.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import type { PartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

const pickup = { lat: 16.0544, lng: 108.2022, label: 'Cầu Rồng' };
const dropoff = { lat: 16.0471, lng: 108.2068, label: 'Chợ Hàn' };

describe('driver card http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let serial = 0;

  beforeAll(async () => {
    harness = await createTestApp([DriverCardModule]);
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
      .set('Idempotency-Key', `card-create-${serial}`)
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(200);
    return created.body.data.id as string;
  }

  async function assign(customer: TestUser, driver: TestUser, rideId: string): Promise<void> {
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
      .set('Idempotency-Key', `card-select-${serial}`)
      .send({ offerId: offer.body.data.offers[0].id })
      .expect(200);
  }

  it('shows the real driver name and approved KYC vehicle to the ride customer only', async () => {
    const customer = await harness.login();
    const driver = await harness.login();
    const stranger = await harness.login();
    await harness.identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
    const application = await partners.upsertSubmit({
      id: randomUUID(),
      userId: driver.userId,
      role: 'DRIVER',
      metadata: { vehiclePlate: '43B1-678.90', vehicleType: 'Xe máy' },
      documents: [],
      now: new Date(),
    });
    await partners.review({
      id: application.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: stranger.userId,
      now: new Date(),
    });

    const rideId = await ride(customer);
    const early = await harness
      .http()
      .get(`/v1/rides/${rideId}/driver`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(404);
    expect(early.body.errorCode).toBe('DRIVER_NOT_ASSIGNED');

    const offered = await harness
      .http()
      .post(`/v1/rides/${rideId}/offers`)
      .set('Authorization', `Bearer ${driver.token}`)
      .send({ amountVnd: 30_000 })
      .expect(200);
    const offerId = offered.body.data.offers[0].id as string;
    const offerCard = await harness
      .http()
      .get(`/v1/rides/${rideId}/offers/${offerId}/driver`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(offerCard.body.data.vehicleType).toBe('Xe máy');
    await harness
      .http()
      .get(`/v1/rides/${rideId}/offers/${offerId}/driver`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .expect(404);

    await assign(customer, driver, rideId);
    const card = await harness
      .http()
      .get(`/v1/rides/${rideId}/driver`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(card.body.data).toMatchObject({
      driverId: driver.userId,
      vehiclePlate: '43B1-678.90',
      vehicleType: 'Xe máy',
      ratingAverage: null,
      ratingCount: 0,
    });
    expect(typeof card.body.data.displayName).toBe('string');

    const hidden = await harness
      .http()
      .get(`/v1/rides/${rideId}/driver`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .expect(404);
    expect(hidden.body.errorCode).toBe('RIDE_NOT_FOUND');
  });

  it('gives Admin a batch name / masked phone / approved vehicle lookup (ops only)', async () => {
    const customer = await harness.login();
    const driver = await harness.login();
    await harness.identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const partners = app.get<PartnerRepository>(PARTNER_REPOSITORY);
    const application = await partners.upsertSubmit({
      id: randomUUID(),
      userId: driver.userId,
      role: 'DRIVER',
      metadata: { vehiclePlate: '43C1-111.22', vehicleType: 'Xe máy' },
      documents: [],
      now: new Date(),
    });
    await partners.review({
      id: application.id,
      status: 'APPROVED',
      reason: null,
      reviewIssues: [],
      reviewedBy: customer.userId,
      now: new Date(),
    });
    await app.get(OpsAuthService).ensureOperator('ops-people@dealgo.test', 'correct-horse-battery', 'test');
    const ops = await harness
      .http()
      .post('/v1/ops/sessions')
      .send({ email: 'ops-people@dealgo.test', password: 'correct-horse-battery' })
      .expect(200);
    const opsToken = ops.body.data.accessToken as string;
    const unknown = randomUUID();
    // One assigned ride the customer then cancels: not held against the driver (DEC-PROD-035).
    const cancelledRide = await ride(customer);
    await assign(customer, driver, cancelledRide);
    const cancelled = await harness
      .http()
      .post(`/v1/rides/${cancelledRide}/cancel`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(200);
    expect(cancelled.body.data).toMatchObject({ status: 'CANCELLED', cancelledBy: 'CUSTOMER' });

    const res = await harness
      .http()
      .get(`/v1/ops/people?ids=${customer.userId},${driver.userId},${unknown}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    const rows = res.body.data as Array<Record<string, unknown>>;
    expect(rows).toHaveLength(2);
    const driverRow = rows.find((row) => row.id === driver.userId);
    expect(driverRow).toMatchObject({ vehiclePlate: '43C1-111.22', vehicleType: 'Xe máy' });
    expect(driverRow).toMatchObject({ completedJobs: 0, finishedJobs: 0, completionRate: null });
    const customerRow = rows.find((row) => row.id === customer.userId);
    expect(customerRow).toMatchObject({ vehiclePlate: null, vehicleType: null });
    expect(customerRow).toMatchObject({ completedJobs: 0, finishedJobs: 0, completionRate: null });
    expect(String(customerRow?.phoneMasked ?? '')).toContain('*');
    expect(JSON.stringify(rows)).not.toMatch(/"phone":/);

    await harness
      .http()
      .get(`/v1/ops/people?ids=not-a-uuid`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(400);
    await harness
      .http()
      .get(`/v1/ops/people?ids=${customer.userId}`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
  });

  it('hides unknown food orders and requires a session', async () => {
    const customer = await harness.login();
    await harness.http().get(`/v1/food/orders/${randomUUID()}/courier`).expect(401);
    const res = await harness
      .http()
      .get(`/v1/food/orders/${randomUUID()}/courier`)
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(404);
    expect(res.body.errorCode).toBe('FOOD_ORDER_NOT_FOUND');
  });
});
