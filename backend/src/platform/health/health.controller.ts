import { Controller, Get, Res } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { SkipResponseEnvelope } from '../http/skip-response-envelope.js';
import {
  HealthService,
  type HealthReport,
  type LiveReport,
  type ReadyReport,
  type WorkerReport,
} from './health.service.js';

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly healthService: HealthService) {}

  @Get()
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Combined dependency health (not wrapped in success envelope)' })
  getHealth(): Promise<HealthReport> {
    return this.healthService.check();
  }

  @Get('live')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Liveness: process is up (no dependency checks)' })
  getLive(): LiveReport {
    return this.healthService.live();
  }

  @Get('ready')
  @SkipResponseEnvelope()
  @ApiOperation({
    summary:
      'Readiness: database required (503 when down); Redis optional (degraded when down)',
  })
  async getReady(@Res({ passthrough: true }) response: Response): Promise<ReadyReport> {
    const report = await this.healthService.checkReady();
    if (report.status === 'not_ready') {
      response.status(503);
    }
    return report;
  }

  @Get('worker')
  @SkipResponseEnvelope()
  @ApiOperation({
    summary: 'Background worker heartbeat + outbox lag (503 when stale/missing or lag above OUTBOX_LAG_ALERT_MS)',
  })
  async getWorker(@Res({ passthrough: true }) response: Response): Promise<WorkerReport | { status: 'unknown' }> {
    const report = await this.healthService.worker();
    if (!report || report.status !== 'up' || (report.outboxLagMs ?? 0) > report.outboxLagAlertMs) {
      response.status(503);
    }
    return report ?? { status: 'unknown' };
  }
}
