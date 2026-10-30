import { Global, Module } from '@nestjs/common';
import { OpsEventBus } from './ops-event-bus.js';

/** Global so realtime, system-errors and ops share one bus without import cycles. */
@Global()
@Module({ providers: [OpsEventBus], exports: [OpsEventBus] })
export class OpsEventsModule {}
