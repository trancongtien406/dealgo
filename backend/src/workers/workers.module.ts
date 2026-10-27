import { RealtimeModule } from '../modules/communication/realtime/realtime.module.js';
import { WorkerSocketEmitter } from './worker-socket-emitter.service.js';
import { Module } from '@nestjs/common';
import { AccountDeletionModule } from '../modules/account-deletion/index.js';
import { OutboxModule } from '../modules/communication/outbox/index.js';
import { RideModule } from '../modules/ride/index.js';
import { FoodModule } from '../modules/food-order/food.module.js';
import { PrismaModule } from '../platform/database/prisma.module.js';
import { PlatformSettingsModule } from '../platform/settings/platform-settings.module.js';
import { StorageModule } from '../platform/storage/storage.module.js';
import { OrphanUploadCleanupService } from './orphan-upload-cleanup.service.js';
import { RideExpiryService } from './ride-expiry.service.js';
import { PrismaUploadReferences, UPLOAD_REFERENCE_SOURCE } from './upload-references.js';
import { WorkersBootstrap } from './workers.bootstrap.js';
import { ChatRetentionService } from './chat-retention.service.js';
import { WorkerHeartbeatService } from './worker-heartbeat.service.js';
import { PrismaWorkerHeartbeatStore, WORKER_HEARTBEAT_STORE } from '../platform/health/worker-heartbeat.js';
import { OpsAlertService } from '../platform/observability/ops-alert.js';

@Module({
  imports: [AccountDeletionModule, RealtimeModule, RideModule, FoodModule, OutboxModule, PrismaModule, PlatformSettingsModule, StorageModule],
  providers: [
    RideExpiryService,
    OrphanUploadCleanupService,
    { provide: UPLOAD_REFERENCE_SOURCE, useClass: PrismaUploadReferences },
    WorkersBootstrap,
    WorkerSocketEmitter,
    OpsAlertService,
    { provide: WORKER_HEARTBEAT_STORE, useClass: PrismaWorkerHeartbeatStore },
    WorkerHeartbeatService,
    ChatRetentionService,
  ],
  exports: [RideExpiryService, OrphanUploadCleanupService, ChatRetentionService],

})
export class WorkersModule {}
