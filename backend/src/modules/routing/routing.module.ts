import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { OpsRoutingController } from './ops-routing.controller.js';
import { RoutingService } from './routing.service.js';

@Module({
  imports: [IdentityModule],
  controllers: [OpsRoutingController],
  providers: [RoutingService],
  exports: [RoutingService],
})
export class RoutingModule {}
