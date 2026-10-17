import { Module } from '@nestjs/common';
import { FoodModule } from '../../food-order/food.module.js';
import { IdentityModule } from '../../identity/identity.module.js';
import { RideModule } from '../../ride/ride.module.js';
import { SnapshotFanoutService } from './snapshot-fanout.service.js';
import { SnapshotGateway } from './snapshot.gateway.js';
import { SocketAccessService } from './socket-access.service.js';

@Module({
  imports: [IdentityModule, RideModule, FoodModule],
  providers: [SnapshotFanoutService, SocketAccessService, SnapshotGateway],
  exports: [SnapshotFanoutService, SocketAccessService],
})
export class RealtimeModule {}
