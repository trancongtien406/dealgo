import { ConflictException, NotFoundException } from '@nestjs/common';
import { beforeEach, describe, expect, it } from 'vitest';
import { MemoryNotificationRepository } from './notification.repository.js';
import { OPS_CMS_SEEDS } from './notification.seed.js';
import { NotificationService } from './notification.service.js';

const ACTOR = '11111111-1111-4111-8111-111111111111';
const FUTURE = () => new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString();

describe('NotificationService', () => {
  let repo: MemoryNotificationRepository;
  let service: NotificationService;

  beforeEach(() => {
    repo = new MemoryNotificationRepository();
    service = new NotificationService(repo);
  });

  async function newDraft(overrides: Record<string, unknown> = {}) {
    return service.createCampaign({
      title: 'Ưu đãi thử nghiệm',
      body: 'Giảm 20% cho chuyến đầu tiên trong tuần.',
      channels: ['PUSH', 'IN_APP'],
      audience: 'CUSTOMER',
      actorUserId: ACTOR,
      ...overrides,
    });
  }

  it('lists seeded campaigns with stable per-tab counts', async () => {
    const all = await service.listCampaigns({});
    expect(all.total).toBe(12);
    expect(all.counts).toEqual({ all: 12, running: 4, sent: 4, pending: 2, draft: 2 });

    const sent = await service.listCampaigns({ tab: 'SENT' });
    expect(sent.items.every((c) => c.status === 'SENT')).toBe(true);
    expect(sent.total).toBe(4);
    // Counts are independent of the selected tab.
    expect(sent.counts).toEqual(all.counts);

    const running = await service.listCampaigns({ tab: 'RUNNING' });
    expect(running.items.map((c) => c.status).sort()).toEqual([
      'RUNNING',
      'RUNNING',
      'RUNNING',
      'SENDING',
    ]);
  });

  it('filters by channel, audience and query, and paginates', async () => {
    const email = await service.listCampaigns({ channel: 'EMAIL' });
    expect(email.items.every((c) => c.channels.includes('EMAIL'))).toBe(true);

    const drivers = await service.listCampaigns({ audience: 'DRIVER' });
    expect(drivers.items.every((c) => c.audienceType === 'DRIVER')).toBe(true);

    const q = await service.listCampaigns({ q: 'kyc' });
    expect(q.items.map((c) => c.code)).toEqual(['TB-240610-026']);

    const page2 = await service.listCampaigns({ page: 2, limit: 5 });
    expect(page2.items).toHaveLength(5);
    expect(page2.page).toBe(2);
  });

  it('formats the view for the Admin Web table', async () => {
    const one = await service.getCampaign('TB-240610-028');
    expect(one.channel).toBe('Push + In-app');
    expect(one.audience).toBe('Khách có chuyến hoạt động');
    expect(one.schedule).toBe('10/06 14:00');
    expect(one.reached).toBe((3240).toLocaleString('vi-VN'));

    const auto = await service.getCampaign('TB-240610-023');
    expect(auto.reached).toBe('Theo sự kiện');
    expect(auto.scheduleNote).toBe('Tự động');
  });

  it('runs the happy-path workflow DRAFT → PENDING → RUNNING → SENT', async () => {
    const draft = await newDraft({ scheduledAt: FUTURE() });
    expect(draft.status).toBe('DRAFT');
    expect(draft.code).toMatch(/^TB-\d{6}-001$/);

    const edited = await service.updateCampaign({
      code: draft.code,
      title: 'Ưu đãi đã chỉnh sửa',
      actorUserId: ACTOR,
    });
    expect(edited.title).toBe('Ưu đãi đã chỉnh sửa');

    const pending = await service.submitCampaign(draft.code, ACTOR);
    expect(pending.status).toBe('PENDING_APPROVAL');
    expect(pending.submittedAt).not.toBeNull();

    const approved = await service.approveCampaign(draft.code, ACTOR, 'Nội dung hợp lệ');
    expect(approved.status).toBe('RUNNING');
    expect(approved.approvedAt).not.toBeNull();

    const sent = await service.markSent(draft.code, 120);
    expect(sent.status).toBe('SENT');
    expect(sent.reachedCount).toBe(120);

    const ops = repo.audits.filter((a) => a.entityId === draft.id).map((a) => a.metadata.op);
    expect(ops).toEqual(['create', 'update', 'submit', 'approve', 'sent']);
  });

  it('approves a campaign without a future schedule straight to SENDING', async () => {
    const draft = await newDraft();
    await service.submitCampaign(draft.code, ACTOR);
    const approved = await service.approveCampaign(draft.code, ACTOR, 'Gửi ngay');
    expect(approved.status).toBe('SENDING');
  });

  it('sends a rejected campaign back to DRAFT with the reviewer note', async () => {
    const draft = await newDraft();
    await service.submitCampaign(draft.code, ACTOR);
    const rejected = await service.rejectCampaign(draft.code, ACTOR, 'Thiếu điều kiện áp dụng');
    expect(rejected.status).toBe('DRAFT');
    expect(rejected.rejectionReason).toBe('Thiếu điều kiện áp dụng');
    expect(rejected.submittedAt).toBeNull();
  });

  it('rejects invalid transitions with 409 and unknown codes with 404', async () => {
    const draft = await newDraft();
    await expect(service.approveCampaign(draft.code, ACTOR, 'x'.repeat(5))).rejects.toBeInstanceOf(
      ConflictException,
    );
    await service.submitCampaign(draft.code, ACTOR);
    await expect(
      service.updateCampaign({ code: draft.code, title: 'Không được sửa', actorUserId: ACTOR }),
    ).rejects.toBeInstanceOf(ConflictException);
    await expect(service.submitCampaign(draft.code, ACTOR)).rejects.toBeInstanceOf(
      ConflictException,
    );
    await expect(service.getCampaign('TB-000000-999')).rejects.toBeInstanceOf(NotFoundException);
    await expect(service.cancelCampaign('TB-000000-999', ACTOR, 'không có')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('cancels draft / pending / running campaigns but not sent ones', async () => {
    const running = await service.cancelCampaign('TB-240610-026', ACTOR, 'Dừng chiến dịch');
    expect(running.status).toBe('CANCELLED');
    expect(running.cancelledAt).not.toBeNull();
    await expect(
      service.cancelCampaign('TB-240610-027', ACTOR, 'Đã gửi rồi'),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('validates content: channels, schedule and OTP-style messages', async () => {
    await expect(newDraft({ channels: [] })).rejects.toMatchObject({
      response: { errorCode: 'NOTIFICATION_CHANNEL_REQUIRED' },
    });
    await expect(
      newDraft({ scheduledAt: new Date(Date.now() - 3_600_000).toISOString() }),
    ).rejects.toMatchObject({ response: { errorCode: 'NOTIFICATION_SCHEDULE_IN_PAST' } });
    await expect(newDraft({ body: 'Mã OTP của bạn là 123456' })).rejects.toMatchObject({
      response: { errorCode: 'NOTIFICATION_SENSITIVE_CONTENT' },
    });
  });

  it('allocates sequential codes within the same day', async () => {
    const a = await newDraft();
    const b = await newDraft();
    expect(a.code.endsWith('-001')).toBe(true);
    expect(b.code.endsWith('-002')).toBe(true);
  });

  it('manages CMS content and stamps publishedAt once', async () => {
    const all = await service.listCms({});
    expect(all.total).toBe(OPS_CMS_SEEDS.length);
    const banners = await service.listCms({ kind: 'BANNER' });
    expect(banners.items.map((i) => i.kindLabel)).toEqual(['Banner', 'Banner']);

    const created = await service.createCms({
      kind: 'ARTICLE',
      title: 'Bài viết mới',
      body: 'Nội dung bài viết.',
      actorUserId: ACTOR,
    });
    expect(created.status).toBe('DRAFT');
    expect(created.publishedAt).toBeNull();

    const published = await service.patchCms({
      id: created.id,
      status: 'PUBLISHED',
      actorUserId: ACTOR,
    });
    expect(published.status).toBe('PUBLISHED');
    const firstPublishedAt = published.publishedAt;
    expect(firstPublishedAt).not.toBeNull();

    const republished = await service.patchCms({
      id: created.id,
      title: 'Bài viết mới (sửa)',
      actorUserId: ACTOR,
    });
    expect(republished.publishedAt).toBe(firstPublishedAt);

    await expect(
      service.patchCms({ id: '00000000-0000-4000-8000-000000000000', actorUserId: ACTOR }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
