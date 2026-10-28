import { vi } from 'vitest';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import { MemoryPromotionRepository } from './promotion.repository.js';
import { INITIAL_PROMOTION_SEED } from './promotion.seed.js';
import { PromotionService } from './promotion.service.js';

describe('PromotionService', () => {
  let service: PromotionService;

  beforeEach(() => {
    service = new PromotionService(
      new MemoryPromotionRepository(INITIAL_PROMOTION_SEED),
    );
  });

  describe('Listing and Filtering', () => {
    it('returns seeded promotions with pagination and KPI summary', async () => {
      const res = await service.listPromotions({ page: 1, limit: 10 });
      expect(res.total).toBeGreaterThanOrEqual(8);
      expect(res.items.length).toBeGreaterThan(0);
      expect(res.kpi).toBeDefined();
      expect(res.kpi.totalCampaigns).toBeGreaterThanOrEqual(8);
      expect(res.kpi.activeCount).toBeGreaterThan(0);
    });

    it('filters by status', async () => {
      const res = await service.listPromotions({ status: 'ACTIVE' });
      expect(res.items.every((item) => item.status === 'ACTIVE')).toBe(true);
    });

    it('filters by serviceType', async () => {
      const res = await service.listPromotions({ serviceType: 'RIDE' });
      expect(
        res.items.every(
          (item) => item.serviceType === 'RIDE' || item.serviceType === 'ALL',
        ),
      ).toBe(true);
    });

    it('filters by query text (code or name)', async () => {
      const res = await service.listPromotions({ q: 'DEALGO20K' });
      expect(res.items.length).toBe(1);
      expect(res.items[0].code).toBe('DEALGO20K');
    });
  });

  describe('Status Transition', () => {
    it('allows pausing an active campaign and resuming it', async () => {
      const active = (await service.listPromotions({ status: 'ACTIVE' }))
        .items[0];
      const paused = await service.updateStatus(active.id, 'PAUSED');
      expect(paused.status).toBe('PAUSED');

      const resumed = await service.updateStatus(active.id, 'ACTIVE');
      expect(resumed.status).toBe('ACTIVE');
    });

    it('allows cancelling a campaign', async () => {
      const active = (await service.listPromotions({ status: 'ACTIVE' }))
        .items[0];
      const cancelled = await service.updateStatus(active.id, 'CANCELLED');
      expect(cancelled.status).toBe('CANCELLED');
    });
  });

  describe('Validation & Calculation Engine (Checkout)', () => {
    it('applies fixed amount discount correctly', async () => {
      // DEALGO20K: Fixed 20.000đ, min order 60.000đ
      const res = await service.validateAndCalculate({
        voucherCode: 'DEALGO20K',
        serviceType: 'FOOD',
        orderAmount: 100000,
      });

      expect(res.valid).toBe(true);
      expect(res.discountAmount).toBe(20000);
      expect(res.finalAmount).toBe(80000);
    });

    it('applies percentage discount with max cap correctly', async () => {
      // FOODIE30: 30% max 35.000đ, min order 100.000đ
      // Order 200.000đ -> 30% = 60.000đ -> capped at 35.000đ
      const res = await service.validateAndCalculate({
        voucherCode: 'FOODIE30',
        serviceType: 'FOOD',
        orderAmount: 200000,
      });

      expect(res.valid).toBe(true);
      expect(res.discountAmount).toBe(35000);
      expect(res.finalAmount).toBe(165000);
    });

    it('applies delivery fee discount up to delivery fee limit', async () => {
      // FREESHIPDN: delivery discount 15.000đ, min order 80.000đ
      const res = await service.validateAndCalculate({
        voucherCode: 'FREESHIPDN',
        serviceType: 'FOOD',
        orderAmount: 90000,
        deliveryFee: 12000, // fee is 12k, less than 15k discount
      });

      expect(res.valid).toBe(true);
      expect(res.discountAmount).toBe(12000); // capped at delivery fee
      expect(res.finalAmount).toBe(90000); // customer pays order 90k + (12k-12k)
    });

    it('rejects when order amount is less than minOrderAmount', async () => {
      const res = await service.validateAndCalculate({
        voucherCode: 'DEALGO20K',
        serviceType: 'FOOD',
        orderAmount: 40000, // min is 60k
      });

      expect(res.valid).toBe(false);
      expect(res.discountAmount).toBe(0);
      expect(res.reason).toContain('tối thiểu');
    });

    it('rejects when voucher code is not found', async () => {
      const res = await service.validateAndCalculate({
        voucherCode: 'NONEXISTENT',
        serviceType: 'RIDE',
        orderAmount: 50000,
      });

      expect(res.valid).toBe(false);
      expect(res.reason).toContain('không tồn tại');
    });

    it('rejects when serviceType does not match', async () => {
      // RIDEDONGGIA is only RIDE
      const res = await service.validateAndCalculate({
        voucherCode: 'RIDEDONGGIA',
        serviceType: 'FOOD',
        orderAmount: 50000,
      });

      expect(res.valid).toBe(false);
      expect(res.reason).toContain('dịch vụ');
    });

    it('rejects when voucher is not ACTIVE (e.g. PAUSED or ENDED)', async () => {
      // FLASHRIDE is PAUSED
      const res = await service.validateAndCalculate({
        voucherCode: 'FLASHRIDE',
        serviceType: 'RIDE',
        orderAmount: 50000,
      });

      expect(res.valid).toBe(false);
      expect(res.reason).toContain('tạm dừng');
    });

    it('ensures payable amount never drops below 0', async () => {
      // Order 15k, discount 20k -> final amount = 0
      const res = await service.validateAndCalculate({
        voucherCode: 'DEALGO20K',
        serviceType: 'RIDE',
        orderAmount: 15000,
      });

      // Still fails min order or if minOrder was 0, finalAmount >= 0
      expect(res.finalAmount).toBeGreaterThanOrEqual(0);
    });
  });

  describe('Create', () => {
    const base = {
      code: ' new50k ',
      name: 'Mã mới',
      description: 'Giảm 50.000đ',
      serviceType: 'ALL' as const,
      discountType: 'FIXED_AMOUNT' as const,
      discountValue: 50000,
      minOrderAmount: 100000,
      totalBudget: 1000000,
      usageLimit: 20,
      startDate: '2026-01-01T00:00:00.000Z',
      endDate: '2099-01-01T00:00:00.000Z',
    };

    it('normalizes the code and makes the campaign listable', async () => {
      const created = await service.create(base);
      expect(created.code).toBe('NEW50K');
      expect(created.usedCount).toBe(0);
      const found = await service.listPromotions({ q: 'NEW50K' });
      expect(found.items.map((item) => item.id)).toEqual([created.id]);
    });

    it('rejects a duplicate code regardless of case', async () => {
      await expect(
        service.create({ ...base, code: 'dealgo20k' }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('rejects an end date that is not after the start date', async () => {
      await expect(
        service.create({ ...base, endDate: base.startDate }),
      ).rejects.toBeInstanceOf(BadRequestException);
    });

    it('returns 404 for status updates on unknown campaigns', async () => {
      await expect(
        service.updateStatus('00000000-0000-4000-8000-000000000000', 'PAUSED'),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
  describe('Customer voucher list', () => {
    async function campaign(code: string, overrides: Record<string, unknown> = {}) {
      return service.create({
        code,
        name: `Voucher ${code}`,
        description: 'Giảm cho đơn đồ ăn',
        serviceType: 'FOOD',
        discountType: 'FIXED_AMOUNT',
        discountValue: 10000,
        minOrderAmount: 50000,
        totalBudget: 1_000_000,
        usageLimit: 100,
        userLimit: 1,
        startDate: '2026-10-01T00:00:00.000Z',
        endDate: '2026-11-01T00:00:00.000Z',
        ...overrides,
      } as never);
    }

    it('lists only running customer campaigns for the service, without internal fields', async () => {
      service = new PromotionService(new MemoryPromotionRepository([]));
      await campaign('FOODNOW');
      await campaign('RIDEONLY', { serviceType: 'RIDE' });
      await campaign('DRIVERS', { targetAudience: 'DRIVER' });
      await campaign('LATER', { startDate: '2026-10-25T00:00:00.000Z' });
      await campaign('OVER', { endDate: '2026-10-10T00:00:00.000Z' });
      const now = new Date('2026-10-19T03:00:00.000Z');

      const food = await service.listAvailableForCustomer('cust-1', 'FOOD', undefined, now);
      expect(food.map((v) => v.code)).toEqual(['FOODNOW']);
      expect(food[0]).toEqual({
        code: 'FOODNOW',
        name: 'Voucher FOODNOW',
        description: 'Giảm cho đơn đồ ăn',
        serviceType: 'FOOD',
        discountType: 'FIXED_AMOUNT',
        discountValue: 10000,
        maxDiscountVnd: null,
        minOrderVnd: 50000,
        endsAt: '2026-11-01T00:00:00.000Z',
        usesLeft: 1,
        storeId: null,
      });
      expect(Object.keys(food[0])).not.toContain('totalBudget');
      const all = await service.listAvailableForCustomer('cust-1', undefined, undefined, now);
      expect(all.map((v) => v.code).sort()).toEqual(['FOODNOW', 'RIDEONLY']);
    });

    it('drops used-up campaigns and keeps usesLeft aligned with the remaining ones', async () => {
      const repo = new MemoryPromotionRepository([]);
      service = new PromotionService(repo);
      await campaign('USED', { endDate: '2026-10-20T00:00:00.000Z' });
      await campaign('TWICE', { userLimit: 3 });
      const used = await service.listAvailableForCustomer('cust-1', 'FOOD', undefined, new Date('2026-10-19T03:00:00.000Z'));
      expect(used.map((v) => v.code)).toEqual(['USED', 'TWICE']);
      const usedId = (await repo.findByCode('USED'))?.id;
      vi.spyOn(repo, 'countUserRedemptions').mockImplementation(async (id: string) =>
        id === usedId ? 1 : 0,
      );
      const left = await service.listAvailableForCustomer('cust-1', 'FOOD', undefined, new Date('2026-10-19T03:00:00.000Z'));
      expect(left).toEqual([expect.objectContaining({ code: 'TWICE', usesLeft: 3 })]);
    });
  });
});
