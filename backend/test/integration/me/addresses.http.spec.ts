import type { INestApplication } from '@nestjs/common';
import { AddressBookModule } from '../../../src/modules/address-book/address-book.module.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

describe('address book http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let alice: TestUser;
  let bob: TestUser;

  beforeAll(async () => {
    harness = await createTestApp([AddressBookModule]);
    app = harness.app;
    alice = await harness.login();
    bob = await harness.login();
  });

  afterAll(async () => {
    await app.close();
  });

  const as = (user: TestUser) => ({
    list: () => harness.http().get('/v1/me/addresses').set('Authorization', `Bearer ${user.token}`),
    create: (body: object) =>
      harness.http().post('/v1/me/addresses').set('Authorization', `Bearer ${user.token}`).send(body),
    update: (id: string, body: object) =>
      harness
        .http()
        .patch(`/v1/me/addresses/${id}`)
        .set('Authorization', `Bearer ${user.token}`)
        .send(body),
    remove: (id: string) =>
      harness.http().delete(`/v1/me/addresses/${id}`).set('Authorization', `Bearer ${user.token}`),
  });

  it('requires a session', async () => {
    await harness.http().get('/v1/me/addresses').expect(401);
  });

  it('validates the body', async () => {
    const res = await as(alice).create({ kind: 'CASTLE', label: '', addressLine: 'x' }).expect(400);
    expect(res.body.errorCode).toBeDefined();
    await as(alice).create({ kind: 'OTHER', label: 'Gym', addressLine: '12 Lê Duẩn', lat: 16 }).expect(400);
  });

  it('runs the full CRUD with default and HOME/WORK rules, scoped to the owner', async () => {
    const home = await as(alice)
      .create({ kind: 'HOME', label: ' Nhà ', addressLine: '12 Lê Duẩn, Hải Châu', lat: 16.07, lng: 108.22 })
      .expect(200);
    expect(home.body.data).toMatchObject({ label: 'Nhà', isDefault: true, lat: 16.07 });

    const dupHome = await as(alice).create({ kind: 'HOME', label: 'Nhà 2', addressLine: '1 Trần Phú' });
    expect(dupHome.status).toBe(409);
    expect(dupHome.body.errorCode).toBe('ADDRESS_KIND_TAKEN');

    const work = await as(alice)
      .create({ kind: 'WORK', label: 'Công ty', addressLine: '99 Nguyễn Văn Linh', isDefault: true })
      .expect(200);
    expect(work.body.data.isDefault).toBe(true);
    let listed = await as(alice).list().expect(200);
    expect(listed.body.data.items.map((a: { label: string }) => a.label)).toEqual(['Công ty', 'Nhà']);
    expect(listed.body.data.items.filter((a: { isDefault: boolean }) => a.isDefault)).toHaveLength(1);

    await as(bob).update(home.body.data.id, { label: 'hijack' }).expect(404);
    await as(bob).remove(home.body.data.id).expect(404);
    expect((await as(bob).list().expect(200)).body.data.items).toEqual([]);

    const renamed = await as(alice)
      .update(home.body.data.id, { label: 'Nhà riêng', note: 'Cổng xanh' })
      .expect(200);
    expect(renamed.body.data).toMatchObject({ label: 'Nhà riêng', note: 'Cổng xanh', isDefault: false });

    await as(alice).remove(work.body.data.id).expect(200);
    listed = await as(alice).list().expect(200);
    expect(listed.body.data.items).toHaveLength(1);
    expect(listed.body.data.items[0]).toMatchObject({ id: home.body.data.id, isDefault: true });
  });

  it('caps the book at 20 addresses', async () => {
    const carol = await harness.login();
    for (let i = 0; i < 20; i += 1) {
      await as(carol).create({ kind: 'OTHER', label: `Nơi ${i}`, addressLine: `${i} Bạch Đằng` }).expect(200);
    }
    const full = await as(carol).create({ kind: 'OTHER', label: 'Thêm', addressLine: '21 Bạch Đằng' });
    expect(full.status).toBe(409);
    expect(full.body.errorCode).toBe('ADDRESS_LIMIT_REACHED');
  });
});
