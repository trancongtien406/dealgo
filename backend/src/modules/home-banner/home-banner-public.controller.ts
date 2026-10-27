import {
  Body,
  Controller,
  Get,
  Header,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { HomeBannerEventsDto, ListPublicHomeBannersQuery } from './home-banner.dto.js';
import { HOME_BANNER_PUBLIC_MAX_AGE_S } from './home-banner.js';
import { HomeBannerService } from './home-banner.service.js';

@ApiTags('home-banners')
@Controller('v1/public/home-banners')
@UseGuards(ThrottlerGuard)
export class PublicHomeBannerController {
  constructor(private readonly banners: HomeBannerService) {}

  @Get()
  @Header('Cache-Control', `public, max-age=${HOME_BANNER_PUBLIC_MAX_AGE_S}`)
  @ApiOperation({
    summary:
      'Live home banners for one role (CUSTOMER/DRIVER/MERCHANT), optional service and region (code or lat/lng); { items[{id,imageUrl,cta{kind:app|web,target},service}] }',
  })
  async list(@Query() query: ListPublicHomeBannersQuery) {
    return { items: await this.banners.listPublic(query) };
  }

  @Post('events')
  @HttpCode(HttpStatus.OK)
  @Throttle({ default: { limit: 60, ttl: 60_000 } })
  @ApiOperation({ summary: 'Record banner impressions / clicks (batch ≤ 50); unknown or non-live ids are ignored' })
  events(@Body() body: HomeBannerEventsDto) {
    return this.banners.recordEvents(body.events);
  }

  @Get('images/:id/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Current image of a home banner' })
  async image(@Param('id') id: string, @Param('file') file: string): Promise<StreamableFile> {
    const found = await this.banners.readImage(id, file);
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}
