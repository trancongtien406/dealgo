import { Injectable } from '@nestjs/common';
import { normalizeLimit, normalizePage, type PageResult } from '../../shared/pagination/pagination.js';
import { PrismaService } from '../database/prisma.service.js';

export type AuditLogItem = {
  id: string;
  code: string;
  time: string;
  createdAt: string;
  actor: string;
  actorId: string;
  action: string;
  target: string;
  entityType: string;
  entityId: string;
  reason: string;
  result: 'SUCCESS' | 'PENDING_APPROVAL' | 'LOGGED' | 'REJECTED';
  metadata?: Record<string, unknown>;
};

export type OpsAuditLogItem = AuditLogItem;

@Injectable()
export class AuditLogsService {
  private inMemoryLogs: AuditLogItem[] = [
    {
      id: 'aud-00985',
      code: 'AUD-00985',
      time: '10/06/2024 14:02',
      createdAt: new Date(Date.now() - 3600_000 * 3).toISOString(),
      actor: 'Nguyễn Văn Minh (Admin)',
      actorId: 'usr-admin-01',
      action: 'Cập nhật giới hạn phiên',
      target: 'Cấu hình bảo mật',
      entityType: 'PLATFORM_SETTING',
      entityId: 'SETTING-SEC-01',
      reason: 'Điều chỉnh thời hạn phiên đăng nhập theo quy định an toàn mới.',
      result: 'SUCCESS',
      metadata: { key: 'SESSION_TTL_HOURS', value: '24' },
    },
    {
      id: 'aud-00984',
      code: 'AUD-00984',
      time: '10/06/2024 13:47',
      createdAt: new Date(Date.now() - 3600_000 * 4).toISOString(),
      actor: 'Phạm Quang Minh (Ops Lead)',
      actorId: 'usr-ops-02',
      action: 'Đề xuất cập nhật vùng',
      target: 'ZONE-DN-01 (Đà Nẵng Lõi)',
      entityType: 'PLATFORM_SETTING',
      entityId: 'ZONE-DN-01',
      reason: 'Mở rộng geofence thêm 2km về phía Ngũ Hành Sơn.',
      result: 'PENDING_APPROVAL',
      metadata: { zone: 'Da Nang Core', radiusKm: 17 },
    },
    {
      id: 'aud-00983',
      code: 'AUD-00983',
      time: '10/06/2024 11:26',
      createdAt: new Date(Date.now() - 3600_000 * 6).toISOString(),
      actor: 'Lê Thị Hoa (Điều phối)',
      actorId: 'usr-cs-03',
      action: 'Tiếp nhận hồ sơ khiếu nại',
      target: 'KN-240610-0245',
      entityType: 'DISPUTE',
      entityId: 'KN-240610-0245',
      reason: 'Khách hàng khiếu nại thiếu món - chuyển trạng thái chờ xác minh quán.',
      result: 'LOGGED',
      metadata: { orderCode: 'FA-240610-0892', priority: 'HIGH' },
    },
    {
      id: 'aud-00982',
      code: 'AUD-00982',
      time: '10/06/2024 10:36',
      createdAt: new Date(Date.now() - 3600_000 * 7).toISOString(),
      actor: 'Đặng Thị Ngọc (CSKH)',
      actorId: 'usr-cs-04',
      action: 'Mở yêu cầu hoàn tiền',
      target: 'RF-240610-0034',
      entityType: 'FOOD_ORDER',
      entityId: 'RF-240610-0034',
      reason: 'Tạo phiếu hoàn tiền dự phòng sau khi khách phản hồi giao chậm.',
      result: 'LOGGED',
      metadata: { amount: 65000 },
    },
    {
      id: 'aud-00981',
      code: 'AUD-00981',
      time: '10/06/2024 09:54',
      createdAt: new Date(Date.now() - 3600_000 * 8).toISOString(),
      actor: 'Hệ thống tự động',
      actorId: 'system',
      action: 'Đối chiếu tích hợp',
      target: 'SMS / OTP Provider',
      entityType: 'AUTH_METHOD_POLICY',
      entityId: 'SMS_GATEWAY',
      reason: 'Kiểm tra độ trễ định kỳ cổng eSMS - độ trễ đạt 1.2s.',
      result: 'SUCCESS',
      metadata: { latencyMs: 1200 },
    },
    {
      id: 'aud-00980',
      code: 'AUD-00980',
      time: '10/06/2024 08:30',
      createdAt: new Date(Date.now() - 3600_000 * 10).toISOString(),
      actor: 'Trần Văn Cường (Admin)',
      actorId: 'usr-admin-01',
      action: 'Cập nhật Q&A Chính sách OPEN-001',
      target: 'Chính sách Vùng Pilot',
      entityType: 'OPS_FAQ',
      entityId: 'OPEN-001',
      reason: 'Đồng bộ khuyến nghị địa bàn Đà Nẵng và tiêu chí mở rộng 60 ngày.',
      result: 'SUCCESS',
      metadata: { openId: 'OPEN-001' },
    },
  ];

