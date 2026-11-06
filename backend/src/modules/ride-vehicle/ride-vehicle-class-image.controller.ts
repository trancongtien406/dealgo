import { Controller, Get, Header, Param, Query, StreamableFile, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { PUBLIC_IMAGE_CACHE_CONTROL } from '../../platform/http/public-image-cache.js';
import { resolveImageVariantWidth } from '../../platform/storage/image-variants.js';
import { RideVehicleClassService } from './ride-vehicle-class.service.js';

@ApiTags('rides')
@Controller('v1/public/ride-vehicle-classes')
@UseGuards(ThrottlerGuard)
export class PublicRideVehicleClassImageController {
  constructor(private readonly classes: RideVehicleClassService) {}

  @Get(':code/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', PUBLIC_IMAGE_CACHE_CONTROL)
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Current image for a ride vehicle class' })
  async read(
    @Param('code') code: string,
    @Param('file') file: string,
    @Query('w') w?: string,
  ): Promise<StreamableFile> {
    const found = await this.classes.readImage(code, file, resolveImageVariantWidth(w));
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}