import { Body, Controller, Get, Param, Patch, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { OpsReviewsQueryDto, RatingIdParamsDto, SetReviewHiddenDto } from './rating.dto.js';
import { RatingService } from './rating.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/reviews')
@UseGuards(OpsPermissionGuard)
export class RatingOpsController {
  constructor(private readonly ratings: RatingService) {}

  @Get()
  @ApiOperation({ summary: 'Ops list store reviews (filter by store, visibility, max stars, text)' })
  list(@Query() query: OpsReviewsQueryDto) {
    return this.ratings.opsReviews(query);
  }

  @RequireOpsPermission('catalog.write')
  @Patch(':id/visibility')
  @ApiOperation({ summary: 'Ops hide or show a store review with a reason (audited; hidden reviews leave the average)' })
  setVisibility(
    @CurrentActor() actor: RequestActor,
    @Param() params: RatingIdParamsDto,
    @Body() body: SetReviewHiddenDto,
  ) {
    return this.ratings.setHidden(actor.userId, params.id, body.hidden, body.reason);
  }
}
