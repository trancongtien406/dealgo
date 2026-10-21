import { Module } from '@nestjs/common';
import { AccountDeletionModule } from '../modules/account-deletion/index.js';
import { OutboxModule } from '../modules/communication/outbox/index.js';
import { RideModule } from '../modules/ride/index.js';
import { PrismaModule } from '../platform/database/prisma.module.js';
import { PlatformSettingsModule } from '../platform/settings/platform-settings.module.js';
import { StorageModule } from '../platform/storage/storage.module.js';
import { OrphanUploadCleanupService } from './orphan-upload-cleanup.service.js';
import { RideExpiryService } from './ride-expiry.service.js';
import { PrismaUploadReferences, UPLOAD_REFERENCE_SOURCE } from './upload-references.js';
import { WorkersBootstrap } from './workers.bootstrap.js';

@Module({
  imports: [AccountDeletionModule, RideModule, OutboxModule, PrismaModule, PlatformSettingsModule, StorageModule],
  providers: [
    RideExpiryService,
    OrphanUploadCleanupService,
    { provide: UPLOAD_REFERENCE_SOURCE, useClass: PrismaUploadReferences },
    WorkersBootstrap,
  ],
  exports: [RideExpiryService, OrphanUploadCleanupService],
})
export class WorkersModule {}
