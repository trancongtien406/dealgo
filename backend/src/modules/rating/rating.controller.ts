import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  RatingSubjectParamsDto,
  StoreIdParamsDto,
  StoreRatingQueryDto,
  SubmitRatingDto,
} from './rating.dto.js';
import { RatingService } from './rating.service.js';

@ApiTags('ratings')
@ApiBearerAuth()
@Controller('v1/ratings')
@UseGuards(CustomerSessionGuard)
export class RatingController {
  constructor(private readonly ratings: RatingService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Rate a completed ride or delivered food order (customer, once)' })
  submit(@CurrentActor() actor: RequestActor, @Body() body: SubmitRatingDto) {
    return this.ratings.submit(actor.userId, body);
  }

  @Get('stores')
  @ApiOperation({
    summary: 'Store rating summaries for browse cards (average hidden below RATING_STORE_MIN_COUNT)',
  })
  stores(@Query() query: StoreRatingQueryDto) {
    return this.ratings.storeSummaries(query.ids);
  }

  @Get('stores/:storeId/reviews')
  @ApiOperation({
    summary: 'Store rating summary and newest reviews (no rater identity; hidden below RATING_STORE_MIN_COUNT)',
  })
  storeReviews(@Param() params: StoreIdParamsDto) {
    return this.ratings.storeReviews(params.storeId);
  }

  @Get(':subjectType/:subjectId')
  @ApiOperation({ summary: 'The rating of one ride/order, and whether it can still be rated' })
  get(@CurrentActor() actor: RequestActor, @Param() params: RatingSubjectParamsDto) {
    return this.ratings.get(actor.userId, params.subjectType, params.subjectId);
  }
}
