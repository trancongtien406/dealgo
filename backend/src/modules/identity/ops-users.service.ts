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
  /** Customer directory statistics and main region */
  region?: string | null;
  area?: string | null;
  rides?: number;
  food?: number;
  delivery?: number;
  spend?: number;
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

export type OpsDriverActiveJob = {
  type: 'RIDE' | 'FOOD';
  id: string;
  code: string;
  status: string;
  statusLabel: string;
  customerName?: string;
  pickupLabel: string;
  dropoffLabel: string;
  fareVnd: number;
  createdAt: string;
};

export type OpsDriverKycInfo = {
  applicationId: string;
  status: string;
  vehicleType?: string | null;
  vehiclePlate?: string | null;
  vehicleBrand?: string | null;
  vehicleModel?: string | null;
  vehicleClassCode?: string | null;
  licenseClass?: string | null;
  licenseNumber?: string | null;
  bankName?: string | null;
  bankAccountNumber?: string | null;
  bankAccountHolder?: string | null;
  documentsWaived?: boolean;
  documentCount: number;
  submittedAt?: string | null;
  reviewedAt?: string | null;
};

export type OpsDriverDailyPerformance = {
  date: string;
  dayLabel: string;
  completedTrips: number;
  fareVnd: number;
  feeVnd: number;
  netVnd: number;
};

export type OpsDriverStats = {
  completedRides: number;
  completedFoodOrders: number;
  finishedJobs: number;
  completionRate: number | null;
  ratingAverage: number | null;
  ratingCount: number;
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
    parcelEnabled: boolean;
    updatedAt: string;
  } | null;
  kycDetail?: OpsDriverKycInfo | null;
  activeJob?: OpsDriverActiveJob | null;
  performance7d?: OpsDriverDailyPerformance[];
  stats?: OpsDriverStats;
};

