import { Controller, Get, Param, ParseUUIDPipe, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import { DriverCardService } from './driver-card.service.js';

@ApiTags('rides', 'food')
@ApiBearerAuth()
@Controller('v1')
@UseGuards(CustomerSessionGuard)
export class DriverCardController {
  constructor(private readonly cards: DriverCardService) {}

  @Get('rides/:id/driver')
  @ApiOperation({ summary: "Assigned driver's name, declared vehicle and rating (ride customer only)" })
  rideDriver(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.cards.forRide(actor.userId, id);
  }

  @Get('rides/:id/offers/:offerId/driver')
  @ApiOperation({ summary: 'Driver behind an offer on the customer ride (name, vehicle, rating)' })
  offerDriver(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('offerId', ParseUUIDPipe) offerId: string,
  ) {
    return this.cards.forRideOffer(actor, id, offerId);
  }

  @Get('food/orders/:id/courier')
  @ApiOperation({ summary: "Courier's name, declared vehicle and rating (order customer only)" })
  foodCourier(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.cards.forFoodOrder(actor.userId, id);
  }
}
