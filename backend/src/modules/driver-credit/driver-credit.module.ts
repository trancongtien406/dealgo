import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import {
  PrismaModule,
  PrismaService,
  resolvePersistenceRepository,
} from '../../platform/database/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { PayosAdapter, VnpayAdapter } from '../../integrations/payment-gateways/providers/index.js';
import { EarningsModule } from '../earnings/earnings.module.js';
import { IdentityModule } from '../identity/identity.module.js';
import {
  DRIVER_CREDIT_REPOSITORY,
  DRIVER_TOP_UP_ADAPTERS,
  DRIVER_TOP_UP_PROVIDER,
  MemoryDriverCreditRepository,
  type DriverCreditRepository,
  type DriverTopUpProviderName,
} from './driver-credit.repository.js';
import { PrismaDriverCreditRepository } from './driver-credit-prisma.repository.js';
import { DriverCreditService, type DriverTopUpAdapters } from './driver-credit.service.js';
import { DriverCreditStatusBus } from './driver-credit-status.bus.js';
import { DriverCreditController } from './driver-credit.controller.js';
import { DriverCreditReturnController } from './driver-credit-return.controller.js';
import { OpsDriverCreditController } from './ops-driver-credit.controller.js';

export function driverTopUpProviderFrom(config: ConfigService<AppEnv, true>): DriverTopUpProviderName {
  const raw = config.get('DRIVER_TOP_UP_PROVIDER', { infer: true });
  return raw === 'vnpay' ? 'vnpay' : 'payos';
}

export function driverTopUpAdaptersFrom(config: ConfigService<AppEnv, true>): DriverTopUpAdapters {
  const adapters: DriverTopUpAdapters = {
    payos: new PayosAdapter({
      clientId: config.get('PAYOS_CLIENT_ID', { infer: true }),
      apiKey: config.get('PAYOS_API_KEY', { infer: true }),
      checksumKey: config.get('PAYOS_CHECKSUM_KEY', { infer: true }),
      endpoint: config.get('PAYOS_ENDPOINT', { infer: true }),
    }),
    vnpay: new VnpayAdapter({
      tmnCode: config.get('VNPAY_TMN_CODE', { infer: true }),
      hashSecret: config.get('VNPAY_HASH_SECRET', { infer: true }),
      url: config.get('VNPAY_URL', { infer: true }),
      apiUrl: config.get('VNPAY_API_URL', { infer: true }),
    }),
  };
  return adapters;
}

@Module({
  imports: [PrismaModule, PlatformSettingsModule, EarningsModule, IdentityModule],
  controllers: [DriverCreditController, OpsDriverCreditController, DriverCreditReturnController],
  providers: [
    DriverCreditService,
    DriverCreditStatusBus,
    {
      provide: DRIVER_TOP_UP_PROVIDER,
      inject: [ConfigService],
      useFactory: driverTopUpProviderFrom,
    },
    {
      provide: DRIVER_TOP_UP_ADAPTERS,
      inject: [ConfigService],
      useFactory: driverTopUpAdaptersFrom,
    },
    {
      provide: DRIVER_CREDIT_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (prisma: PrismaService, config: ConfigService<AppEnv, true>): DriverCreditRepository =>
        resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          DriverCreditRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryDriverCreditRepository(),
          createPrisma: (client) => new PrismaDriverCreditRepository(client),
        }),
    },
  ],
  exports: [DriverCreditService, DriverCreditStatusBus],
})
export class DriverCreditModule {}