export type OpsDriverActivityItem = {
  time: string;
  code: string;
  kind: string;
  summary: string;
  value: string;
  status: string;
  tone: string;
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

  async listCustomers(
    page?: number,
    limit?: number,
    filter?: { q?: string; status?: string; region?: string; service?: string },
  ): Promise<PageResult<OpsUserListItem>> {
    const pageResult = await this.listByRole('CUSTOMER', page, limit, {
      q: filter?.q,
      status: filter?.status,
      region: filter?.region,
      service: filter?.service,
    });
    const enriched = await this.enrichCustomersWithStats(pageResult.items);
    return { ...pageResult, items: enriched };
  }

  async getCustomer(id: string): Promise<OpsUserListItem> {
    const customer = await this.getByRole(id, 'CUSTOMER');
    const [enriched] = await this.enrichCustomersWithStats([customer]);
    return enriched ?? customer;
  }

  private async enrichCustomersWithStats(
    customers: OpsUserListItem[],
  ): Promise<OpsUserListItem[]> {
    if (customers.length === 0) {
      return [];
    }
    const db = this.prisma.db();
    if (!db) {
      return customers;
    }
    const customerIds = customers.map((c) => c.id);

    const [
      rideCounts,
      foodCounts,
      parcelCounts,
      completedRidesSpend,
      deliveredFoodSpend,
      recentRides,
      recentFood,
      regions,
    ] = await Promise.all([
      db.ride.groupBy({
        by: ['customerId'],
        where: { customerId: { in: customerIds } },
        _count: { _all: true },
      }),
      db.foodOrder.groupBy({
        by: ['customerId'],
        where: { customerId: { in: customerIds } },
        _count: { _all: true },
      }),
      db.ride.groupBy({
        by: ['customerId'],
        where: { customerId: { in: customerIds }, parcel: { isNot: null } },
        _count: { _all: true },
      }),
      db.ride.groupBy({
        by: ['customerId'],
        where: { customerId: { in: customerIds }, status: 'COMPLETED' },
        _sum: { agreedFareVnd: true, offeredFareVnd: true },
      }),
      db.foodOrder.groupBy({
        by: ['customerId'],
        where: { customerId: { in: customerIds }, status: 'DELIVERED' },
        _sum: { totalVnd: true },
      }),
      db.ride.findMany({
        where: { customerId: { in: customerIds }, serviceRegionCode: { not: null } },
        select: { customerId: true, serviceRegionCode: true },
        orderBy: { createdAt: 'desc' },
        distinct: ['customerId'],
      }),
      db.foodOrder.findMany({
        where: { customerId: { in: customerIds }, serviceRegionCode: { not: null } },
        select: { customerId: true, serviceRegionCode: true },
        orderBy: { createdAt: 'desc' },
        distinct: ['customerId'],
      }),
      db.serviceRegion.findMany({
        select: { code: true, label: true },
      }),
    ]);

    const regionMap = new Map<string, string>();
    for (const r of regions) {
      regionMap.set(r.code.toUpperCase(), r.label);
    }

    const rideCountMap = new Map<string, number>();
    for (const row of rideCounts) {
      rideCountMap.set(row.customerId, row._count._all);
    }

    const foodCountMap = new Map<string, number>();
    for (const row of foodCounts) {
      foodCountMap.set(row.customerId, row._count._all);
    }

    const parcelCountMap = new Map<string, number>();
    for (const row of parcelCounts) {
      parcelCountMap.set(row.customerId, row._count._all);
    }

    const spendMap = new Map<string, number>();
    for (const row of completedRidesSpend) {
      const fare = row._sum.agreedFareVnd ?? row._sum.offeredFareVnd ?? 0;
      spendMap.set(row.customerId, (spendMap.get(row.customerId) ?? 0) + fare);
    }
    for (const row of deliveredFoodSpend) {
      const amount = row._sum.totalVnd ?? 0;
      spendMap.set(row.customerId, (spendMap.get(row.customerId) ?? 0) + amount);
    }

    const customerRegionMap = new Map<string, string>();
    for (const row of recentRides) {
      if (row.serviceRegionCode && !customerRegionMap.has(row.customerId)) {
        customerRegionMap.set(row.customerId, row.serviceRegionCode);
      }
    }
    for (const row of recentFood) {
      if (row.serviceRegionCode && !customerRegionMap.has(row.customerId)) {
        customerRegionMap.set(row.customerId, row.serviceRegionCode);
      }
    }

    return customers.map((c) => {
      const regionCode = customerRegionMap.get(c.id) ?? null;
      const area = regionCode ? (regionMap.get(regionCode.toUpperCase()) ?? regionCode) : null;
      return {
        ...c,
        region: regionCode,
        area: area ?? '—',
        rides: rideCountMap.get(c.id) ?? 0,
        food: foodCountMap.get(c.id) ?? 0,
        delivery: parcelCountMap.get(c.id) ?? 0,
        spend: spendMap.get(c.id) ?? 0,
      };
    });
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
    const db = this.prisma.db();

    let kycDetail: OpsDriverKycInfo | null = null;
    let activeJob: OpsDriverActiveJob | null = null;
    let performance7d: OpsDriverDailyPerformance[] = [];
    let stats: OpsDriverStats | null = null;

    if (db) {
      // 1. Partner application for vehicle & KYC info
      try {
        const app = await db.partnerApplication.findFirst({
          where: { userId: id, role: 'DRIVER' },
          orderBy: { createdAt: 'desc' },
        });
        if (app) {
          const meta = (app.metadata ?? {}) as Record<string, unknown>;
          kycDetail = {
            applicationId: app.id,
            status: app.status,
            vehicleType: typeof meta.vehicleType === 'string' ? meta.vehicleType : null,
            vehiclePlate: typeof meta.vehiclePlate === 'string' ? meta.vehiclePlate : null,
            vehicleBrand: typeof meta.vehicleBrand === 'string' ? meta.vehicleBrand : null,
            vehicleModel: typeof meta.vehicleModel === 'string' ? meta.vehicleModel : null,
            vehicleClassCode: typeof meta.vehicleClassCode === 'string' ? meta.vehicleClassCode : null,
            licenseClass: typeof meta.licenseClass === 'string' ? meta.licenseClass : null,
            licenseNumber: typeof meta.licenseNumber === 'string' ? meta.licenseNumber : null,
            bankName: typeof meta.bankName === 'string' ? meta.bankName : null,
            bankAccountNumber: typeof meta.bankAccountNumber === 'string' ? meta.bankAccountNumber : null,
            bankAccountHolder: typeof meta.bankAccountHolder === 'string' ? meta.bankAccountHolder : null,
            documentsWaived: meta.documentsWaived === true,
            documentCount: Array.isArray(app.documents) ? app.documents.length : 0,
            submittedAt: app.submittedAt?.toISOString() ?? null,
            reviewedAt: app.reviewedAt?.toISOString() ?? null,
          };
        }
      } catch {
        // Non-blocking
      }

      // 2. Active ride or active food order
      try {
        const activeRide = await db.ride.findFirst({
          where: {
            assignedDriverId: id,
            status: { in: ['ASSIGNED', 'ARRIVING', 'ARRIVED', 'IN_PROGRESS', 'IN_TRIP' as any] },
          },
          include: { customer: { select: { displayName: true } } },
        });
        if (activeRide) {
          activeJob = {
            type: 'RIDE',
            id: activeRide.id,
            code: `DGX-${activeRide.id.slice(0, 8).toUpperCase()}`,
            status: activeRide.status,
            statusLabel: RIDE_STATUS_LABEL[activeRide.status] ?? activeRide.status,
            customerName: activeRide.customer?.displayName ?? 'Khách hàng',
            pickupLabel: activeRide.pickupLabel,
            dropoffLabel: activeRide.dropoffLabel,
            fareVnd: activeRide.agreedFareVnd ?? activeRide.offeredFareVnd,
            createdAt: activeRide.createdAt.toISOString(),
          };
        } else {
          const activeFood = await db.foodOrder.findFirst({
            where: {
              assignedDriverId: id,
              status: { in: ['ASSIGNED', 'PICKED_UP'] },
            },
            include: {
              customer: { select: { displayName: true } },
              store: { select: { name: true } },
            },
          });
          if (activeFood) {
            activeJob = {
              type: 'FOOD',
              id: activeFood.id,
              code: `FA-${activeFood.id.slice(0, 8).toUpperCase()}`,
              status: activeFood.status,
              statusLabel: FOOD_STATUS_LABEL[activeFood.status] ?? activeFood.status,
              customerName: activeFood.customer?.displayName ?? 'Khách hàng',
              pickupLabel: activeFood.store?.name ?? 'Cửa hàng',
              dropoffLabel: activeFood.dropoffLabel,
              fareVnd: activeFood.totalVnd,
              createdAt: activeFood.createdAt.toISOString(),
            };
          }
        }
      } catch {
        // Non-blocking
      }

      // 3. Stats (trips completed, rating, completion rate)
      try {
        const [completedRides, finishedRides, completedFood, finishedFood] = await Promise.all([
          db.ride.count({ where: { assignedDriverId: id, status: 'COMPLETED' } }),
          db.ride.count({ where: { assignedDriverId: id, status: { in: ['COMPLETED', 'CANCELLED'] } } }),
          db.foodOrder.count({ where: { assignedDriverId: id, status: 'DELIVERED' } }),
          db.foodOrder.count({ where: { assignedDriverId: id, status: { in: ['DELIVERED', 'CANCELLED'] } } }),
        ]);
        const completedJobs = completedRides + completedFood;
        const finishedJobs = finishedRides + finishedFood;
        const completionRate = finishedJobs > 0 ? Math.round((completedJobs / finishedJobs) * 1000) / 1000 : null;

        const ratingAgg = await db.serviceRating.aggregate({
          where: { driverId: id, driverStars: { not: null } },
          _avg: { driverStars: true },
          _count: { driverStars: true },
        });

        stats = {
          completedRides,
          completedFoodOrders: completedFood,
          finishedJobs,
          completionRate,
          ratingAverage: ratingAgg._avg.driverStars ? Math.round(ratingAgg._avg.driverStars * 10) / 10 : null,
          ratingCount: ratingAgg._count.driverStars ?? 0,
        };
      } catch {
        // Non-blocking
      }

      // 4. Performance last 7 days
      try {
        performance7d = await this.buildDriverPerformance7d(db, id);
      } catch {
        // Non-blocking
      }
    }

    return {
      ...user,
      presence: mapPresence(presence),
      kycDetail,
      activeJob,
      performance7d,
      stats: stats ?? undefined,
    };
  }

  async getDriverActivities(
    id: string,
    options: { tab?: string; page?: number; limit?: number },
  ): Promise<{
    items: OpsDriverActivityItem[];
    page: number;
    limit: number;
    total: number;
    tab: string;
  }> {
    await this.getByRole(id, 'DRIVER');

    const page = Math.max(1, options.page ?? 1);
    const limit = Math.max(1, Math.min(50, options.limit ?? 10));
    const tab = options.tab || 'Tất cả';
    const tabKey = normalizeDriverActivityTab(tab);

    const db = this.prisma.db();
    if (!db) {
      return { items: [], page, limit, total: 0, tab };
    }

    type ActivityRow = OpsDriverActivityItem & { sortAt: number };
    const activities: ActivityRow[] = [];

    if (tabKey === 'ALL' || tabKey === 'RIDES') {
      const rides = await db.ride.findMany({
        where: { assignedDriverId: id },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
      for (const ride of rides) {
        const fare = ride.agreedFareVnd ?? ride.offeredFareVnd;
        activities.push({
          time: formatActivityTime(ride.createdAt),
          code: `DGX-${ride.id.slice(0, 8).toUpperCase()}`,
          kind: 'Chuyến xe',
          summary: `${ride.pickupLabel} → ${ride.dropoffLabel}`,
          value: formatVnd(fare),
          status: RIDE_STATUS_LABEL[ride.status] ?? ride.status,
          tone: ride.status === 'COMPLETED' ? 'success' : ride.status === 'CANCELLED' ? 'danger' : 'brand',
          sortAt: ride.createdAt.getTime(),
        });
      }
    }

    if (tabKey === 'ALL' || tabKey === 'FOOD') {
      const orders = await db.foodOrder.findMany({
        where: { assignedDriverId: id },
        include: { store: { select: { name: true } } },
        orderBy: { createdAt: 'desc' },
        take: 100,
      });
      for (const order of orders) {
        activities.push({
          time: formatActivityTime(order.createdAt),
          code: `FA-${order.id.slice(0, 8).toUpperCase()}`,
          kind: 'Giao đồ ăn',
          summary: order.store?.name
            ? `${order.store.name} → ${order.dropoffLabel}`
            : order.dropoffLabel,
          value: formatVnd(order.totalVnd),
          status: FOOD_STATUS_LABEL[order.status] ?? order.status,
          tone: order.status === 'DELIVERED' ? 'success' : order.status === 'CANCELLED' ? 'danger' : 'brand',
          sortAt: order.createdAt.getTime(),
        });
      }
    }

    if (tabKey === 'ALL' || tabKey === 'EARNINGS') {
      const earnings = await db.jobEarning.findMany({
        where: { driverId: id },
        orderBy: { completedAt: 'desc' },
        take: 100,
      });
      for (const earning of earnings) {
        const prefix = earning.entityType === 'RIDE' ? 'DGX' : 'FA';
        activities.push({
          time: formatActivityTime(earning.completedAt),
          code: `ERN-${earning.id.slice(0, 8).toUpperCase()}`,
          kind: 'Thu nhập',
          summary: `Quyết toán chuyến ${prefix}-${earning.entityId.slice(0, 8).toUpperCase()} (Cước ${formatVnd(earning.fareVnd)} - Phí ${formatVnd(earning.feeVnd)})`,
          value: `+${formatVnd(earning.netVnd)}`,
          status: 'Thành công',
          tone: 'success',
          sortAt: earning.completedAt.getTime(),
        });
      }
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

  private async buildDriverPerformance7d(
    db: any,
    driverId: string,
  ): Promise<OpsDriverDailyPerformance[]> {
    const now = new Date();
    const days: OpsDriverDailyPerformance[] = [];
    const dayNames = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    const startOf7Days = new Date(now);
    startOf7Days.setDate(startOf7Days.getDate() - 6);
    startOf7Days.setHours(0, 0, 0, 0);

    const [rides, orders, earnings] = await Promise.all([
      db.ride.findMany({
        where: {
          assignedDriverId: driverId,
          status: 'COMPLETED',
          createdAt: { gte: startOf7Days },
        },
        select: {
          agreedFareVnd: true,
          offeredFareVnd: true,
          createdAt: true,
        },
      }),
      db.foodOrder.findMany({
        where: {
          assignedDriverId: driverId,
          status: 'DELIVERED',
          createdAt: { gte: startOf7Days },
        },
        select: {
          deliveryFeeVnd: true,
          createdAt: true,
        },
      }),
      db.jobEarning.findMany({
        where: {
          driverId,
          completedAt: { gte: startOf7Days },
        },
        select: {
          fareVnd: true,
          feeVnd: true,
          netVnd: true,
          completedAt: true,
        },
      }),
    ]);

    for (let i = 0; i < 7; i++) {
      const d = new Date(startOf7Days);
      d.setDate(d.getDate() + i);
      const yyyy = d.getFullYear();
      const mm = String(d.getMonth() + 1).padStart(2, '0');
      const dd = String(d.getDate()).padStart(2, '0');
      const dateKey = `${yyyy}-${mm}-${dd}`;
      const dayLabel = `${dayNames[d.getDay()]}, ${dd}/${mm}`;

      const dayEarnings = earnings.filter((e: any) => {
        const ed = new Date(e.completedAt);
        return ed.getFullYear() === yyyy && ed.getMonth() === d.getMonth() && ed.getDate() === d.getDate();
      });

      let completedTrips = 0;
      let fareVnd = 0;
      let feeVnd = 0;
      let netVnd = 0;

      if (dayEarnings.length > 0) {
        completedTrips = dayEarnings.length;
        for (const e of dayEarnings) {
          fareVnd += e.fareVnd;
          feeVnd += e.feeVnd;
          netVnd += e.netVnd;
        }
      } else {
        const dayRides = rides.filter((r: any) => {
          const rd = new Date(r.createdAt);
          return rd.getFullYear() === yyyy && rd.getMonth() === d.getMonth() && rd.getDate() === d.getDate();
        });
        const dayOrders = orders.filter((o: any) => {
          const od = new Date(o.createdAt);
          return od.getFullYear() === yyyy && od.getMonth() === d.getMonth() && od.getDate() === d.getDate();
        });
        completedTrips = dayRides.length + dayOrders.length;
        for (const r of dayRides) {
          fareVnd += r.agreedFareVnd ?? r.offeredFareVnd ?? 0;
        }
        for (const o of dayOrders) {
          fareVnd += o.deliveryFeeVnd ?? 0;
        }
        feeVnd = Math.round(fareVnd * 0.15);
        netVnd = fareVnd - feeVnd;
      }

      days.push({
        date: dateKey,
        dayLabel,
        completedTrips,
        fareVnd,
        feeVnd,
        netVnd,
      });
    }

    return days;
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
    parcelEnabled: presence.parcelEnabled,
    updatedAt: presence.updatedAt.toISOString(),
  };
}

const RIDE_STATUS_LABEL: Record<string, string> = {
  NEGOTIATING: 'Đang thương lượng',
  OFFER_SELECTED: 'Đã chọn tài xế',
  CONFIRMED: 'Đã xác nhận',
  ASSIGNED: 'Đã gán tài xế',
  ARRIVING: 'Tài xế đang đến',
  DRIVER_EN_ROUTE: 'Tài xế đang đến',
  ARRIVED: 'Tài xế đã tới',
  DRIVER_ARRIVED: 'Tài xế đã tới',
  IN_PROGRESS: 'Đang chạy',
  IN_TRIP: 'Đang chạy',
  COMPLETED: 'Hoàn thành',
  CANCELLED: 'Đã hủy',
  EXPIRED: 'Hết hạn',
  SCHEDULED: 'Lên lịch',
};

const FOOD_STATUS_LABEL: Record<string, string> = {
  PLACED: 'Chờ xác nhận',
  CONFIRMED: 'Đã xác nhận',
  PREPARING: 'Đang chuẩn bị',
  READY: 'Sẵn sàng lấy',
  READY_FOR_PICKUP: 'Chờ tài xế lấy',
  ASSIGNED: 'Đã gán tài xế',
  DRIVER_ASSIGNED: 'Đã gán tài xế',
  PICKING_UP: 'Tài xế đang đến lấy',
  PICKED_UP: 'Đang giao hàng',
  DELIVERING: 'Đang giao hàng',
  DELIVERED: 'Đã giao thành công',
  CANCELLED: 'Đã hủy',
  FAILED: 'Thất bại',
};

function normalizeDriverActivityTab(
  tab: string,
): 'ALL' | 'RIDES' | 'FOOD' | 'EARNINGS' {
  const t = tab.trim().toUpperCase();
  if (t === 'RIDES' || tab === 'Chuyến xe') return 'RIDES';
  if (t === 'FOOD' || tab === 'Đồ ăn' || tab === 'Giao đồ ăn') return 'FOOD';
  if (t === 'EARNINGS' || tab === 'Thu nhập') return 'EARNINGS';
  return 'ALL';
}

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
