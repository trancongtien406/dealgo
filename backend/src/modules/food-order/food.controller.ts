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
import { ListFoodStoresQueryDto, OpsPageQueryDto, PlaceFoodOrderDto } from './food.dto.js';
import { foodError } from './food.error.js';
import { FoodService } from './food.service.js';


@ApiTags('food')
@ApiBearerAuth()
@Controller('v1/food')
@UseGuards(CustomerSessionGuard)
export class FoodController {
  constructor(private readonly food: FoodService) {}

  @Get('stores')
  @ApiOperation({
    summary:
      'Browse food stores with page/search/category/geo/sort (DRIVER_SEARCH_RADIUS_KM when lat+lng set)',
  })
  listStores(@CurrentActor() actor: RequestActor, @Query() query: ListFoodStoresQueryDto) {
    return this.food.listStores(actor, query);
  }

  @Get('stores/:id')
  @ApiOperation({ summary: 'Get store catalog' })
  getStore(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.getStore(actor, id);
  }

  @Post('orders')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Place a food order (Idempotency-Key required)' })
  place(
    @CurrentActor() actor: RequestActor,
    @Headers('idempotency-key') idempotencyKey: string | string[] | undefined,
    @Body() dto: PlaceFoodOrderDto,
  ) {
    return this.food.place(actor, readIdempotencyKey(idempotencyKey), dto);
  }

  @Get('orders')
  @ApiOperation({ summary: 'Customer paginated food order history (actor-scoped)' })
  listMine(@CurrentActor() actor: RequestActor, @Query() query: OpsPageQueryDto) {
    return this.food.listForCustomer(actor, query.page, query.limit);
  }

  @Get('orders/ready')
  @ApiOperation({
    summary:
      'List ready orders for drivers. Optional lat/lng filters by DRIVER_SEARCH_RADIUS_KM from store coords when present, else dropoff; offline presence returns empty.',
  })
  listReady(@CurrentActor() actor: RequestActor, @Query() query: DriverLocationQueryDto) {
    return this.food.listReady(actor, query);
  }

  @Get('orders/queue')
  @ApiOperation({ summary: 'List open orders for the merchant store queue' })
  listQueue(@CurrentActor() actor: RequestActor) {
    return this.food.listQueue(actor);
  }

  @Get('orders/:id')
  @ApiOperation({ summary: 'Get a food order by id' })
  getOrder(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.get(actor, id);
  }

  @Get('orders/:id/ledger')
  @ApiOperation({ summary: 'Sandbox COD ledger journal for an order (owner/participants)' })
  getOrderLedger(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.getLedgerJournal(actor, id);
  }

  @Post('orders/:id/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Merchant accepts order (PLACED → PREPARING)' })
  accept(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.accept(actor, id);
  }

  @Post('orders/:id/ready')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Merchant marks ready (PREPARING → READY)' })
  ready(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.markReady(actor, id);
  }

  @Post('orders/:id/claim')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver claims ready order (READY → ASSIGNED)' })
  claim(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.claim(actor, id);
  }

  @Post('orders/:id/pickup')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver picks up (ASSIGNED → PICKED_UP)' })
  pickup(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.pickup(actor, id);
  }

  @Post('orders/:id/deliver')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver delivers (PICKED_UP → DELIVERED)' })
  deliver(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.deliver(actor, id);
  }

  @Post('orders/:id/fail')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver marks delivery failed (ASSIGNED|PICKED_UP → FAILED)' })
  fail(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.fail(actor, id);
  }

  @Post('orders/:id/cancel')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer cancels while PLACED only' })
  cancel(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.cancel(actor, id);
  }
}

function readIdempotencyKey(header: string | string[] | undefined): string {
  const value = Array.isArray(header) ? header[0] : header;
  const key = value?.trim() ?? '';
  if (key.length < 8 || key.length > 200) {
    throw foodError(400, 'VALIDATION_ERROR', 'Idempotency-Key must be 8 to 200 characters');
  }
  return key;
}
