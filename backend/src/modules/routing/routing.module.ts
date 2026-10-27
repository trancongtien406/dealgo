import { Module } from '@nestjs/common';
import { MapsModule } from '../../integrations/maps/maps.module.js';
import { IdentityModule } from '../identity/index.js';
import { OpsRoutingController } from './ops-routing.controller.js';
import { PhaseRouteCache } from './phase-route-cache.js';
import { RoutingService } from './routing.service.js';

@Module({
  imports: [IdentityModule, MapsModule],
  controllers: [OpsRoutingController],
  providers: [RoutingService, PhaseRouteCache],
  exports: [RoutingService, PhaseRouteCache],
})
export class RoutingModule {}
