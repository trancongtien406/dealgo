import type { INestApplication } from '@nestjs/common';
import { InboxModule } from '../../../src/modules/communication/inbox/inbox.module.js';
import { INBOX_REPOSITORY } from '../../../src/modules/communication/inbox/inbox.constants.js';
import type { InboxRepository } from '../../../src/modules/communication/inbox/inbox.repository.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';

describe('notification inbox http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let alice: TestUser;
  let bob: TestUser;

  beforeAll(async () => {
    harness = await createTestApp([InboxModule]);
    app = harness.app;
    alice = await harness.login();
    bob = await harness.login();
    const inbox = app.get<InboxRepository>(INBOX_REPOSITORY);
    await inbox.createMany([
      { userId: alice.userId, category: 'FOOD', title: 'Đơn đã giao', body: 'x', sourceEventKey: 'a1' },
      { userId: alice.userId, category: 'PROMOTION', title: 'Ưu đãi', body: 'y', sourceEventKey: 'a2' },
      { userId: bob.userId, category: 'RIDE', title: 'Bob', body: 'z', sourceEventKey: 'b1' },
    ]);
  });

  afterAll(async () => {
    await app.close();
  });

  it('requires a session', async () => {
    await harness.http().get('/v1/me/notifications').expect(401);
  });

  it('lists, marks one read, and marks all read for the owner only', async () => {
    const listed = await harness
      .http()
      .get('/v1/me/notifications?limit=10')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(listed.body.data.total).toBe(2);
    expect(listed.body.data.unreadCount).toBe(2);
    const first = listed.body.data.items[0];

    const bobsList = await harness
      .http()
      .get('/v1/me/notifications')
      .set('Authorization', `Bearer ${bob.token}`)
      .expect(200);
    const bobsId = bobsList.body.data.items[0].id;
    await harness
      .http()
      .post(`/v1/me/notifications/${bobsId}/read`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(404);

    const read = await harness
      .http()
      .post(`/v1/me/notifications/${first.id}/read`)
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(read.body.data.read).toBe(true);

    const all = await harness
      .http()
      .post('/v1/me/notifications/read-all')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(200);
    expect(all.body.data.updated).toBe(1);
  });

  it('validates query params', async () => {
    await harness
      .http()
      .get('/v1/me/notifications?limit=500')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
    await harness
      .http()
      .get('/v1/me/notifications?category=NOPE')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
    await harness
      .http()
      .post('/v1/me/notifications/not-a-uuid/read')
      .set('Authorization', `Bearer ${alice.token}`)
      .expect(400);
  });
});
