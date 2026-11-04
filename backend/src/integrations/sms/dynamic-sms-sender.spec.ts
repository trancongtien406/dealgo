import { describe, expect, it, vi } from 'vitest';
import { DynamicSmsSender } from './dynamic-sms-sender.js';
import { MockSmsSender, UnavailableSmsSender } from './sms-sender.js';
import type { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import type { SmsEnv } from './sms-factory.js';

describe('DynamicSmsSender', () => {
  const env: SmsEnv = {
    NODE_ENV: 'test',
    SMS_PROVIDER: undefined,
    SMS_OTP_TEMPLATE: 'Code {code}',
    SMS_HTTP_TIMEOUT_MS: 8_000,
    SMS_HTTP_MAX_ATTEMPTS: 2,
  };

  it('falls back to env sender when settings is undefined or empty', async () => {
    const mockEnvSender = new MockSmsSender('test');
    const sendSpy = vi.spyOn(mockEnvSender, 'sendOtp');
    const dynamic = new DynamicSmsSender(mockEnvSender, env, 5);

    await dynamic.sendOtp('+84901234567', '123456');
    expect(sendSpy).toHaveBeenCalledWith('+84901234567', '123456');
    expect(await dynamic.isConfigured()).toBe(true);
  });

  it('resolves mock provider when configured in IntegrationSettings', async () => {
    const mockEnvSender = new UnavailableSmsSender();
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: { provider: 'mock' },
        secrets: {},
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicSmsSender(
      mockEnvSender,
      env,
      5,
      mockSettings as IntegrationSettingsService,
    );
    expect(await dynamic.isConfigured()).toBe(true);
    await expect(
      dynamic.sendOtp('+84901234567', '654321'),
    ).resolves.toBeUndefined();
  });

  it('resolves esms provider from IntegrationSettings with credentials', async () => {
    const mockEnvSender = new UnavailableSmsSender();
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: { provider: 'esms', brandname: 'DealGoTest' },
        secrets: { apiKey: 'key123', secretKey: 'sec123' },
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicSmsSender(
      mockEnvSender,
      env,
      5,
      mockSettings as IntegrationSettingsService,
    );
    expect(await dynamic.isConfigured()).toBe(true);
  });

  it('resolves speedsms provider from IntegrationSettings with credentials', async () => {
    const mockEnvSender = new UnavailableSmsSender();
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: { provider: 'speedsms', sender: 'DealGoSpeed' },
        secrets: { accessToken: 'token123' },
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicSmsSender(
      mockEnvSender,
      env,
      5,
      mockSettings as IntegrationSettingsService,
    );
    expect(await dynamic.isConfigured()).toBe(true);
  });

  it('returns unavailable when provider is set to none', async () => {
    const mockEnvSender = new MockSmsSender('test');
    const mockSettings: Partial<IntegrationSettingsService> = {
      values: vi.fn(async () => ({
        config: { provider: 'none' },
        secrets: {},
        updatedAt: null,
        updatedByUserId: null,
      })) as any,
    };

    const dynamic = new DynamicSmsSender(
      mockEnvSender,
      env,
      5,
      mockSettings as IntegrationSettingsService,
    );
    expect(await dynamic.isConfigured()).toBe(false);
  });
});
