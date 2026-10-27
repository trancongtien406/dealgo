import { describe, expect, it } from 'vitest';
import { MemoryPromotionRepository } from '../promotion/promotion.repository.js';
import { VoucherRejectedError } from '../promotion/promotion-redemption.js';
import type { PromotionCampaign } from '../promotion/promotion.types.js';
import { MemoryFoodRepository } from './food.repository.js';

const dropoff = { lat: 16.05, lng: 108.2, label: 'Hải Châu' };

function campaign(overrides: Partial<PromotionCampaign> = {}): PromotionCampaign {
  const now = Date.now();
  return {
    id: 'promo-1',
    code: 'FOOD20',
    name: 'Giảm 20k',
    description: 'Giảm 20k cho đơn đồ ăn',
    serviceType: 'FOOD',
    discountType: 'FIXED_AMOUNT',
    discountValue: 20_000,
    minOrderAmount: 0,
    totalBudget: 1_000_000,
    usedBudget: 0,
    usageLimit: 100,
    usedCount: 0,
    userLimit: 1,
    targetAudience: 'ALL',
    status: 'ACTIVE',
    startDate: new Date(now - 60_000).toISOString(),
    endDate: new Date(now + 3_600_000).toISOString(),
    sponsor: 'PLATFORM',
    createdAt: new Date(now).toISOString(),
    updatedAt: new Date(now).toISOString(),
    ...overrides,
  };
}

async function setup(seed: PromotionCampaign[]) {
  const promotions = new MemoryPromotionRepository(seed);
  const food = new MemoryFoodRepository(promotions);
  await food.createFixtureStore('owner-1', [{ name: 'Phở bò', priceVnd: 50_000 }]);
  const store = (await food.findStoreByOwner('owner-1'))!;
  const place = (customerId: string, key: string, voucherCode?: string) =>
    food.place({
      customerId,
      storeId: store.id,
      idempotencyKey: key,
      items: [{ itemId: store.items[0].id, quantity: 1 }],
      dropoff,
      deliveryFareVnd: 15_000,
      voucherCode,
    });
  return { promotions, food, place };
}


