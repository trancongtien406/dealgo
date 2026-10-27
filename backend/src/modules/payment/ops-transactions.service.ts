import { prismaDateFilter, type OpsDateWindow } from '../operations/ops-date-window.js';
import { Injectable } from '@nestjs/common';
import { normalizeLimit, normalizePage, type PageResult } from '../../shared/pagination/pagination.js';
import { PrismaService } from '../../platform/database/prisma.service.js';
import {
  paymentFilterMatchers,
  paymentMethodDisplay,
} from './ops-payment-filter.js';

export type OpsTransactionItem = {
  code: string;
  time: string;
  service: 'FOOD' | 'RIDE' | 'DELIVERY';
  orderCode: string;
  customer: string;
  method: string;
  amount: number;
  status: 'COLLECTED' | 'COD_PENDING' | 'COD_CONFIRMED' | 'PROCESSING' | 'FAILED';
  area: string;
};

@Injectable()
export class OpsTransactionsService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    page?: number,
    limit?: number,
    filters?: {
      q?: string;
      status?: string;
      service?: string;
      payment?: string;
      window?: OpsDateWindow;
    },
  ): Promise<PageResult<OpsTransactionItem>> {
    const safePage = normalizePage(page);
    const safeLimit = normalizeLimit(limit);

    const db = this.prisma.db();
    if (!db) {
      return { items: [], total: 0, page: safePage, limit: safeLimit };
    }

    let allItems: OpsTransactionItem[] = [];
    try {
      const createdAt = prismaDateFilter(filters?.window);
      const intents = await db.paymentIntent.findMany({
        ...(createdAt ? { where: { createdAt } } : {}),
        orderBy: { createdAt: 'desc' },
        take: 200,
      });

      const rideIds = intents
        .filter((pi) => pi.entityType === 'RIDE')
        .map((pi) => pi.entityId);
      const foodIds = intents
        .filter((pi) => pi.entityType === 'FOOD_ORDER')
        .map((pi) => pi.entityId);

      const [rides, foods] = await Promise.all([
        rideIds.length
          ? db.ride.findMany({
              where: { id: { in: rideIds } },
              select: {
                id: true,
                pickupLabel: true,
                serviceRegionCode: true,
                customer: { select: { displayName: true } },
              },
            })
          : Promise.resolve([]),
        foodIds.length
          ? db.foodOrder.findMany({
              where: { id: { in: foodIds } },
              select: {
                id: true,
                dropoffLabel: true,
                serviceRegionCode: true,
                customer: { select: { displayName: true } },
              },
            })
          : Promise.resolve([]),
      ]);

      const rideById = new Map(rides.map((r) => [r.id, r]));
      const foodById = new Map(foods.map((f) => [f.id, f]));

      allItems = intents.map((pi) => {
        const service = pi.entityType === 'RIDE' ? 'RIDE' : 'FOOD';
        const method = paymentMethodDisplay(pi.method);
        const status =
          pi.status === 'CAPTURED_STUB'
            ? 'COLLECTED'
            : pi.method === 'COD'
              ? 'COD_PENDING'
              : 'PROCESSING';

        let customer = '—';
        let area = '—';
        if (pi.entityType === 'RIDE') {
          const ride = rideById.get(pi.entityId);
          customer = ride?.customer.displayName ?? '—';
          area = ride?.serviceRegionCode ?? shortArea(ride?.pickupLabel) ?? '—';
        } else {
          const food = foodById.get(pi.entityId);
          customer = food?.customer.displayName ?? '—';
          area = food?.serviceRegionCode ?? shortArea(food?.dropoffLabel) ?? '—';
        }

        return {
          code: `GD-${pi.id.slice(0, 8).toUpperCase()}`,
          time: pi.createdAt.toISOString().slice(5, 16).replace('T', ' · '),
          service,
          orderCode: `${service === 'RIDE' ? 'DGX' : 'FA'}-${pi.entityId.slice(0, 8).toUpperCase()}`,
          customer,
          method,
          amount: pi.amountVnd,
          status,
          area,
        } satisfies OpsTransactionItem;
      });
    } catch {
      return { items: [], total: 0, page: safePage, limit: safeLimit };
    }

    let filtered = allItems;

    if (filters?.status && filters.status !== 'ALL') {
      filtered = filtered.filter((row) => row.status === filters.status);
    }

    if (filters?.service && filters.service !== 'ALL') {
      const s = filters.service.toUpperCase();
      filtered = filtered.filter((row) => row.service === s);
    }

    if (filters?.payment && filters.payment !== 'ALL') {
      const { methodNeedles } = paymentFilterMatchers(filters.payment);
      filtered = filtered.filter((row) => {
        const method = row.method.toLowerCase();
        return methodNeedles.some(
          (needle) => method.includes(needle) || needle.includes(method),
        );
      });
    }

    if (filters?.q?.trim()) {
      const q = filters.q.trim().toLowerCase();
      filtered = filtered.filter(
        (row) =>
          row.code.toLowerCase().includes(q) ||
          row.orderCode.toLowerCase().includes(q) ||
          row.customer.toLowerCase().includes(q) ||
          row.area.toLowerCase().includes(q) ||
          row.method.toLowerCase().includes(q),
      );
    }

    const total = filtered.length;
    const start = (safePage - 1) * safeLimit;
    const items = filtered.slice(start, start + safeLimit);

    return {
      items,
      total,
      page: safePage,
      limit: safeLimit,
    };
  }
}

function shortArea(label: string | null | undefined): string | null {
  if (!label) return null;
  const part = label.split(/[,·|]/)[0]?.trim();
  return part && part.length > 0 ? part.slice(0, 40) : null;
}
