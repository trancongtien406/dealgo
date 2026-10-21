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
import { MenuItemImageService } from './menu-item-image.service.js';

@ApiTags('food')
@Controller('v1/public/menu-items')
@UseGuards(ThrottlerGuard)
export class PublicMenuItemImageController {
  constructor(private readonly images: MenuItemImageService) {}

  @Get(':itemId/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: "A menu item's current photo (404 for replaced or unknown files)" })
  async read(
    @Param('itemId') itemId: string,
    @Param('file') file: string,
  ): Promise<StreamableFile> {
    const found = await this.images.read(itemId, file);
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}
