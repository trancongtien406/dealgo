import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { normalizeLimit, normalizePage, type PageResult } from '../../../shared/pagination/pagination.js';
import type {
  ApplyCampaignResult,
  CampaignCounts,
  CampaignRecord,
  CampaignStatusName,
  CampaignTabName,
  CmsKindName,
  CmsRecord,
  CmsStatusName,
  NotificationAudienceName,
  NotificationChannelName,
  OpsNotificationRepository,
} from './notification.repository.js';
import { OPS_CAMPAIGN_SEEDS, OPS_CMS_SEEDS } from './notification.seed.js';
import { OPS_NOTIFICATION_REPOSITORY } from './notification.constants.js';

const CHANNEL_LABELS: Record<NotificationChannelName, string> = {
  PUSH: 'Push',
  SMS: 'SMS',
  EMAIL: 'Email',
  IN_APP: 'In-app',
};

const AUDIENCE_LABELS: Record<NotificationAudienceName, string> = {
  ALL: 'Toàn hệ thống',
  CUSTOMER: 'Khách hàng',
  DRIVER: 'Tài xế',
  MERCHANT: 'Cửa hàng',
  STAFF: 'Nhân viên',
};

const CMS_KIND_LABELS: Record<CmsKindName, string> = {
  ARTICLE: 'Bài viết',
  BANNER: 'Banner',
  POLICY: 'Chính sách',
};

const CMS_KIND_STYLE: Record<CmsKindName, { icon: string; tone: string }> = {
  ARTICLE: { icon: 'receipt', tone: 'delivery' },
  BANNER: { icon: 'gift', tone: 'food' },
  POLICY: { icon: 'shield', tone: 'brand' },
};

/** OTP / sign-in codes are always backend-issued; campaigns must never carry them. */
const SENSITIVE_PATTERN = /\botp\b|mã\s*xác\s*(thực|minh)|verification\s*code/i;

