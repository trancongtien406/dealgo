import { describe, expect, it } from 'vitest';
import { MemoryLedgerRepository } from '../ledger/ledger.repository.js';
import { LedgerService } from '../ledger/ledger.service.js';
import { percentToBps, splitFare } from './earnings.math.js';
import { MemoryEarningsRepository } from './earnings.repository.js';
import { driverCommissionSettingKey, EarningsService } from './earnings.service.js';

function setup(rates: Record<string, number>) {
  const ledgerRepo = new MemoryLedgerRepository();
  const settings = { getNumber: async (key: string) => rates[key] };
  const service = new EarningsService(
    new MemoryEarningsRepository(),
    settings as never,
    new LedgerService(ledgerRepo),
  );
  return { service, ledgerRepo, rates };
}

const job = (entityId: string, fareVnd: number, entityType: 'RIDE' | 'FOOD_ORDER' = 'RIDE') => ({
  entityType,
  entityId,
  driverId: 'drv',
  fareVnd,
  completedAt: new Date('2026-10-19T03:00:00.000Z'),
});

async function record(service: EarningsService, input: ReturnType<typeof job>) {
  return service.recordWithin(null, {
    ...input,
    feeBps: await service.currentFeeBps(input.entityType),
  });
}

describe('earnings math', () => {
  it('converts percent to basis points and rounds the fee half-up', () => {
    expect(percentToBps(12.5)).toBe(1250);
    expect(percentToBps(0)).toBe(0);
    expect(percentToBps(100)).toBe(10_000);
    expect(() => percentToBps(100.01)).toThrow();
    expect(splitFare(42_000, 1250)).toEqual({ feeVnd: 5250, netVnd: 36_750 });
    expect(splitFare(10_001, 1500)).toEqual({ feeVnd: 1500, netVnd: 8501 });
    expect(splitFare(15_003, 3333)).toEqual({ feeVnd: 5000, netVnd: 10_003 });
    expect(splitFare(0, 2000)).toEqual({ feeVnd: 0, netVnd: 0 });
  });
});

describe('EarningsService', () => {
  it('snapshots the rate per service and posts a balanced fee journal once', async () => {
    const { service, ledgerRepo } = setup({
      RIDE_COMMISSION_BIKE_PERCENT: 12.5,
      FOOD_DRIVER_COMMISSION_PERCENT: 10,
    });
    const ride = await record(service, job('r1', 42_000));
    expect(ride).toMatchObject({ feeBps: 1250, feeVnd: 5250, netVnd: 36_750 });
    const food = await record(service, job('o1', 18_000, 'FOOD_ORDER'));
    expect(food).toMatchObject({ feeBps: 1000, feeVnd: 1800, netVnd: 16_200 });

    const journal = await ledgerRepo.findByEntity('RIDE', 'r1', 'DRIVER_PLATFORM_FEE_ACCRUED');
    expect(journal?.amountVnd).toBe(5250);
    expect(journal?.entries.map((e) => [e.accountCode, e.direction, e.amountVnd])).toEqual([
      ['sandbox.fee.driver_receivable', 'DEBIT', 5250],
      ['sandbox.fee.platform_revenue', 'CREDIT', 5250],
    ]);
    // A retry keeps the snapshot and does not post a second journal.
    const again = await record(service, job('r1', 42_000));
    expect(again.id).toBe(ride.id);
    expect((await ledgerRepo.findByEntity('RIDE', 'r1', 'DRIVER_PLATFORM_FEE_ACCRUED'))?.id).toBe(
      journal?.id,
    );
  });

  it('keeps history when the admin changes the rate later', async () => {
    const { service, rates } = setup({ RIDE_COMMISSION_BIKE_PERCENT: 10 });
    await record(service, job('r1', 50_000));
    rates.RIDE_COMMISSION_BIKE_PERCENT = 30;
    await record(service, job('r2', 50_000));
    const map = await service.findMany([
      { entityType: 'RIDE', entityId: 'r1' },
      { entityType: 'RIDE', entityId: 'r2' },
    ]);
    expect(map.get('RIDE:r1')).toMatchObject({ feeBps: 1000, feeVnd: 5000, netVnd: 45_000 });
    expect(map.get('RIDE:r2')).toMatchObject({ feeBps: 3000, feeVnd: 15_000, netVnd: 35_000 });
  });

  it('records a zero fee without a journal and refuses an invalid rate', async () => {
    const { service, ledgerRepo } = setup({ RIDE_COMMISSION_BIKE_PERCENT: 0 });
    expect(await record(service, job('r1', 30_000))).toMatchObject({
      feeVnd: 0,
      netVnd: 30_000,
    });
    expect(await ledgerRepo.findByEntity('RIDE', 'r1', 'DRIVER_PLATFORM_FEE_ACCRUED')).toBeNull();
    // An out-of-range rate fails loudly before the completion transaction opens.
    const broken = setup({ RIDE_COMMISSION_BIKE_PERCENT: 250 });
    await expect(broken.service.currentFeeBps('RIDE')).rejects.toThrow();
  });

  it('Picks the commission per service (motorbike, car, food delivery)', async () => {
    expect(driverCommissionSettingKey('RIDE', 'MOTORBIKE')).toBe('RIDE_COMMISSION_BIKE_PERCENT');
    expect(driverCommissionSettingKey('RIDE', 'BIKE_PLUS')).toBe('RIDE_COMMISSION_BIKE_PERCENT');
    expect(driverCommissionSettingKey('RIDE', undefined)).toBe('RIDE_COMMISSION_BIKE_PERCENT');
    expect(driverCommissionSettingKey('RIDE', 'CAR_4')).toBe('RIDE_COMMISSION_CAR_PERCENT');
    expect(driverCommissionSettingKey('RIDE', 'CAR_7')).toBe('RIDE_COMMISSION_CAR_PERCENT');
    expect(driverCommissionSettingKey('FOOD_ORDER', 'CAR_4')).toBe('FOOD_DRIVER_COMMISSION_PERCENT');
    const { service } = setup({
      RIDE_COMMISSION_BIKE_PERCENT: 10,
      RIDE_COMMISSION_CAR_PERCENT: 15,
      FOOD_DRIVER_COMMISSION_PERCENT: 0,
    });
    expect(await service.currentFeeBps('RIDE', 'MOTORBIKE')).toBe(1000);
    expect(await service.currentFeeBps('RIDE', 'CAR_4')).toBe(1500);
    expect(await service.currentFeeBps('FOOD_ORDER')).toBe(0);
  });
});
