import { Controller, Get, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { OpsOverviewService } from './ops-overview.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops')
@UseGuards(OpsSessionGuard)
export class OpsOverviewController {
  constructor(private readonly overview: OpsOverviewService) {}

  @Get('overview')
  @ApiOperation({
    summary:
      'Ops dashboard KPIs + optional panels (hourlyTrend, recentActivity, ridesByArea, foodByCategory). Today = Asia/Ho_Chi_Minh. revenueVnd/commissionVnd null. Enrichment fail-soft → empty arrays.',
  })
  getOverview() {
    return this.overview.overview();
  }

  @Get('monitor/snapshot')
  @ApiOperation({
    summary:
      'Live board: core KPIs + mapMarkers, queue, areaDemand, recentActivity, systemAlerts, optional pilotZoneLabel. Enrichment fail-soft.',
  })
  getMonitorSnapshot() {
    return this.overview.monitorSnapshot();
  }
}
