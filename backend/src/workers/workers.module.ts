import { Module } from '@nestjs/common';
import { OutboxModule } from '../modules/communication/outbox/index.js';
import { RideModule } from '../modules/ride/index.js';
import { RideExpiryService } from './ride-expiry.service.js';
import { WorkersBootstrap } from './workers.bootstrap.js';

@Module({
  imports: [RideModule, OutboxModule],
  providers: [RideExpiryService, WorkersBootstrap],
  exports: [RideExpiryService],
})
export class WorkersModule {}
