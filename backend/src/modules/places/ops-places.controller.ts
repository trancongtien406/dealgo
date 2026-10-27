import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { SearchPlacesQueryDto } from './places.dto.js';
import { PlacesService } from './places.service.js';

/**
 * Admin › Khu vực: place lookup for the zone form (pick a city/district, the map
 * recenters on it). Same provider chain as the app search; ops session only.
 */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/places')
@UseGuards(OpsPermissionGuard, ThrottlerGuard)
export class OpsPlacesController {
  constructor(private readonly places: PlacesService) {}

  @RequireOpsPermission('zones.write')
  @Get('search')
  @ApiOperation({
    summary:
      'Search places for the zone form (zones.write); { items[{lat,lng,name,address,provider}], available }',
  })
  search(@Query() query: SearchPlacesQueryDto) {
    return this.places.search(
      query.q,
      query.limit,
      query.lat != null && query.lng != null ? { lat: query.lat, lng: query.lng } : undefined,
    );
  }
}
