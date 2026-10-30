/** DEC-PROD-071: parcel bookings check the admin PARCEL on/off column, not BIKE/CAR. */
import { describe, expect, it } from 'vitest';
import { RideService } from './ride.service.js';

type Resolver = (vehicle: string, requested?: string, parcel?: boolean) => Promise<string>;

function serviceWith(enabled: Record<string, string[]>) {
  const asked: string[] = [];
  const svc = Object.create(RideService.prototype) as Record<string, unknown>;
  svc.paymentMethods = {
    assertSelectable: async (service: string, code: string) => {
      asked.push(service);
      if (!(enabled[service] ?? []).includes(code)) {
        throw Object.assign(new Error('unavailable'), { status: 422 });
      }
      return code;
    },
  };
  const resolve = (svc.resolvePaymentMethod as Resolver).bind(svc);
  return { resolve, asked };
}

describe('RideService payment scope for parcels', () => {
  it('uses the PARCEL scope for parcel rides and BIKE/CAR for people rides', async () => {
    const { resolve, asked } = serviceWith({ PARCEL: ['MOMO'], BIKE: ['MOMO'] });
    await expect(resolve('MOTORBIKE', 'MOMO', true)).resolves.toBe('MOMO');
    await expect(resolve('MOTORBIKE', 'MOMO', false)).resolves.toBe('MOMO');
    expect(asked).toEqual(['PARCEL', 'BIKE']);
  });

  it('refuses a method the admin switched off for PARCEL even if BIKE allows it', async () => {
    const { resolve } = serviceWith({ PARCEL: [], BIKE: ['MOMO'] });
    await expect(resolve('MOTORBIKE', 'MOMO', true)).rejects.toMatchObject({ status: 422 });
  });

  it('cash is always allowed without asking the registry', async () => {
    const { resolve, asked } = serviceWith({});
    await expect(resolve('CAR_4', undefined, true)).resolves.toBe('CASH');
    expect(asked).toEqual([]);
  });
});
