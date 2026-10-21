import type { INestApplication } from '@nestjs/common';
import { InboxModule } from '../../../src/modules/communication/inbox/inbox.module.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { SupportTicketModule } from '../../../src/modules/support-ticket/support-ticket.module.js';
import { createTestApp, type TestUser } from '../../support/app-harness.js';
import { TINY_JPEG_BASE64, TINY_PDF_BASE64 } from '../../../src/platform/storage/testing.js';

function binary(res: NodeJS.ReadableStream & { setEncoding?: unknown }, done: (err: Error | null, body: Buffer) => void) {
  const chunks: Buffer[] = [];
  res.on('data', (chunk: Buffer) => chunks.push(chunk));
  res.on('end', () => done(null, Buffer.concat(chunks)));
}

const OPS_EMAIL = 'support-ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';
const pickup = { lat: 16.0544, lng: 108.2022, label: 'Cầu Rồng' };
const dropoff = { lat: 16.0471, lng: 108.2068, label: 'Chợ Hàn' };

describe('support tickets http', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;
  let opsToken: string;

  beforeAll(async () => {
    harness = await createTestApp([SupportTicketModule, InboxModule]);
    app = harness.app;
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
    const login = await harness
      .http()
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    opsToken = login.body.data.accessToken as string;
  });

  afterAll(async () => {
    await app.close();
  });

  function open(user: TestUser, body: Record<string, unknown> = {}) {
    return harness
      .http()
      .post('/v1/support/tickets')
      .set('Authorization', `Bearer ${user.token}`)
      .send({
        category: 'RIDE',
        subject: 'Cần hỗ trợ về phí chuyến đi',
        description: 'Có khoản phụ phí chưa rõ trong chuyến gần đây.',
        ...body,
      });
  }

  it('opens, lists and reads my own tickets; others get 404', async () => {
    const me = await harness.login();
    const stranger = await harness.login();
    const created = await open(me).expect(201);
    const ticket = created.body.data;
    expect(ticket.code).toMatch(/^DG-\d{6}-\d{4}$/);
    expect(ticket.status).toBe('OPEN');
    expect(ticket.awaitingRequester).toBe(false);
    expect(ticket.messages).toEqual([
      expect.objectContaining({ author: 'REQUESTER', body: 'Có khoản phụ phí chưa rõ trong chuyến gần đây.' }),
    ]);

    const list = await harness
      .http()
      .get('/v1/support/tickets?state=ACTIVE')
      .set('Authorization', `Bearer ${me.token}`)
      .expect(200);
    expect(list.body.data).toMatchObject({ total: 1, activeCount: 1, doneCount: 0 });
    expect(list.body.data.items[0]).toMatchObject({
      id: ticket.id,
      lastMessagePreview: 'Có khoản phụ phí chưa rõ trong chuyến gần đây.',
    });
    const done = await harness
      .http()
      .get('/v1/support/tickets?state=DONE')
      .set('Authorization', `Bearer ${me.token}`)
      .expect(200);
    expect(done.body.data.items).toEqual([]);

    await harness
      .http()
      .get(`/v1/support/tickets/${ticket.id}`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .expect(404);
    await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .send({ body: 'không phải của tôi' })
      .expect(404);
    await harness.http().get('/v1/support/tickets').expect(401);
  });

  it('stores attachments and serves them only to the requester and ops', async () => {
    const me = await harness.login();
    const stranger = await harness.login();
    const created = await open(me, {
      attachments: [{ label: 'hoa-don.jpg', contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 }],
    }).expect(201);
    const ticket = created.body.data;
    const first = ticket.messages[0];
    expect(first.attachments).toEqual([
      { index: 0, label: 'hoa-don.jpg', contentType: 'image/jpeg', sizeBytes: 8 },
    ]);
    const path = `/v1/support/tickets/${ticket.id}/messages/${first.id}/attachments/0`;
    const mine = await harness
      .http()
      .get(path)
      .set('Authorization', `Bearer ${me.token}`)
      .buffer(true)
      .parse(binary as never)
      .expect(200);
    expect(mine.headers['content-type']).toBe('image/jpeg');
    expect((mine.body as Buffer).toString('base64')).toBe(TINY_JPEG_BASE64);
    await harness.http().get(path).set('Authorization', `Bearer ${stranger.token}`).expect(404);
    await harness
      .http()
      .get(`/v1/ops/support-tickets/${ticket.id}/messages/${first.id}/attachments/0`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);

    const replied = await harness
      .http()
      .post(`/v1/ops/support-tickets/${ticket.id}/replies`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({
        body: 'Gửi bạn biên nhận hoàn tiền.',
        attachments: [{ label: 'bien-nhan.pdf', contentBase64: TINY_PDF_BASE64 }],
      })
      .expect(200);
    const staff = replied.body.data.messages.at(-1);
    expect(staff.attachments[0]).toMatchObject({ label: 'bien-nhan.pdf', contentType: 'application/pdf' });

    const svg = await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${me.token}`)
      .send({ body: 'Ảnh thêm', attachments: [{ contentBase64: Buffer.from('<svg></svg>').toString('base64') }] })
      .expect(415);
    expect(svg.body.errorCode).toBe('UPLOAD_TYPE_NOT_ALLOWED');
    await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${stranger.token}`)
      .send({ body: 'x', attachments: [{ contentBase64: TINY_JPEG_BASE64 }] })
      .expect(404);
    await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${me.token}`)
      .send({
        body: 'quá nhiều',
        attachments: Array.from({ length: 4 }, () => ({ contentBase64: TINY_JPEG_BASE64 })),
      })
      .expect(400);
  });

  it('links only rides the user took part in', async () => {
    const customer = await harness.login();
    const other = await harness.login();
    const ride = await harness
      .http()
      .post('/v1/rides')
      .set('Authorization', `Bearer ${customer.token}`)
      .set('Idempotency-Key', 'support-ride-1')
      .send({ pickup, dropoff, offeredFareVnd: 30_000 })
      .expect(200);
    const rideId = ride.body.data.id as string;

    const denied = await open(other, { relatedType: 'RIDE', relatedId: rideId }).expect(404);
    expect(denied.body.errorCode).toBe('SUPPORT_RELATED_NOT_FOUND');
    const linked = await open(customer, { relatedType: 'RIDE', relatedId: rideId }).expect(201);
    expect(linked.body.data).toMatchObject({ relatedType: 'RIDE', relatedId: rideId });
    await open(customer, { relatedType: 'RIDE' }).expect(400);
  });

  it('caps open tickets per user and rejects text over the setting', async () => {
    const me = await harness.login();
    for (let i = 0; i < 5; i += 1) {
      await open(me).expect(201);
    }
    const limited = await open(me).expect(409);
    expect(limited.body.errorCode).toBe('SUPPORT_TICKET_LIMIT_REACHED');

    const fresh = await harness.login();
    const safety = await open(fresh, { category: 'SAFETY' }).expect(201);
    expect(safety.body.data.priority).toBe('HIGH');
    const tooLong = await open(fresh, { description: 'x'.repeat(2001) }).expect(400);
    expect(tooLong.body.errorCode).toBe('SUPPORT_TEXT_TOO_LONG');
  });

  it('accepts the public form, normalizes the contact and caps it per day', async () => {
    const body = {
      role: 'CUSTOMER',
      category: 'PAYMENT',
      description: 'Tôi bị trừ tiền hai lần cho cùng một đơn.',
      contact: '0905 123 456',
      externalRef: 'FOOD-1234',
    };
    const bad = await harness
      .http()
      .post('/v1/public/support/tickets')
      .send({ ...body, contact: 'abc12' })
      .expect(400);
    expect(bad.body.errorCode).toBe('SUPPORT_CONTACT_INVALID');

    const first = await harness.http().post('/v1/public/support/tickets').send(body).expect(201);
    expect(Object.keys(first.body.data).sort()).toEqual(['code', 'createdAt']);
    await harness
      .http()
      .post('/v1/public/support/tickets')
      .send({ ...body, contact: '+84905123456' })
      .expect(201);
    await harness
      .http()
      .post('/v1/public/support/tickets')
      .send({ ...body, contact: '84 905 123 456' })
      .expect(201);
    const capped = await harness
      .http()
      .post('/v1/public/support/tickets')
      .send(body)
      .expect(429);
    expect(capped.body.errorCode).toBe('SUPPORT_CONTACT_LIMIT_REACHED');

    const list = await harness
      .http()
      .get(`/v1/ops/support-tickets?channel=WEB&q=${first.body.data.code}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .expect(200);
    expect(list.body.data.items).toHaveLength(1);
    expect(list.body.data.items[0]).toMatchObject({
      channel: 'WEB',
      contact: '0905123456',
      externalRef: 'FOOD-1234',
      requester: null,
      subject: 'Tôi bị trừ tiền hai lần cho cùng một đơn.',
    });
  });

  it('lets ops reply, resolve and close; the requester is notified and follows the rules', async () => {
    const me = await harness.login();
    const ticket = (await open(me).expect(201)).body.data;

    await harness
      .http()
      .get('/v1/ops/support-tickets')
      .set('Authorization', `Bearer ${me.token}`)
      .expect(403);

    const replied = await harness
      .http()
      .post(`/v1/ops/support-tickets/${ticket.id}/replies`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ body: 'Chào bạn! DealGo đã nhận yêu cầu và đang kiểm tra.' })
      .expect(200);
    expect(replied.body.data).toMatchObject({ status: 'IN_PROGRESS', awaitingRequester: true });
    expect(replied.body.data.requester).toMatchObject({ userId: me.userId });

    const mine = await harness
      .http()
      .get(`/v1/support/tickets/${ticket.id}`)
      .set('Authorization', `Bearer ${me.token}`)
      .expect(200);
    expect(mine.body.data.messages.map((m: { author: string }) => m.author)).toEqual([
      'REQUESTER',
      'STAFF',
    ]);
    expect(mine.body.data.messages[1]).not.toHaveProperty('authorUserId');

    const inbox = await harness
      .http()
      .get('/v1/me/notifications')
      .set('Authorization', `Bearer ${me.token}`)
      .expect(200);
    expect(inbox.body.data.items[0]).toMatchObject({
      category: 'SYSTEM',
      title: 'DealGo đã phản hồi yêu cầu hỗ trợ',
      data: { aggregateType: 'SupportTicket', aggregateId: ticket.id, status: 'IN_PROGRESS' },
    });

    await harness
      .http()
      .patch(`/v1/ops/support-tickets/${ticket.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ reason: 'không đổi gì' })
      .expect(400);
    const resolved = await harness
      .http()
      .patch(`/v1/ops/support-tickets/${ticket.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ status: 'RESOLVED', priority: 'HIGH', reason: 'Đã hoàn phụ phí' })
      .expect(200);
    expect(resolved.body.data).toMatchObject({ status: 'RESOLVED', priority: 'HIGH' });
    expect(resolved.body.data.resolvedAt).toEqual(expect.any(String));

    const reopened = await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${me.token}`)
      .send({ body: 'Mình vẫn chưa thấy tiền hoàn.' })
      .expect(200);
    expect(reopened.body.data).toMatchObject({
      status: 'IN_PROGRESS',
      resolvedAt: null,
      awaitingRequester: false,
    });

    await harness
      .http()
      .patch(`/v1/ops/support-tickets/${ticket.id}`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ status: 'CLOSED', reason: 'Khách xác nhận đã nhận tiền' })
      .expect(200);
    const closedReply = await harness
      .http()
      .post(`/v1/support/tickets/${ticket.id}/messages`)
      .set('Authorization', `Bearer ${me.token}`)
      .send({ body: 'thêm nữa' })
      .expect(409);
    expect(closedReply.body.errorCode).toBe('SUPPORT_TICKET_CLOSED');
    await harness
      .http()
      .post(`/v1/ops/support-tickets/${ticket.id}/replies`)
      .set('Authorization', `Bearer ${opsToken}`)
      .send({ body: 'thêm nữa' })
      .expect(409);

    const done = await harness
      .http()
      .get('/v1/support/tickets')
      .set('Authorization', `Bearer ${me.token}`)
      .expect(200);
    expect(done.body.data).toMatchObject({ activeCount: 0, doneCount: 1 });
  });
});
