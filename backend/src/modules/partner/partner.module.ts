import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { resolvePersistenceRepository, PrismaModule, PrismaService } from '../../platform/database/index.js';
import type { AppEnv } from '../../platform/config/index.js';
import { IdentityModule } from '../identity/index.js';
import { KYC_STORAGE, PARTNER_REPOSITORY } from './partner.constants.js';
import { MePartnerApplicationsController } from './me-partner-applications.controller.js';
import {
  MockKycStorage,
  UnavailableKycStorage,
  type KycStorage,
} from '../../integrations/object-storage/index.js';
import { OpsPartnerApplicationsController } from './ops-partner-applications.controller.js';
import { PartnerEligibilityService } from './partner-eligibility.service.js';
import { MemoryPartnerRepository, type PartnerRepository } from './partner.repository.js';
import { PartnerService } from './partner.service.js';
import { PrismaPartnerRepository } from './partner-prisma.repository.js';
import { S3KycStorage } from '../../integrations/object-storage/s3-kyc-storage.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [MePartnerApplicationsController, OpsPartnerApplicationsController],
  providers: [
    {
      provide: PARTNER_REPOSITORY,
      inject: [PrismaService, ConfigService],
      useFactory: (
        prisma: PrismaService,
        config: ConfigService<AppEnv, true>,
      ): PartnerRepository => {
        return resolvePersistenceRepository<
          NonNullable<ReturnType<PrismaService['db']>>,
          PartnerRepository
        >({
          nodeEnv: config.get('NODE_ENV', { infer: true }),
          databaseUrl: config.get('DATABASE_URL', { infer: true }),
          client: prisma.db(),
          createMemory: () => new MemoryPartnerRepository(),
          createPrisma: (client) => new PrismaPartnerRepository(client),
        });
      },
    },
    {
      provide: KYC_STORAGE,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): KycStorage => {
        const provider = config.get('KYC_STORAGE_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if (provider === 's3') {
          const s3 = S3KycStorage.tryFromEnv({
            S3_ENDPOINT: config.get('S3_ENDPOINT', { infer: true }),
            S3_REGION: config.get('S3_REGION', { infer: true }),
            S3_BUCKET: config.get('S3_BUCKET', { infer: true }),
            S3_ACCESS_KEY_ID: config.get('S3_ACCESS_KEY_ID', { infer: true }),
            S3_SECRET_ACCESS_KEY: config.get('S3_SECRET_ACCESS_KEY', { infer: true }),
          });
          if (!s3) {
            return new UnavailableKycStorage();
          }
          return s3;
        }
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockKycStorage();
        }
        return new UnavailableKycStorage();
      },
    },
    PartnerService,
    PartnerEligibilityService,
  ],
  exports: [PartnerEligibilityService, PARTNER_REPOSITORY, PartnerService],
})
export class PartnerModule {}
