import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { SupportModule } from '../support/index.js';
import { MomoPaymentPort } from '../../integrations/payment-gateways/index.js';
import { CashOnlyPaymentPort } from '../../integrations/payment-gateways/cash-only-payment.port.js';
import { isCashOnlyPaymentProvider } from '../../platform/config/env.js';

import { UnavailablePaymentPort, type PaymentPort } from './payment-port.js';
import { PAYMENT_PORT, PAYMENT_REPOSITORY } from './payment.constants.js';
import { PaymentWebhookController } from './payment-webhook.controller.js';
import { OpsRefundsController } from './ops-refunds.controller.js';
import { OpsTransactionsController } from './ops-transactions.controller.js';
import { OpsRefundsService } from './ops-refunds.service.js';
import { OpsTransactionsService } from './ops-transactions.service.js';
import { MemoryPaymentRepository, type PaymentRepository } from './payment.repository.js';
import { PrismaPaymentRepository } from './payment-prisma.repository.js';
import { SandboxPaymentPort } from '../../integrations/payment-gateways/sandbox-payment.port.js';
import { VnpayPaymentPort } from '../../integrations/payment-gateways/vnpay-payment.port.js';

function hasVnpayKeys(config: ConfigService<AppEnv, true>): boolean {
  return Boolean(
    config.get('VNPAY_TMN_CODE', { infer: true }) &&
      config.get('VNPAY_HASH_SECRET', { infer: true }) &&
      config.get('VNPAY_URL', { infer: true }),
  );
}

function hasMomoKeys(config: ConfigService<AppEnv, true>): boolean {
  return Boolean(
    config.get('MOMO_PARTNER_CODE', { infer: true }) &&
      config.get('MOMO_ACCESS_KEY', { infer: true }) &&
      config.get('MOMO_SECRET_KEY', { infer: true }) &&
      config.get('MOMO_ENDPOINT', { infer: true }),
  );
}

@Module({
  imports: [PrismaModule, IdentityModule, SupportModule],
  controllers: [PaymentWebhookController, OpsRefundsController, OpsTransactionsController],
  providers: [
    OpsRefundsService,
    OpsTransactionsService,
    {
      provide: PAYMENT_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): PaymentRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          PaymentRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPaymentRepository(),
          createPrisma: (client) => new PrismaPaymentRepository(client),
        });
      },
    },
    {
      provide: PAYMENT_PORT,
      inject: [ConfigService, PAYMENT_REPOSITORY],
      useFactory: (
        config: ConfigService<AppEnv, true>,
        repository: PaymentRepository,
      ): PaymentPort => {
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        const provider = config.get('PAYMENT_PROVIDER', { infer: true });
        if (nodeEnv === 'production') {
          if (!provider || provider === 'sandbox') {
            throw new Error(
              'PAYMENT_PROVIDER must be configured and cannot be sandbox when NODE_ENV=production',
            );
          }
        }
        if (isCashOnlyPaymentProvider(provider)) {
          return new CashOnlyPaymentPort(repository);
        }
        if (provider === 'sandbox' || provider === undefined) {
          return new SandboxPaymentPort(repository);
        }

        if (provider === 'vnpay' && hasVnpayKeys(config)) {
          return new VnpayPaymentPort(
            {
              tmnCode: config.get('VNPAY_TMN_CODE', { infer: true })!,
              hashSecret: config.get('VNPAY_HASH_SECRET', { infer: true })!,
              url: config.get('VNPAY_URL', { infer: true })!,
            },
            repository,
          );
        }
        if (provider === 'momo' && hasMomoKeys(config)) {
          return new MomoPaymentPort(
            {
              partnerCode: config.get('MOMO_PARTNER_CODE', { infer: true })!,
              accessKey: config.get('MOMO_ACCESS_KEY', { infer: true })!,
              secretKey: config.get('MOMO_SECRET_KEY', { infer: true })!,
              endpoint: config.get('MOMO_ENDPOINT', { infer: true })!,
            },
            repository,
          );
        }
        if (
          (provider === 'vnpay' && !hasVnpayKeys(config)) ||
          (provider === 'momo' && !hasMomoKeys(config))
        ) {
          return new UnavailablePaymentPort();
        }
        return new UnavailablePaymentPort();
      },
    },
  ],
  exports: [PAYMENT_PORT, PAYMENT_REPOSITORY, OpsRefundsService, OpsTransactionsService],
})
export class PaymentModule {}
