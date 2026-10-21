import type { INestApplication } from '@nestjs/common';
import { RatingModule } from '../../../src/modules/rating/rating.module.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

describe('ratings http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let alice: TestUser;

  beforeAll(async () => {
    harness = await createTestApp([RatingModule]);
    app = harness.app;
    alice = await harness.login();
  });

  afterAll(async () => {
    await app.close();
  });

  it('requires a customer session', async () => {
    await harness.http().post('/v1/ratings').send({}).expect(401);
  });

  it('validates stars, tags and subject', async () => {
    const res = await harness
      .http()
      .post('/v1/ratings')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ subjectType: 'RIDE', subjectId: 'nope', driverStars: 9, tags: ['GREAT'] })
      .expect(400);
    expect(res.body.errorCode).toBeDefined();
  });

  it('hides unknown rides as 404', async () => {
    const id = '00000000-0000-4000-8000-00000000f00d';
    const res = await harness
      .http()
      .post('/v1/ratings')
      .set('Authorization', `Bearer ${alice.token}`)
      .send({ subjectType: 'RIDE', subjectId: id, driverStars: 5 })
      .expect(404);
    expect(res.body.errorCode).toBe('RATING_SUBJECT_NOT_FOUND');
    await harness
      .http()
      .get(`/v1/ratings/FOOD_ORDER/${id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(404);
  });

  it('serves store summaries to app sessions and validates ids', async () => {
    const id = '00000000-0000-4000-8000-00000000abcd';
    await harness.http().get(`/v1/ratings/stores?ids=${id}`).expect(401);
    const ok = await harness
      .http()
      .get(`/v1/ratings/stores?ids=${id},${id}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(ok.body.data).toEqual([{ storeId: id, count: 0, average: null }]);
    await harness
      .http()
      .get('/v1/ratings/stores?ids=nope')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
    const tooMany = Array.from(
      { length: 51 },
      (_, i) => `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
    ).join(',');
    await harness
      .http()
      .get(`/v1/ratings/stores?ids=${tooMany}`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
  });

  it('serves empty store reviews and validates the store id', async () => {
    const id = '00000000-0000-4000-8000-00000000abce';
    const res = await harness
      .http()
      .get(`/v1/ratings/stores/${id}/reviews`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(res.body.data).toEqual({ summary: { storeId: id, count: 0, average: null }, items: [] });
    await harness
      .http()
      .get('/v1/ratings/stores/nope/reviews')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
  });
});
