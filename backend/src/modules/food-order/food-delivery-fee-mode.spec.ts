import { ConfigService } from '@nestjs/config';
import { describe, expect, it } from 'vitest';
import { MemoryPlatformSettingsRepository } from '../../platform/settings/platform-settings.repository.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { FoodService } from './food.service.js';

const ACTOR = '00000000-0000-4000-8000-000000000001';

function settingsService() {
  return new PlatformSettingsService(new MemoryPlatformSettingsRepository(), new ConfigService({}) as never);
}

/** Only the settings-backed mode helpers are exercised; other deps are never touched. */
function foodWith(settings: PlatformSettingsService) {
  const svc = Object.create(FoodService.prototype) as FoodService;
  (svc as unknown as { settings: PlatformSettingsService }).settings = settings;
  return svc;
}

describe('FOOD_DELIVERY_FEE_MODE', () => {
  it('seeds NEGOTIATE under DISPATCH', async () => {
    const view = (await settingsService().list()).find((v) => v.key === 'FOOD_DELIVERY_FEE_MODE');
    expect(view?.value).toBe('NEGOTIATE');
    const dispatch = await settingsService().list({ category: 'DISPATCH', source: 'ALL' });
    expect(dispatch.some((v) => v.key === 'FOOD_DELIVERY_FEE_MODE')).toBe(true);
  });

  it('accepts only NEGOTIATE or FIXED (case-insensitive)', async () => {
    const settings = settingsService();
    await expect(settings.patch('FOOD_DELIVERY_FEE_MODE', 'AUCTION', 'thử', ACTOR)).rejects.toMatchObject({
      response: { errorCode: 'PLATFORM_SETTING_INVALID' },
    });
    const view = await settings.patch('FOOD_DELIVERY_FEE_MODE', ' fixed ', 'giá cố định', ACTOR);
    expect(view.value).toBe('FIXED');
  });

  it('FIXED rejects driver counters and customer selection with FOOD_FEE_NEGOTIATION_DISABLED', async () => {
    const settings = settingsService();
    await settings.patch('FOOD_DELIVERY_FEE_MODE', 'FIXED', 'giá cố định', ACTOR);
    const food = foodWith(settings);
    expect(await food.deliveryFeeMode()).toBe('FIXED');
    await expect(food.counterDeliveryOffer({ userId: 'drv-a' } as never, 'order-1', 20_000)).rejects.toMatchObject({
      status: 409,
      response: { errorCode: 'FOOD_FEE_NEGOTIATION_DISABLED' },
    });
    (food as unknown as { requireOwnOrder: () => Promise<{ id: string }> }).requireOwnOrder = async () => ({ id: 'order-1' });
    await expect(food.selectDeliveryOffer({ userId: 'cust-1' } as never, 'order-1', 'offer-1')).rejects.toMatchObject({
      response: { errorCode: 'FOOD_FEE_NEGOTIATION_DISABLED' },
    });
  });

  it('NEGOTIATE is the default mode', async () => {
    expect(await foodWith(settingsService()).deliveryFeeMode()).toBe('NEGOTIATE');
  });
});