export type CampaignView = {
  id: string;
  code: string;
  title: string;
  body: string;
  /** Display label, e.g. "Push + In-app". */
  channel: string;
  channels: NotificationChannelName[];
  /** Display label (audience note when present, else the audience group name). */
  audience: string;
  audienceType: NotificationAudienceName;
  audienceNote: string | null;
  status: CampaignStatusName;
  isAutomatic: boolean;
  reached: string;
  reachedCount: number | null;
  /** "dd/MM HH:mm" in Asia/Ho_Chi_Minh, "—" when unscheduled. */
  schedule: string;
  scheduleNote: string;
  scheduledAt: string | null;
  rejectionReason: string | null;
  submittedAt: string | null;
  approvedAt: string | null;
  sentAt: string | null;
  cancelledAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CampaignPageView = PageResult<CampaignView> & { counts: CampaignCounts };

export type CmsView = {
  id: string;
  kind: CmsKindName;
  title: string;
  body: string;
  status: CmsStatusName;
  /** Vietnamese kind label for display (matches the Admin Web tabs). */
  kindLabel: string;
  /** "dd/MM/yyyy" of publishedAt ?? createdAt (Asia/Ho_Chi_Minh). */
  date: string;
  icon: string;
  tone: string;
  publishedAt: string | null;
  createdAt: string;
  updatedAt: string;
};

export type CreateCampaignParams = {
  title: string;
  body: string;
  channels: NotificationChannelName[];
  audience: NotificationAudienceName;
  audienceNote?: string | null;
  isAutomatic?: boolean;
  scheduledAt?: string | null;
  actorUserId: string;
  reason?: string;
};

export type UpdateCampaignParams = {
  code: string;
  title?: string;
  body?: string;
  channels?: NotificationChannelName[];
  audience?: NotificationAudienceName;
  audienceNote?: string | null;
  isAutomatic?: boolean;
  scheduledAt?: string | null;
  actorUserId: string;
  reason?: string;
};

@Injectable()
export class NotificationService {
  private seeded: Promise<void> | null = null;

  constructor(
    @Inject(OPS_NOTIFICATION_REPOSITORY) private readonly repo: OpsNotificationRepository,
  ) {}

  async listCampaigns(params: {
    page?: number;
    limit?: number;
    q?: string;
    tab?: CampaignTabName;
    channel?: NotificationChannelName;
    audience?: NotificationAudienceName;
  }): Promise<CampaignPageView> {
    await this.ensureSeeded();
    const page = normalizePage(params.page);
    const limit = normalizeLimit(params.limit);
    const result = await this.repo.listCampaigns({
      page,
      limit,
      q: params.q,
      tab: params.tab ?? 'ALL',
      channel: params.channel,
      audience: params.audience,
    });
    return {
      items: result.rows.map(toCampaignView),
      page,
      limit,
      total: result.total,
      counts: result.counts,
    };
  }

  async getCampaign(code: string): Promise<CampaignView> {
    await this.ensureSeeded();
    return toCampaignView(await this.requireCampaign(code));
  }

  async createCampaign(params: CreateCampaignParams): Promise<CampaignView> {
    await this.ensureSeeded();
    const channels = normalizeChannels(params.channels);
    assertSafeContent(params.title, params.body);
    const scheduledAt = parseFutureDate(params.scheduledAt);
    const record = await this.repo.createCampaign({
      title: params.title.trim(),
      body: params.body.trim(),
      channels,
      audience: params.audience,
      audienceNote: normalizeNote(params.audienceNote),
      isAutomatic: params.isAutomatic ?? false,
      scheduledAt,
      actorUserId: params.actorUserId,
      reason: params.reason?.trim() || 'Tạo chiến dịch thông báo',
    });
    return toCampaignView(record);
  }

  async updateCampaign(params: UpdateCampaignParams): Promise<CampaignView> {
    await this.ensureSeeded();
    if (params.title !== undefined || params.body !== undefined) {
      const current = await this.requireCampaign(params.code);
      assertSafeContent(params.title ?? current.title, params.body ?? current.body);
    }
    const result = await this.repo.applyCampaign({
      code: params.code,
      from: ['DRAFT'],
      data: {
        title: params.title?.trim(),
        body: params.body?.trim(),
        channels: params.channels ? normalizeChannels(params.channels) : undefined,
        audience: params.audience,
        audienceNote:
          params.audienceNote === undefined ? undefined : normalizeNote(params.audienceNote),
        isAutomatic: params.isAutomatic,
        scheduledAt:
          params.scheduledAt === undefined ? undefined : parseFutureDate(params.scheduledAt),
        rejectionReason: null,
      },
      actorUserId: params.actorUserId,
      op: 'update',
      reason: params.reason?.trim() || 'Cập nhật chiến dịch thông báo',
    });
    return toCampaignView(unwrap(result, params.code, 'chỉnh sửa'));
  }

  /** DRAFT → PENDING_APPROVAL */
  async submitCampaign(code: string, actorUserId: string, reason?: string): Promise<CampaignView> {
    await this.ensureSeeded();
    const result = await this.repo.applyCampaign({
      code,
      from: ['DRAFT'],
      data: { status: 'PENDING_APPROVAL', submittedAt: new Date(), rejectionReason: null },
      actorUserId,
      op: 'submit',
      reason: reason?.trim() || 'Gửi duyệt chiến dịch',
    });
    return toCampaignView(unwrap(result, code, 'gửi duyệt'));
  }

  /**
   * PENDING_APPROVAL → RUNNING (scheduled / automatic) or SENDING (due now).
   * SENDING + PUSH enqueues a NotificationCampaign outbox row for best-effort fan-out.
   */
  async approveCampaign(code: string, actorUserId: string, reason: string): Promise<CampaignView> {
    await this.ensureSeeded();
    const current = await this.requireCampaign(code);
    const deferred =
      current.isAutomatic ||
      (current.scheduledAt !== null && current.scheduledAt.getTime() > Date.now());
    const result = await this.repo.applyCampaign({
      code,
      from: ['PENDING_APPROVAL'],
      data: {
        status: deferred ? 'RUNNING' : 'SENDING',
        approvedAt: new Date(),
        approvedByUserId: actorUserId,
        rejectionReason: null,
      },
      actorUserId,
      op: 'approve',
      reason,
    });
    return toCampaignView(unwrap(result, code, 'phê duyệt'));
  }

  /** PENDING_APPROVAL → DRAFT with the reviewer's note so the author can fix it. */
  async rejectCampaign(code: string, actorUserId: string, reason: string): Promise<CampaignView> {
    await this.ensureSeeded();
    const result = await this.repo.applyCampaign({
      code,
      from: ['PENDING_APPROVAL'],
      data: { status: 'DRAFT', rejectionReason: reason.trim().slice(0, 500), submittedAt: null },
      actorUserId,
      op: 'reject',
      reason,
    });
    return toCampaignView(unwrap(result, code, 'từ chối'));
  }

  /** DRAFT | PENDING_APPROVAL | RUNNING → CANCELLED */
  async cancelCampaign(code: string, actorUserId: string, reason: string): Promise<CampaignView> {
    await this.ensureSeeded();
    const result = await this.repo.applyCampaign({
      code,
      from: ['DRAFT', 'PENDING_APPROVAL', 'RUNNING'],
      data: { status: 'CANCELLED', cancelledAt: new Date() },
      actorUserId,
      op: 'cancel',
      reason,
    });
    return toCampaignView(unwrap(result, code, 'hủy'));
  }

  /**
   * Internal hook for the future delivery worker (not exposed over HTTP):
   * SENDING | RUNNING → SENT with the delivered audience size.
   */
  async markSent(code: string, reachedCount: number): Promise<CampaignView> {
    const result = await this.repo.applyCampaign({
      code,
      from: ['SENDING', 'RUNNING'],
      data: { status: 'SENT', reachedCount, sentAt: new Date() },
      actorUserId: null,
      op: 'sent',
      reason: 'Hoàn tất phát hành',
    });
    return toCampaignView(unwrap(result, code, 'đánh dấu đã gửi'));
  }

  async listCms(params: {
    kind?: CmsKindName;
    status?: CmsStatusName;
    q?: string;
  }): Promise<{ items: CmsView[]; total: number }> {
    await this.ensureSeeded();
    const rows = await this.repo.listCms(params);
    return { items: rows.map(toCmsView), total: rows.length };
  }

  async getCms(id: string): Promise<CmsView> {
    await this.ensureSeeded();
    const row = await this.repo.findCms(id);
    if (!row) throw cmsNotFound();
    return toCmsView(row);
  }

  async createCms(params: {
    kind: CmsKindName;
    title: string;
    body: string;
    status?: CmsStatusName;
    actorUserId: string;
    reason?: string;
  }): Promise<CmsView> {
    await this.ensureSeeded();
    const row = await this.repo.createCms({
      kind: params.kind,
      title: params.title.trim(),
      body: params.body.trim(),
      status: params.status,
      actorUserId: params.actorUserId,
      reason: params.reason?.trim() || 'Tạo nội dung CMS',
    });
    return toCmsView(row);
  }

  async patchCms(params: {
    id: string;
    kind?: CmsKindName;
    title?: string;
    body?: string;
    status?: CmsStatusName;
    actorUserId: string;
    reason?: string;
  }): Promise<CmsView> {
    await this.ensureSeeded();
    const row = await this.repo.patchCms({
      id: params.id,
      kind: params.kind,
      title: params.title?.trim(),
      body: params.body?.trim(),
      status: params.status,
      actorUserId: params.actorUserId,
      reason: params.reason?.trim() || 'Cập nhật nội dung CMS',
    });
    if (!row) throw cmsNotFound();
    return toCmsView(row);
  }

  private async requireCampaign(code: string): Promise<CampaignRecord> {
    const row = await this.repo.findCampaign(code);
    if (!row) throw campaignNotFound(code);
    return row;
  }

  private ensureSeeded(): Promise<void> {
    if (!this.seeded) {
      this.seeded = this.repo.ensureSeeds(OPS_CAMPAIGN_SEEDS, OPS_CMS_SEEDS).catch((error) => {
        this.seeded = null;
        throw error;
      });
    }
    return this.seeded;
  }
}

function campaignNotFound(code: string): NotFoundException {
  return new NotFoundException({
    message: `Không tìm thấy chiến dịch ${code}`,
    errorCode: 'NOTIFICATION_CAMPAIGN_NOT_FOUND',
  });
}

function cmsNotFound(): NotFoundException {
  return new NotFoundException({
    message: 'Không tìm thấy nội dung CMS',
    errorCode: 'CMS_CONTENT_NOT_FOUND',
  });
}

function unwrap(result: ApplyCampaignResult, code: string, action: string): CampaignRecord {
  if (result.kind === 'OK') return result.record;
  if (result.kind === 'NOT_FOUND') throw campaignNotFound(code);
  throw new ConflictException({
    message: `Không thể ${action} chiến dịch ${code} khi đang ở trạng thái ${result.current}`,
    errorCode: 'NOTIFICATION_INVALID_STATE',
  });
}

function normalizeChannels(channels: NotificationChannelName[]): NotificationChannelName[] {
  const unique = [...new Set(channels)];
  if (unique.length === 0) {
    throw new BadRequestException({
      message: 'Cần chọn ít nhất một kênh phát hành',
      errorCode: 'NOTIFICATION_CHANNEL_REQUIRED',
    });
  }
  return unique;
}

function normalizeNote(note: string | null | undefined): string | null {
  const trimmed = note?.trim();
  return trimmed ? trimmed : null;
}

function assertSafeContent(title: string, body: string): void {
  if (SENSITIVE_PATTERN.test(title) || SENSITIVE_PATTERN.test(body)) {
    throw new BadRequestException({
      message:
        'Nội dung liên quan OTP/mã xác thực chỉ do backend xác thực phát hành, không dùng chiến dịch',
      errorCode: 'NOTIFICATION_SENSITIVE_CONTENT',
    });
  }
}

function parseFutureDate(value: string | null | undefined): Date | null {
  if (value === null || value === undefined || value === '') return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new BadRequestException({
      message: 'Thời điểm lên lịch không hợp lệ',
      errorCode: 'NOTIFICATION_SCHEDULE_INVALID',
    });
  }
  if (date.getTime() < Date.now() - 60_000) {
    throw new BadRequestException({
      message: 'Thời điểm lên lịch phải ở tương lai',
      errorCode: 'NOTIFICATION_SCHEDULE_IN_PAST',
    });
  }
  return date;
}

