import type { INestApplication } from '@nestjs/common';
import { DriverHistoryModule } from '../../../src/modules/driver-history/driver-history.module.js';
import { createTestApp } from '../../support/app-harness.js';

describe('driver history http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;

  beforeAll(async () => {
    harness = await createTestApp([DriverHistoryModule]);
    app = harness.app;
  });

  afterAll(async () => {
    await app.close();
  });

  it('requires a session and an active driver role', async () => {
    await harness.http().get('/v1/driver/history').expect(401);
    const customer = await harness.login();
    const res = await harness
      .http()
      .get('/v1/driver/history/summary')
      .set('Authorization', `Bearer ${customer.token}`)
      .expect(403);
    expect(res.body.errorCode).toBe('ROLE_NOT_ACTIVE');
  });

  it('returns an empty first page and validates the query', async () => {
    const driver = await harness.login();
    await harness.identity.insertGrant(driver.userId, 'DRIVER', 'ACTIVE');
    const auth = `Bearer ${driver.token}`;
    const page = await harness.http().get('/v1/driver/history').set('Authorization', auth).expect(200);
    expect(page.body.data).toEqual({ items: [], nextCursor: null });
    const summary = await harness
      .http()
      .get('/v1/driver/history/summary')
      .set('Authorization', auth)
      .expect(200);
    expect(summary.body.data.days).toHaveLength(7);
    expect(summary.body.data.week.earningsVnd).toBe(0);
    await harness.http().get('/v1/driver/history?kind=BUS').set('Authorization', auth).expect(400);
    await harness.http().get('/v1/driver/history?limit=99').set('Authorization', auth).expect(400);
    const bad = await harness
      .http()
      .get('/v1/driver/history?cursor=zzz')
      .set('Authorization', auth)
      .expect(400);
    expect(bad.body.errorCode).toBe('DRIVER_HISTORY_CURSOR_INVALID');
  });
});
