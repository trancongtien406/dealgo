import { Module } from '@nestjs/common';
import { FoodModule } from '../../food-order/food.module.js';
import { IdentityModule } from '../../identity/identity.module.js';
import { RideModule } from '../../ride/ride.module.js';
import { RoutingModule } from '../../routing/routing.module.js';
import { PhaseRouteService } from './phase-route.service.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { SnapshotGateway } from './snapshot.gateway.js';
import { DriverLocationFanoutService } from './driver-location-fanout.service.js';
import { SocketAccessService } from './socket-access.service.js';
import { RideOfferFanoutService } from './ride-offer-fanout.service.js';
import { PushModule } from '../../../integrations/push/index.js';
import { AccountSettingsModule } from '../../account-settings/index.js';
import { PaymentModule } from '../../payment/index.js';
import { PaymentStatusBridgeService } from './payment-status-bridge.service.js';
import { PlatformSettingsModule } from '../../../platform/settings/platform-settings.module.js';

@Module({
  // PushModule was missing, so PUSH_SENDER (optional) was always undefined here.
  imports: [IdentityModule, RideModule, FoodModule, RoutingModule, PushModule, AccountSettingsModule, PlatformSettingsModule, PaymentModule],
  providers: [SnapshotFanoutService, SocketAccessService, SnapshotGateway, DriverLocationFanoutService, RideOfferFanoutService, PhaseRouteService, PaymentStatusBridgeService],
  exports: [SnapshotFanoutService, SocketAccessService],
})
export class RealtimeModule {}
