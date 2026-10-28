import {
  Controller,
  Get,
  Header,
  Param,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { StoreLogoService } from './store-logo.service.js';

@ApiTags('food')
@Controller('v1/public/store-logos')
@UseGuards(ThrottlerGuard)
export class PublicStoreLogoController {
  constructor(private readonly logos: StoreLogoService) {}

  @Get(':storeId/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary: "A store's current logo (404 for replaced or unknown files)",
  })
  async read(
    @Param('storeId') storeId: string,
    @Param('file') file: string,
  ): Promise<StreamableFile> {
    const found = await this.logos.read(storeId, file);
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
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({
    summary:
      "A store's current cover photo (404 for replaced or unknown files)",
  })
  async read(
    @Param('storeId') storeId: string,
    @Param('file') file: string,
  ): Promise<StreamableFile> {
    const found = await this.logos.read(storeId, file, 'cover');
    return new StreamableFile(found.body, {
      type: found.contentType,
      length: found.body.byteLength,
    });
  }
}
