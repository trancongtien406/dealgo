import {
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { DriverLocationQueryDto } from '../dispatch/driver-location-query.dto.js';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import { CreateOfferDto, CreateRideDto, QuoteRideDto, RidePageQueryDto, SelectOfferDto, StartTripDto } from './ride.dto.js';
import { rideError } from './ride.error.js';
import { RideService } from './ride.service.js';

@ApiTags('rides')
@ApiBearerAuth()
@Controller('v1/rides')
@UseGuards(CustomerSessionGuard)
export class RideController {
  constructor(private readonly rides: RideService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Create a negotiating ride (Idempotency-Key required)' })
  create(
    @CurrentActor() actor: RequestActor,
    @Headers('idempotency-key') idempotencyKey: string | string[] | undefined,
    @Body() dto: CreateRideDto,
  ) {
    return this.rides.create(actor, readIdempotencyKey(idempotencyKey), dto);
  }

  @Post('quote')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Route distance, server reference fare and admin fare bounds before booking' })
  quote(@CurrentActor() actor: RequestActor, @Body() dto: QuoteRideDto) {
    return this.rides.quote(actor, dto);
  }

  @Get()
  @ApiOperation({ summary: 'Customer paginated ride history (actor-scoped)' })
  listMine(@CurrentActor() actor: RequestActor, @Query() query: RidePageQueryDto) {
    return this.rides.listForCustomer(actor, query.page, query.limit);
  }

  @Get('open')
  @ApiOperation({
    summary:
      'List open negotiating rides for drivers. Optional lat/lng filters by DRIVER_SEARCH_RADIUS_KM; without coords returns a capped recent list (DISPATCH_FALLBACK_LIMIT). Offline presence returns empty.',
  })
  listOpen(@CurrentActor() actor: RequestActor, @Query() query: DriverLocationQueryDto) {
    return this.rides.listOpen(actor, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get a ride by id' })
  get(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.get(actor, id);
  }

  @Get(':id/driver-location')
  @ApiOperation({
    summary:
      'Customer: assigned driver position while the ride is active (DEC-PROD-031). location=null when unknown or older than 2 minutes.',
  })
  driverLocation(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.driverLocation(actor, id);
  }

  @Get(':id/ledger')
  @ApiOperation({ summary: 'Sandbox COD ledger journal for a ride (customer/assigned driver)' })
  getLedger(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.getLedgerJournal(actor, id);
  }

  @Post(':id/offers')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver offer or counter on a negotiating ride' })
  offer(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateOfferDto,
  ) {
    return this.rides.offer(actor, id, dto);
  }

  @Post(':id/selection')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer selects an offer (Idempotency-Key required)' })
  select(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Headers('idempotency-key') idempotencyKey: string | string[] | undefined,
    @Body() dto: SelectOfferDto,
  ) {
    return this.rides.select(actor, id, readIdempotencyKey(idempotencyKey), dto);
  }

  @Post(':id/en-route')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver marks en route to pickup (ASSIGNED → DRIVER_EN_ROUTE)' })
  markEnRoute(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.markEnRoute(actor, id);
  }

  @Post(':id/arrived')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver marks arrived (DRIVER_EN_ROUTE → DRIVER_ARRIVED)' })
  markArrived(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.markArrived(actor, id);
  }

  @Post(':id/start')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Assigned driver starts trip with the customer pickup code (DRIVER_ARRIVED → IN_TRIP)',
  })
  startTrip(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: StartTripDto,
  ) {
    return this.rides.startTrip(actor, id, dto.pickupCode);
  }

  @Post(':id/complete')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Assigned driver completes trip (IN_TRIP → COMPLETED). Records committed agreedFareVnd only; no payment mock.',
  })
  complete(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.complete(actor, id);
  }

  @Post(':id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Customer cancels while NEGOTIATING or before IN_TRIP (ASSIGNED / DRIVER_EN_ROUTE / DRIVER_ARRIVED)',
  })
  cancel(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.rides.cancel(actor, id);
  }
}

function readIdempotencyKey(header: string | string[] | undefined): string {
  const value = Array.isArray(header) ? header[0] : header;
  const key = value?.trim() ?? '';
  if (key.length < 8 || key.length > 200) {
    throw rideError(400, 'VALIDATION_ERROR', 'Idempotency-Key must be 8 to 200 characters');
  }
  return key;
}
