import { Module } from '@nestjs/common';
import { DeliveryService } from './delivery.service.js';

@Module({
  providers: [DeliveryService],
  exports: [DeliveryService],
})
export class DeliveryModule {}
