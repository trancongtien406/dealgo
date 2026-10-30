import { Controller, Get, Header, Param, ParseUUIDPipe, Query, StreamableFile, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsParcelQueryDto } from './parcel.dto.js';
import { parsePhotoKind } from './parcel.controller.js';
import { ParcelService } from './parcel.service.js';

/** DEC-PROD-071: ops view of parcels. Cancel/reassign reuse /v1/ops/rides/:id/* (rides.intervene). */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/parcels')
@UseGuards(OpsPermissionGuard)
export class ParcelOpsController {
  constructor(private readonly parcels: ParcelService) {}

  @RequireOpsPermission('rides.read')
  @Get()
  @ApiOperation({ summary: 'Ops paginated parcel list (outcome filter, phone/name/id search)' })
  list(@Query() query: OpsParcelQueryDto) {
    return this.parcels.listForOps(query);
  }

  @RequireOpsPermission('rides.read')
  @Get(':id')
  @ApiOperation({ summary: 'Ops parcel detail (ops ride view + package)' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.parcels.getForOps(id);
  }

  @RequireOpsPermission('rides.read')
  @Get(':id/photos/:kind')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'private, no-store')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Ops parcel proof photo' })
  async photo(@Param('id', ParseUUIDPipe) id: string, @Param('kind') kind: string): Promise<StreamableFile> {
    const found = await this.parcels.photo(null, id, parsePhotoKind(kind));
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}
