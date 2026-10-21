import type { INestApplication } from '@nestjs/common';
import { PlacesModule } from '../../../src/modules/places/places.module.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

describe('places http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let alice: TestUser;

  beforeAll(async () => {
    harness = await createTestApp([PlacesModule]);
    app = harness.app;
    alice = await harness.login();
  });

  afterAll(async () => {
    await app.close();
  });

  const search = (query: string) =>
    harness
      .http()
      .get(`/v1/places/search?${query}`)
      .set('Authorization', `Bearer ${alice.token}`);

  it('requires a session', async () => {
    await harness.http().get('/v1/places/search?q=cho').expect(401);
  });

  it('validates the query', async () => {
    await search('q=a').expect(400);
    await search(`q=${'x'.repeat(121)}`).expect(400);
    await search('q=cho&limit=50').expect(400);
  });

  it('returns provider results with coordinates', async () => {
    const res = await search(
      `q=${encodeURIComponent('cầu rồng')}&limit=3`,
    ).expect(200);
    expect(res.body.data.available).toBe(true);
    expect(res.body.data.items[0]).toMatchObject({
      name: 'Cầu Rồng',
      provider: 'mock',
    });
    expect(typeof res.body.data.items[0].lat).toBe('number');
    const none = await search('q=khongtimthay').expect(200);
    expect(none.body.data.items).toEqual([]);
  });

  it('reverse geocodes a GPS fix and validates coordinates', async () => {
    const reverse = (query: string) =>
      harness
        .http()
        .get(`/v1/places/reverse?${query}`)
        .set('Authorization', `Bearer ${alice.token}`);
    const res = await reverse('lat=16.061&lng=108.2275').expect(200);
    expect(res.body.data.place).toMatchObject({ name: 'Gần Cầu Rồng' });
    await reverse('lat=200&lng=108').expect(400);
    await reverse('lat=16').expect(400);
  });
});
