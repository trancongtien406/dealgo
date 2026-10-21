import { Inject, Injectable } from '@nestjs/common';
import {
  normalizeLimit,
  normalizePage,
  type PageResult,
} from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import { maskPhone } from '../../shared/privacy/pii-mask.js';
import { authError } from './auth-error.js';
import {
  DRIVER_PRESENCE_REPOSITORY,
  IDENTITY_REPOSITORY,
} from './identity.constants.js';
import type {
  DriverPresenceRepository,
  DriverPresenceView,
} from './driver-presence.repository.js';
import type {
  GrantStatusName,
  IdentityRepository,
  OpsUserDirectoryRecord,
  RoleName,
} from './identity.repository.js';

export type OpsUserGrantView = {
  id: string;
  role: RoleName;
  status: GrantStatusName;
};

export type OpsUserListItem = {
  id: string;
  displayName: string;
  phone: string | null;
  phoneMasked?: string | null;
  email: string | null;
  phoneVerifiedAt: string | null;
  emailVerifiedAt: string | null;
  createdAt: string;
  grants: OpsUserGrantView[];
  /** Staff directory: ADMIN | OPS (from grants + OpsCredential). */
  role?: string;
  /** Staff directory: NATIONAL | CITY | ZONE. */
  scope?: string;
  /** Staff directory (DEC-PROD-036): can reset other ops users' passwords. */
  superAdmin?: boolean;
  /** S027 (DEC-PROD-037): null = active account. */
  deletion: OpsUserDeletionView | null;
};

export type OpsUserDeletionView = {
  /** SCHEDULED = soft-deleted, inside the grace period; PURGED = PII anonymized. */
  status: 'SCHEDULED' | 'PURGED';
  deletedAt: string;
  purgeAfter: string | null;
  purgedAt: string | null;
};

export type OpsStaffListResult = PageResult<OpsUserListItem> & {
  counts?: { active: number; pending: number; suspended: number };
};

export type OpsDriverListItem = OpsUserListItem & {
  presence: {
    online: boolean;
    lat: number | null;
    lng: number | null;
    serviceRegionCode: string | null;
    /** DEC-PROD-023 service toggles (Admin "Dịch vụ" column). */
    rideEnabled: boolean;
    foodEnabled: boolean;
    updatedAt: string;
  } | null;
};

export type OpsCustomerActivityItem = {
  time: string;
  code: string;
  kind: string;
  summary: string;
  value: string;
  status: string;
  tone: string;
};

