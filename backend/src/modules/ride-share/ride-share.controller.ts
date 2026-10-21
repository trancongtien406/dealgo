import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import { RideShareService } from './ride-share.service.js';
import {
  RIDE_SHARE_VIEW_LIMIT_PER_MIN,
  ShareViewThrottlerGuard,
} from './share-view-throttler.guard.js';

@ApiTags('rides')
@ApiBearerAuth()
@Controller('v1/rides')
@UseGuards(CustomerSessionGuard)
export class RideShareController {
  constructor(private readonly shares: RideShareService) {}

  @Post(':id/share-link')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a read-only trip link for family (ride customer, ongoing trip only)' })
  create(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.shares.create(actor.userId, id);
  }
}

@ApiTags('rides')
@Controller('v1/public/ride-shares')
@UseGuards(ShareViewThrottlerGuard)
export class PublicRideShareController {
  constructor(private readonly shares: RideShareService) {}

  @Get(':token')
  @Throttle({ default: { limit: RIDE_SHARE_VIEW_LIMIT_PER_MIN, ttl: 60_000 } })
  @ApiOperation({ summary: 'Trip status for a share link: labels, masked driver, vehicle; 410 once expired' })
  view(@Param('token') token: string) {
    return this.shares.view(token);
  }
}
