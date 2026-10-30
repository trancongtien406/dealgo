import { Controller, Get, Inject, Req, Res, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiProduces, ApiTags } from '@nestjs/swagger';
import type { Request, Response } from 'express';
import { OpsSessionGuard, currentActorFromRequest } from './ops-events.auth.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';
import { isOpsStaffRole, roleHasPermission } from '../identity/ops-rbac/ops-permissions.js';
import { OpsEventBus, type OpsEvent } from '../../platform/ops-events/ops-event-bus.js';

export const OPS_EVENTS_HEARTBEAT_MS = 25_000;
/** Ride/food snapshots can burst; the board only needs one re-GET per window. */
export const OPS_MONITOR_COALESCE_MS = 2_000;

/** Same rule as OpsPermissionGuard for `errors.read` (the system-errors REST). */
export async function canReadSystemErrors(repo: IdentityRepository, userId: string): Promise<boolean> {
  const cred = await repo.findOpsCredential(userId);
  if (!cred) return false;
  if (cred.superAdmin) return true;
  return roleHasPermission(isOpsStaffRole(cred.staffRole) ? cred.staffRole : 'SUPPORT', 'errors.read');
}

export function formatSse(event: OpsEvent): string {
  return `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops')
@UseGuards(OpsSessionGuard)
export class OpsEventsController {
  constructor(
    private readonly bus: OpsEventBus,
    @Inject(IDENTITY_REPOSITORY) private readonly repository: IdentityRepository,
  ) {}

  @Get('events')
  @ApiProduces('text/event-stream')
  @ApiOperation({
    summary:
      'Admin live hints (SSE). Events: `ready`, `monitor` (re-GET /v1/ops/monitor/snapshot; coalesced 2 s), `systemErrors` (re-GET system-errors list/count; only for actors with errors.read). Comment heartbeat every 25 s. Hints only, REST stays the source of truth.',
  })
  async stream(@Req() req: Request, @Res() res: Response): Promise<void> {
    const actor = currentActorFromRequest(req);
    const errorsAllowed = await canReadSystemErrors(this.repository, actor.userId).catch(() => false);

    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    res.flushHeaders?.();
    res.write(`retry: 5000\nevent: ready\ndata: ${JSON.stringify({ systemErrors: errorsAllowed })}\n\n`);

    let monitorTimer: ReturnType<typeof setTimeout> | null = null;
    let pendingMonitor: OpsEvent | null = null;
    let closed = false;

    const send = (event: OpsEvent) => {
      if (!closed) res.write(formatSse(event));
    };
    const unsubscribe = this.bus.subscribe((event) => {
      if (event.type === 'systemErrors') {
        if (errorsAllowed) send(event);
        return;
      }
      pendingMonitor = event;
      if (monitorTimer) return;
      monitorTimer = setTimeout(() => {
        monitorTimer = null;
        if (pendingMonitor) send(pendingMonitor);
        pendingMonitor = null;
      }, OPS_MONITOR_COALESCE_MS);
    });
    const heartbeat = setInterval(() => {
      if (!closed) res.write(`: ping ${Date.now()}\n\n`);
    }, OPS_EVENTS_HEARTBEAT_MS);

    const cleanup = () => {
      if (closed) return;
      closed = true;
      clearInterval(heartbeat);
      if (monitorTimer) clearTimeout(monitorTimer);
      monitorTimer = null;
      unsubscribe();
    };
    req.on('close', cleanup);
    res.on('close', cleanup);
    res.on('error', cleanup);
  }
}
