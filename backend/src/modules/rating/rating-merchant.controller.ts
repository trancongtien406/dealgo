import { Body, Controller, Get, Param, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { MerchantReviewsQueryDto, RatingIdParamsDto, ReplyReviewDto } from './rating.dto.js';
import { RatingService } from './rating.service.js';

@ApiTags('ratings')
@ApiBearerAuth()
@Controller('v1/food/merchant/reviews')
@UseGuards(CustomerSessionGuard)
export class RatingMerchantController {
  constructor(private readonly ratings: RatingService) {}

  @Get()
  @ApiOperation({
    summary:
      'Reviews of the signed-in merchant store with filters (stars, reply state, comment, visibility, tag, search, date range, sort)',
  })
  list(@CurrentActor() actor: RequestActor, @Query() query: MerchantReviewsQueryDto) {
    return this.ratings.merchantReviews(actor, query);
  }

  @Put(':id/reply')
  @ApiOperation({ summary: 'Set or clear the store public reply to one review (max 500 chars)' })
  reply(
    @CurrentActor() actor: RequestActor,
    @Param() params: RatingIdParamsDto,
    @Body() body: ReplyReviewDto,
  ) {
    return this.ratings.replyAsMerchant(actor, params.id, body.text);
  }
}
