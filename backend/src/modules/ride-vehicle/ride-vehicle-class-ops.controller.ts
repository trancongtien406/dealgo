import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { PatchRideVehicleClassDto, UploadRideVehicleClassImageDto } from './ride-vehicle-class.dto.js';
import { RideVehicleClassService } from './ride-vehicle-class.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/ride-vehicle-classes')
@UseGuards(OpsPermissionGuard)
export class RideVehicleClassOpsController {
  constructor(private readonly classes: RideVehicleClassService) {}

  @Get()
  @ApiOperation({
    summary:
      'List ride vehicle classes and their reference-fare parameters. Rows are bid bounds, not an approved tariff.',
  })
  list() {
    return this.classes.listAll();
  }

  @RequireOpsPermission('settings.write')
  @Patch(':code')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update one ride vehicle class. Code is immutable.' })
  patch(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: PatchRideVehicleClassDto,
  ) {
    return this.classes.update(code, body, actor.userId);
  }

  @RequireOpsPermission('settings.write')
  @Post(':code/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Upload a JPEG, PNG or WebP image for a vehicle class' })
  uploadImage(
    @CurrentActor() actor: RequestActor,
    @Param('code') code: string,
    @Body() body: UploadRideVehicleClassImageDto,
  ) {
    return this.classes.uploadImage(code, body, actor.userId);
  }

  @RequireOpsPermission('settings.write')
  @Delete(':code/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Remove the image for a vehicle class' })
  clearImage(@CurrentActor() actor: RequestActor, @Param('code') code: string) {
    return this.classes.clearImage(code, actor.userId);
  }
}