const FAIL = { reasonCode: 'CUSTOMER_REFUSED', note: null, minWaitMinutes: 0, now: new Date() };
describe('food checkout vouchers', () => {
  it('snapshots the discount on the order and nets it out of the total', async () => {
    const { promotions, place } = await setup([campaign()]);
    const order = await place('cust-1', 'k1', ' food20 ');
    expect(order.discountVnd).toBe(20_000);
    expect(order.voucherCode).toBe('FOOD20');
    expect(order.totalVnd).toBe(50_000 + 15_000 - 20_000);
    const after = await promotions.findByCode('FOOD20');
    expect(after?.usedCount).toBe(1);
    expect(after?.usedBudget).toBe(20_000);
  });

  it('enforces userLimit across active orders', async () => {
    const { food, place } = await setup([campaign({ userLimit: 1 })]);
    const first = await place('cust-1', 'k1', 'FOOD20');
    await food.accept(first.id, 'owner-1');
    await food.markReady(first.id, 'owner-1');
    await food.claim(first.id, 'driver-1', 1);
    await food.pickup(first.id, 'driver-1');
    await food.deliver(first.id, 'driver-1');
    await expect(place('cust-1', 'k2', 'FOOD20')).rejects.toMatchObject({
      code: 'VOUCHER_USER_LIMIT',
    });
  });

  it('gives the use and budget back when the order is cancelled, once', async () => {
    const { promotions, food, place } = await setup([campaign({ userLimit: 1 })]);
    const first = await place('cust-1', 'k1', 'FOOD20');
    await food.cancel(first.id, 'cust-1');
    let after = await promotions.findByCode('FOOD20');
    expect(after?.usedCount).toBe(0);
    expect(after?.usedBudget).toBe(0);
    expect(await promotions.release({ entityType: 'FOOD_ORDER', entityId: first.id })).toBe(false);
    after = await promotions.findByCode('FOOD20');
    expect(after?.usedCount).toBe(0);
    const again = await place('cust-1', 'k2', 'FOOD20');
    expect(again.discountVnd).toBe(20_000);
  });

  it('gives the use back once when the delivery fails', async () => {
    const { promotions, food, place } = await setup([campaign({ userLimit: 1 })]);
    const order = await place('cust-1', 'k1', 'FOOD20');
    await food.accept(order.id, 'owner-1');
    await food.markReady(order.id, 'owner-1');
    await food.claim(order.id, 'driver-1', 1);
    await food.pickup(order.id, 'driver-1');
    await food.fail(order.id, 'driver-1', FAIL);
    expect((await promotions.findByCode('FOOD20'))?.usedCount).toBe(0);
    expect(await promotions.release({ entityType: 'FOOD_ORDER', entityId: order.id })).toBe(false);
    await expect(food.fail(order.id, 'driver-1', FAIL)).rejects.toMatchObject({
      code: 'FOOD_STATUS_CONFLICT',
    });
    expect((await promotions.findByCode('FOOD20'))?.usedCount).toBe(0);
    expect((await place('cust-1', 'k2', 'FOOD20')).discountVnd).toBe(20_000);
  });

  it('gives the use back when ops cancels the order', async () => {
    const { promotions, food, place } = await setup([campaign()]);
    const order = await place('cust-1', 'k1', 'FOOD20');
    await food.opsCancel(order.id, 'ops-1', 'test');
    expect((await promotions.findByCode('FOOD20'))?.usedCount).toBe(0);
  });

  it('rejects an exhausted budget and leaves the campaign untouched', async () => {
    const { promotions, place } = await setup([
      campaign({ totalBudget: 30_000, usedBudget: 15_000 }),
    ]);
    await expect(place('cust-1', 'k1', 'FOOD20')).rejects.toBeInstanceOf(VoucherRejectedError);
    expect((await promotions.findByCode('FOOD20'))?.usedCount).toBe(0);
  });

  it('rejects a ride-only voucher on a food order', async () => {
    const { place } = await setup([campaign({ serviceType: 'RIDE' })]);
    await expect(place('cust-1', 'k1', 'FOOD20')).rejects.toMatchObject({
      code: 'VOUCHER_WRONG_SERVICE',
    });
  });

  it('snapshots the campaign sponsor on the order', async () => {
    const { food, place } = await setup([campaign({ sponsor: 'SHARED' })]);
    const order = await place('cust-1', 'k1', 'FOOD20');
    expect(order.voucherSponsor).toBe('SHARED');
    expect((await food.findOrder(order.id))?.voucherSponsor).toBe('SHARED');
    expect((await place('cust-2', 'k2')).voucherSponsor).toBeNull();
  });

  it('keeps the order picked up when the delivery hook fails', async () => {
    const { food, place } = await setup([campaign()]);
    const order = await place('cust-1', 'k1', 'FOOD20');
    await food.accept(order.id, 'owner-1');
    await food.markReady(order.id, 'owner-1');
    await food.claim(order.id, 'driver-1', 1);
    await food.pickup(order.id, 'driver-1');
    await expect(
      food.deliver(order.id, 'driver-1', async (_tx, delivered) => {
        expect(delivered.status).toBe('DELIVERED');
        throw new Error('ledger down');
      }),
    ).rejects.toThrow('ledger down');
    expect((await food.findOrder(order.id))?.status).toBe('PICKED_UP');
    expect((await food.deliver(order.id, 'driver-1')).status).toBe('DELIVERED');
  });

  it('places normally without a voucher', async () => {
    const { place } = await setup([campaign()]);
    const order = await place('cust-1', 'k1');
    expect(order.discountVnd).toBe(0);
    expect(order.voucherCode).toBeNull();
    expect(order.totalVnd).toBe(65_000);
  });

  it('does not redeem twice on an idempotent replay', async () => {
    const { promotions, place } = await setup([campaign({ userLimit: 5 })]);
    const a = await place('cust-1', 'same', 'FOOD20');
    const b = await place('cust-1', 'same', 'FOOD20');
    expect(b.id).toBe(a.id);
    expect((await promotions.findByCode('FOOD20'))?.usedCount).toBe(1);
  });

  it('exposes store name and address on ready jobs', async () => {
    const { food, place } = await setup([campaign()]);
    await food.updateStoreLocation({
      ownerId: 'owner-1',
      lat: 16.06,
      lng: 108.21,
      addressLabel: ' 12 Bạch Đằng, Hải Châu ',
    });
    const order = await place('cust-1', 'k1');
    await food.accept(order.id, 'owner-1');
    await food.markReady(order.id, 'owner-1');
    const [ready] = await food.listReady();
    expect(ready.storeName).toBeTruthy();
    expect(ready.storeAddress).toBe('12 Bạch Đằng, Hải Châu');
  });
});
