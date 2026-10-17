import { Module } from '@nestjs/common';
import { PrismaModule } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { PlatformSettingsModule } from '../../platform/settings/index.js';
import { AuditModule } from '../../platform/audit/index.js';
import { ServiceZonesController } from './service-zones.controller.js';
import { ServiceZonesService } from './service-zones.service.js';
import { ServiceRegionsService } from './service-regions.service.js';

@Module({
  imports: [PrismaModule, IdentityModule, PlatformSettingsModule, AuditModule],
  controllers: [ServiceZonesController],
  providers: [ServiceZonesService, ServiceRegionsService],
  exports: [ServiceZonesService, ServiceRegionsService],
})
export class ServiceAreaModule {}
