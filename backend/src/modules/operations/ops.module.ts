import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { PrismaModule } from '../../platform/database/index.js';
import { OpsAuditLogsController } from './ops-audit-logs.controller.js';
import { OpsAuthMethodsController } from './ops-auth-methods.controller.js';
import { OpsExceptionsController } from './ops-exceptions.controller.js';
import { OpsExceptionsService } from './ops-exceptions.service.js';
import { OpsOverviewController } from './ops-overview.controller.js';
import { OpsOverviewService } from './ops-overview.service.js';
import { OpsReportsController } from './ops-reports.controller.js';
import { OpsReportsService } from './ops-reports.service.js';
import { OpsEventsController } from './ops-events.controller.js';
import { AuditModule } from '../../platform/audit/index.js';
import { OpsEventsModule } from '../../platform/ops-events/index.js';

@Module({
  imports: [PrismaModule, IdentityModule, AuditModule, OpsEventsModule],
  controllers: [
    OpsAuthMethodsController,
    OpsExceptionsController,
    OpsOverviewController,
    OpsAuditLogsController,
    OpsReportsController,
    OpsEventsController,
  ],
  providers: [
    OpsExceptionsService,
    OpsOverviewService,
    OpsReportsService,
  ],
  exports: [
    OpsExceptionsService,
    OpsOverviewService,
    AuditModule,
  ],
})
export class OpsModule {}