@Injectable()
export class OpsUsersService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    @Inject(DRIVER_PRESENCE_REPOSITORY)
    private readonly presence: DriverPresenceRepository,
    private readonly prisma: PrismaService,
  ) {}

  listCustomers(
    page?: number,
    limit?: number,
    filter?: { q?: string; status?: string; region?: string; service?: string },
  ): Promise<PageResult<OpsUserListItem>> {
    return this.listByRole('CUSTOMER', page, limit, {
      q: filter?.q,
      status: filter?.status,
      region: filter?.region,
      service: filter?.service,
    });
  }

  async getCustomer(id: string): Promise<OpsUserListItem> {
    return this.getByRole(id, 'CUSTOMER');
  }

  async getCustomerActivities(
    id: string,
    options: { tab?: string; page?: number; limit?: number },
  ): Promise<{
    items: OpsCustomerActivityItem[];
    page: number;
    limit: number;
    total: number;
    tab: string;
  }> {
    await this.getByRole(id, 'CUSTOMER');

    const page = Math.max(1, options.page ?? 1);
    const limit = Math.max(1, Math.min(50, options.limit ?? 6));
    const tab = options.tab || 'Hoạt động gần đây';
    const tabKey = normalizeActivityTab(tab);

    const db = this.prisma.db();
    if (!db) {
      return { items: [], page, limit, total: 0, tab };
    }

    type ActivityRow = OpsCustomerActivityItem & { sortAt: number };
    const activities: ActivityRow[] = [];

    if (tabKey === 'ALL' || tabKey === 'RIDES') {
      const rides = await db.ride.findMany({
        where: { customerId: id },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
      for (const ride of rides) {
        const fare = ride.agreedFareVnd ?? ride.offeredFareVnd;
        activities.push({
          time: formatActivityTime(ride.createdAt),
          code: `DGX-${ride.id.slice(0, 8).toUpperCase()}`,
          kind: ride.status === 'NEGOTIATING' ? 'Phiên trả giá' : 'Chuyến xe',
          summary: `${ride.pickupLabel} → ${ride.dropoffLabel}`,
          value: formatVnd(fare),
          status: RIDE_STATUS_LABEL[ride.status] ?? ride.status,
          tone: ride.status === 'COMPLETED' ? 'success' : 'brand',
          sortAt: ride.createdAt.getTime(),
        });
      }
    }

    if (tabKey === 'ALL' || tabKey === 'FOOD') {
      const orders = await db.foodOrder.findMany({
        where: { customerId: id },
        include: { store: { select: { name: true } } },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
      for (const order of orders) {
        activities.push({
          time: formatActivityTime(order.createdAt),
          code: `FA-${order.id.slice(0, 8).toUpperCase()}`,
          kind: 'Đơn đồ ăn',
          summary: order.store?.name
            ? `${order.store.name}, ${order.dropoffLabel}`
            : order.dropoffLabel,
          value: formatVnd(order.totalVnd),
          status: FOOD_STATUS_LABEL[order.status] ?? order.status,
          tone: order.status === 'DELIVERED' ? 'success' : 'brand',
          sortAt: order.createdAt.getTime(),
        });
      }
    }

    if (tabKey === 'ALL' || tabKey === 'PAYMENT') {
      const [rideIds, foodIds] = await Promise.all([
        db.ride.findMany({
          where: { customerId: id },
          select: { id: true },
          take: 200,
        }),
        db.foodOrder.findMany({
          where: { customerId: id },
          select: { id: true },
          take: 200,
        }),
      ]);
      const entityIds = [
        ...rideIds.map((r) => r.id),
        ...foodIds.map((o) => o.id),
      ];
      if (entityIds.length > 0) {
        const intents = await db.paymentIntent.findMany({
          where: { entityId: { in: entityIds } },
          orderBy: { createdAt: 'desc' },
          take: 100,
        });
        for (const pi of intents) {
          const prefix = pi.entityType === 'RIDE' ? 'DGX' : 'FA';
          activities.push({
            time: formatActivityTime(pi.createdAt),
            code: `TXN-${pi.id.slice(0, 8).toUpperCase()}`,
            kind: 'Thanh toán',
            summary: `Thanh toán ${prefix}-${pi.entityId.slice(0, 8).toUpperCase()} (${pi.method})`,
            value: `-${formatVnd(pi.amountVnd)}`,
            status: pi.status === 'CAPTURED_STUB' ? 'Thành công' : pi.status,
            tone: pi.status === 'CAPTURED_STUB' ? 'success' : 'brand',
            sortAt: pi.createdAt.getTime(),
          });
        }
      }
    }

    // Delivery / notes tabs kept for UI — MVP has no separate delivery entity.
    if (tabKey === 'DELIVERY' || tabKey === 'NOTE') {
      return { items: [], page, limit, total: 0, tab };
    }

    activities.sort((a, b) => b.sortAt - a.sortAt);
    const total = activities.length;
    const start = (page - 1) * limit;
    return {
      items: activities.slice(start, start + limit).map(({ sortAt: _s, ...item }) => item),
      page,
      limit,
      total,
      tab,
    };
  }


  listStaff(
    page?: number,
    limit?: number,
    filter?: { q?: string; status?: string; role?: string; scope?: string },
  ): Promise<OpsStaffListResult> {
    return this.listByRole('OPS', page, limit, {
      q: filter?.q,
      status: filter?.status,
      staffRole: filter?.role,
      scope: filter?.scope,
    });
  }

  async getStaff(id: string): Promise<OpsUserListItem> {
    return this.getByRole(id, 'OPS');
  }

  async listDrivers(
    page?: number,
    limit?: number,
    filter?: {
      q?: string;
      status?: string;
      service?: string;
      region?: string;
      activity?: string;
      kyc?: string;
    },
  ): Promise<PageResult<OpsDriverListItem>> {
    const pageResult = await this.listByRole('DRIVER', page, limit, {
      q: filter?.q,
      status: filter?.status,
      region: filter?.region,
      activity: filter?.activity,
      kyc: filter?.kyc,
      service: filter?.service,
    });
    const items: OpsDriverListItem[] = [];
    for (const item of pageResult.items) {
      const presence = await this.presence.findByUserId(item.id);
      items.push({ ...item, presence: mapPresence(presence) });
    }
    return { ...pageResult, items };
  }

  async getDriver(id: string): Promise<OpsDriverListItem> {
    const user = await this.getByRole(id, 'DRIVER');
    const presence = await this.presence.findByUserId(id);
    return { ...user, presence: mapPresence(presence) };
  }

  private async listByRole(
    role: RoleName,
    page?: number,
    limit?: number,
    filter?: {
      q?: string;
      status?: string;
      region?: string;
      activity?: string;
      kyc?: string;
      staffRole?: string;
      scope?: string;
      service?: string;
    },
  ): Promise<OpsStaffListResult> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);
    const grantStatus =
      filter?.status && filter.status !== 'ALL'
        ? (filter.status.toUpperCase() as GrantStatusName)
        : undefined;
    // UI INVITED → PENDING grant; DISABLED → SUSPENDED
    const mappedStatus =
      grantStatus === ('INVITED' as GrantStatusName)
        ? ('PENDING' as GrantStatusName)
        : grantStatus === ('DISABLED' as GrantStatusName)
          ? ('SUSPENDED' as GrantStatusName)
          : grantStatus;
    const result = await this.identity.listUsersByRole(role, safePage, safeLimit, {
      q: filter?.q,
      status: mappedStatus,
      region: filter?.region,
      activity: filter?.activity,
      kyc: filter?.kyc,
      staffRole: filter?.staffRole,
      scope: filter?.scope,
      service: filter?.service,
    });
    return {
      items: result.items.map(toOpsUserView),
      page: safePage,
      limit: safeLimit,
      total: result.total,
      ...(result.counts ? { counts: result.counts } : {}),
    };
  }

  private async getByRole(id: string, role: RoleName): Promise<OpsUserListItem> {
    const user = await this.identity.findUserDirectory(id);
    if (!user || !user.grants.some((grant) => grant.role === role)) {
      throw authError(404, 'USER_NOT_FOUND', 'User not found');
    }
    return toOpsUserView(user);
  }
}

function toOpsUserView(user: OpsUserDirectoryRecord): OpsUserListItem {
  return {
    id: user.id,
    displayName: user.displayName,
    phone: user.phone,
    phoneMasked: maskPhone(user.phone),
    email: user.email,
    phoneVerifiedAt: user.phoneVerifiedAt?.toISOString() ?? null,
    emailVerifiedAt: user.emailVerifiedAt?.toISOString() ?? null,
    createdAt: user.createdAt.toISOString(),
    grants: user.grants.map((grant) => ({
      id: grant.id,
      role: grant.role,
      status: grant.status,
    })),
    ...(user.staffRole ? { role: user.staffRole } : {}),
    ...(user.scope ? { scope: user.scope } : {}),
    ...(user.superAdmin !== undefined ? { superAdmin: user.superAdmin } : {}),
    deletion: user.deletedAt
      ? {
          status: user.purgedAt ? 'PURGED' : 'SCHEDULED',
          deletedAt: user.deletedAt.toISOString(),
          purgeAfter: user.purgeAfter?.toISOString() ?? null,
          purgedAt: user.purgedAt?.toISOString() ?? null,
        }
      : null,
  };
}

function mapPresence(
  presence: DriverPresenceView | null,
): OpsDriverListItem['presence'] {
  if (!presence) {
    return null;
  }
  return {
    online: presence.online,
    lat: presence.lat,
    lng: presence.lng,
    serviceRegionCode: presence.serviceRegionCode ?? null,
    rideEnabled: presence.rideEnabled,
    foodEnabled: presence.foodEnabled,
    updatedAt: presence.updatedAt.toISOString(),
  };
}

const RIDE_STATUS_LABEL: Record<string, string> = {
  NEGOTIATING: 'Đang thương lượng',
  ASSIGNED: 'Đã gán tài xế',
  DRIVER_EN_ROUTE: 'Tài xế đang đến',
  DRIVER_ARRIVED: 'Tài xế đã tới',
  IN_TRIP: 'Đang chạy',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Đã hủy',
  EXPIRED: 'Hết hạn',
};

const FOOD_STATUS_LABEL: Record<string, string> = {
  PLACED: 'Chờ xác nhận',
  CONFIRMED: 'Đã xác nhận',
  PREPARING: 'Đang chuẩn bị',
  READY: 'Sẵn sàng lấy',
  ASSIGNED: 'Đã gán tài xế',
  PICKED_UP: 'Đang giao',
  DELIVERED: 'Đã giao',
  CANCELLED: 'Đã hủy',
  FAILED: 'Thất bại',
};

function normalizeActivityTab(
  tab: string,
): 'ALL' | 'RIDES' | 'FOOD' | 'PAYMENT' | 'DELIVERY' | 'NOTE' {
  const t = tab.trim().toUpperCase();
  if (t === 'HOẠT ĐỘNG GẦN ĐÂY' || t === 'ALL' || tab === 'Hoạt động gần đây') {
    return 'ALL';
  }
  if (t === 'RIDES' || tab === 'Chuyến xe') return 'RIDES';
  if (t === 'FOOD' || t === 'ORDERS' || tab === 'Đơn ăn') return 'FOOD';
  if (t === 'PAYMENT' || t === 'PAYMENTS' || tab === 'Thanh toán') return 'PAYMENT';
  if (t === 'DELIVERY' || tab === 'Giao hàng') return 'DELIVERY';
  if (t === 'NOTE' || tab === 'Ghi chú') return 'NOTE';
  return 'ALL';
}

function formatActivityTime(d: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(d.getDate())}/${pad(d.getMonth() + 1)}/${d.getFullYear()} · ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function formatVnd(amount: number): string {
  return `${amount.toLocaleString('vi-VN')}đ`;
}
