import { Module } from '@nestjs/common';
import { IdentityModule } from '../identity/index.js';
import { PrismaModule } from '../../platform/database/index.js';
import { OpsAuditLogsController } from './ops-audit-logs.controller.js';
import { OpsAuthMethodsController } from './ops-auth-methods.controller.js';
import { OpsExceptionsController } from './ops-exceptions.controller.js';
import { OpsExceptionsService } from './ops-exceptions.service.js';
import { OpsOverviewController } from './ops-overview.controller.js';
import { OpsOverviewService } from './ops-overview.service.js';
import { AuditModule } from '../../platform/audit/index.js';

@Module({
  imports: [PrismaModule, IdentityModule, AuditModule],
  controllers: [
    OpsAuthMethodsController,
    OpsExceptionsController,
    OpsOverviewController,
    OpsAuditLogsController,
  ],
  providers: [
    OpsExceptionsService,
    OpsOverviewService,
  ],
  exports: [
    OpsExceptionsService,
    OpsOverviewService,
    AuditModule,
  ],
})
export class OpsModule {}
