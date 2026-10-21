import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { Type } from 'class-transformer';
import { IsNumber, Max, Min } from 'class-validator';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RoutingService } from './routing.service.js';

export class OpsRouteQueryDto {
  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  fromLat!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  fromLng!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-90)
  @Max(90)
  toLat!: number;

  @Type(() => Number)
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(-180)
  @Max(180)
  toLng!: number;
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/routing')
@UseGuards(ThrottlerGuard, OpsPermissionGuard)
export class OpsRoutingController {
  constructor(private readonly routing: RoutingService) {}

  @Get('route')
  @Throttle({ default: { limit: 120, ttl: 60_000 } })
  @ApiOperation({
    summary:
      'Admin map road geometry via the configured provider (ROUTING_PROVIDER). available=false → draw a straight line.',
  })
  route(@Query() query: OpsRouteQueryDto) {
    return this.routing.route(
      { lat: query.fromLat, lng: query.fromLng },
      { lat: query.toLat, lng: query.toLng },
    );
  }
}