const VN_OFFSET_MS = 7 * 60 * 60 * 1000;
const pad = (n: number) => String(n).padStart(2, '0');

function formatVnDayMonthTime(date: Date): string {
  const d = new Date(date.getTime() + VN_OFFSET_MS);
  return `${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)} ${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}`;
}

function formatVnDate(date: Date): string {
  const d = new Date(date.getTime() + VN_OFFSET_MS);
  return `${pad(d.getUTCDate())}/${pad(d.getUTCMonth() + 1)}/${d.getUTCFullYear()}`;
}

function formatReached(row: CampaignRecord): string {
  if (row.reachedCount !== null) {
    return row.reachedCount.toLocaleString('vi-VN');
  }
  return row.isAutomatic ? 'Theo sự kiện' : '—';
}

export function toCampaignView(row: CampaignRecord): CampaignView {
  return {
    id: row.id,
    code: row.code,
    title: row.title,
    body: row.body,
    channel: row.channels.map((c) => CHANNEL_LABELS[c]).join(' + '),
    channels: row.channels,
    audience: row.audienceNote ?? AUDIENCE_LABELS[row.audience],
    audienceType: row.audience,
    audienceNote: row.audienceNote,
    status: row.status,
    isAutomatic: row.isAutomatic,
    reached: formatReached(row),
    reachedCount: row.reachedCount,
    schedule: row.scheduledAt ? formatVnDayMonthTime(row.scheduledAt) : '—',
    scheduleNote: row.isAutomatic ? 'Tự động' : '',
    scheduledAt: row.scheduledAt?.toISOString() ?? null,
    rejectionReason: row.rejectionReason,
    submittedAt: row.submittedAt?.toISOString() ?? null,
    approvedAt: row.approvedAt?.toISOString() ?? null,
    sentAt: row.sentAt?.toISOString() ?? null,
    cancelledAt: row.cancelledAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export function toCmsView(row: CmsRecord): CmsView {
  const style = CMS_KIND_STYLE[row.kind];
  return {
    id: row.id,
    kind: row.kind,
    title: row.title,
    body: row.body,
    status: row.status,
    kindLabel: CMS_KIND_LABELS[row.kind],
    date: formatVnDate(row.publishedAt ?? row.createdAt),
    icon: style.icon,
    tone: style.tone,
    publishedAt: row.publishedAt?.toISOString() ?? null,
    createdAt: row.createdAt.toISOString(),
    updatedAt: row.updatedAt.toISOString(),
  };
}

export const OpsNotificationsService = NotificationService;
export type OpsNotificationsService = NotificationService;

