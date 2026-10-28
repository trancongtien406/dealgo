import { Controller, Get, Header, Param, StreamableFile, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { FOOD_CATEGORY_PUBLIC_MAX_AGE_S } from './food-category.js';
import { FoodCategoryService } from './food-category.service.js';

@ApiTags('food')
@Controller('v1/public/food-categories')
@UseGuards(ThrottlerGuard)
export class PublicFoodCategoryController {
  constructor(private readonly categories: FoodCategoryService) {}

  @Get()
  @Header('Cache-Control', `public, max-age=${FOOD_CATEGORY_PUBLIC_MAX_AGE_S}`)
  @ApiOperation({
    summary: 'Active store categories in display order; { items[{code,nameVi,nameEn,icon,tone,imageUrl}] }',
  })
  async list() {
    return { items: await this.categories.listPublic() };
  }

  @Get('images/:code/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: 'Current tile image of a store category' })
  async image(@Param('code') code: string, @Param('file') file: string): Promise<StreamableFile> {
    const found = await this.categories.readImage(code, file);
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}
