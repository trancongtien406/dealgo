import {
  Controller,
  Get,
  Header,
  Param,
  Query,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { PUBLIC_IMAGE_CACHE_CONTROL } from '../../platform/http/public-image-cache.js';
import { resolveImageVariantWidth } from '../../platform/storage/image-variants.js';
import { StoreLogoService } from './store-logo.service.js';

/**
 * Photos are requested in bursts (one per store card) and cached for a day, so
 * the limiter must absorb a whole screen before the client cache warms up.
 */
const IMAGE_LIMIT_PER_MINUTE = 600;

@ApiTags('food')
@Controller('v1/public/store-logos')
@UseGuards(ThrottlerGuard)
export class PublicStoreLogoController {
  constructor(private readonly logos: StoreLogoService) {}

  @Get(':storeId/:file')
  @SkipResponseEnvelope()
  @Throttle({ default: { limit: IMAGE_LIMIT_PER_MINUTE, ttl: 60_000 } })
  @Header('Cache-Control', PUBLIC_IMAGE_CACHE_CONTROL)
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: "A store's current logo (404 for replaced or unknown files)",
  })
  async read(
    @Param('storeId') storeId: string,
    @Param('file') file: string,
    @Query('w') w?: string,
  ): Promise<StreamableFile> {
    const found = await this.logos.read(storeId, file, 'logo', resolveImageVariantWidth(w));
    return new StreamableFile(found.body, {
      type: found.contentType,
      length: found.body.byteLength,
    });
  }
}

@ApiTags('food')
@Controller('v1/public/store-covers')
@UseGuards(ThrottlerGuard)
export class PublicStoreCoverController {
  constructor(private readonly logos: StoreLogoService) {}

  @Get(':storeId/:file')
  @SkipResponseEnvelope()
  @Throttle({ default: { limit: IMAGE_LIMIT_PER_MINUTE, ttl: 60_000 } })
  @Header('Cache-Control', PUBLIC_IMAGE_CACHE_CONTROL)
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary:
      "A store's current cover photo (404 for replaced or unknown files)",
  })
  async read(
    @Param('storeId') storeId: string,
    @Param('file') file: string,
    @Query('w') w?: string,
  ): Promise<StreamableFile> {
    const found = await this.logos.read(storeId, file, 'cover', resolveImageVariantWidth(w));
    return new StreamableFile(found.body, {
      type: found.contentType,
      length: found.body.byteLength,
    });
  }
}