  constructor(private readonly prisma: PrismaService) {}

  record(log: Omit<AuditLogItem, 'id' | 'code' | 'time' | 'createdAt'>): AuditLogItem {
    const nextSeq = this.inMemoryLogs.length + 986;
    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const timeFormatted = `${pad(now.getDate())}/${pad(now.getMonth() + 1)}/${now.getFullYear()} ${pad(now.getHours())}:${pad(now.getMinutes())}`;

    const item: AuditLogItem = {
      ...log,
      id: `aud-${nextSeq}`,
      code: `AUD-${String(nextSeq).padStart(5, '0')}`,
      time: timeFormatted,
      createdAt: now.toISOString(),
    };

    this.inMemoryLogs.unshift(item);
    return item;
  }

  async list(options: {
    q?: string;
    entityType?: string;
    result?: string;
    page?: number;
    limit?: number;
  }): Promise<PageResult<AuditLogItem>> {
    const safePage = normalizePage(options.page);
    const safeLimit = normalizeLimit(options.limit);

    let allItems = [...this.inMemoryLogs];

    // Merge with Prisma records if DB is available
    const db = this.prisma.db();
    if (db) {
      try {
        const prismaLogs = await db.opsAuditLog.findMany({
          include: { actor: true },
          orderBy: { createdAt: 'desc' },
          take: 200,
        });

        for (const p of prismaLogs) {
          const createdAt = p.createdAt.toISOString();
          const d = p.createdAt;
          const pad = (n: number) => String(n).padStart(2, '0');
          const time = `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
          const code = `AUD-DB-${p.id.slice(0, 6).toUpperCase()}`;

          // Avoid duplicate
          if (!allItems.some((item) => item.id === p.id)) {
            allItems.push({
              id: p.id,
              code,
              time,
              createdAt,
              actor: p.actor.email ?? p.actor.phone ?? 'Operator',
              actorId: p.actorUserId,
              action: p.action,
              target: `${p.entityType}:${p.entityId.slice(0, 8)}`,
              entityType: p.entityType,
              entityId: p.entityId,
              reason: p.reason,
              result: 'SUCCESS',
              metadata: (p.metadata as Record<string, unknown>) ?? {},
            });
          }
        }

        // Sort all items descending by createdAt
        allItems.sort((a, b) => b.createdAt.localeCompare(a.createdAt));
      } catch {
        // Fallback gracefully to in-memory items
      }
    }

    // Apply filtering
    if (options.q && options.q.trim()) {
      const q = options.q.trim().toLowerCase();
      allItems = allItems.filter(
        (i) =>
          i.code.toLowerCase().includes(q) ||
          i.actor.toLowerCase().includes(q) ||
          i.action.toLowerCase().includes(q) ||
          i.target.toLowerCase().includes(q) ||
          i.reason.toLowerCase().includes(q),
      );
    }

    if (options.entityType && options.entityType !== 'ALL') {
      const et = options.entityType.toUpperCase();
      allItems = allItems.filter((i) => i.entityType.toUpperCase() === et);
    }

    if (options.result && options.result !== 'ALL') {
      const r = options.result.toUpperCase();
      allItems = allItems.filter((i) => i.result === r);
    }

    const total = allItems.length;
    const start = (safePage - 1) * safeLimit;
    const items = allItems.slice(start, start + safeLimit);

    return {
      items,
      page: safePage,
      limit: safeLimit,
      total,
    };
  }
}

export { AuditLogsService as OpsAuditLogsService };
