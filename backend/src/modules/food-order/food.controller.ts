import {
  Ip,
  Body,
  Controller,
  Get,
  Headers,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Delete,
  Query,
  UseGuards,
} from '@nestjs/common';
import { StartPaymentDto } from '../payment/checkout/payment-checkout.dto.js';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { DriverLocationQueryDto } from '../dispatch/driver-location-query.dto.js';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from '../identity/access-auth.guard.js';
import {
  DeliverFoodOrderDto,
  FailFoodOrderDto,
  MerchantStatementQueryDto,
  ListFoodStoresQueryDto,
  MerchantStatsQueryDto,
  OpsPageQueryDto,
  PickupFoodOrderDto,
  PlaceFoodOrderDto,
  QuoteFoodDeliveryDto,
  ProposeFoodOrderChangeDto,
  RejectFoodOrderDto,
  ReleaseFoodOrderDto,
  FoodDeliveryAmountDto,
} from './food.dto.js';
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

  @Post('quote')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Server delivery fare for a store and drop-off (same rule as placement)' })
  quote(@CurrentActor() actor: RequestActor, @Body() dto: QuoteFoodDeliveryDto) {
    return this.food.quoteDelivery(actor, dto.storeId, dto.dropoff);
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

  @Get('merchant/statement')
  @ApiOperation({
    summary:
      'Merchant commission statement by Vietnam day (cash received at pickup, commission owed, settlements)',
  })
  merchantStatement(@CurrentActor() actor: RequestActor, @Query() query: MerchantStatementQueryDto) {
    return this.food.merchantStatement(actor, query.from, query.to);
  }

  @Get('merchant/stats')
  @ApiOperation({
    summary:
      'Merchant sales summary by Vietnam day: delivered/cancelled counts, item sales, open orders, top items',
  })
  merchantStats(@CurrentActor() actor: RequestActor, @Query() query: MerchantStatsQueryDto) {
    return this.food.merchantStats(actor, query.days ?? 7);
  }

  @Get('orders/:id')
  @ApiOperation({ summary: 'Get a food order by id' })
  getOrder(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.get(actor, id);
  }

  @Get('orders/:id/collection')
  @ApiOperation({ summary: 'Assigned driver: payment method, paid online vs cash to collect for this food order' })
  collection(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.driverCollection(actor, id);
  }

  @Get('orders/:id/payment')
  @ApiOperation({ summary: 'Payment method + status for this food order (CASH/PENDING/PAID/FAILED/…)' })
  paymentStatus(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.paymentStatus(actor, id);
  }

  @Post('orders/:id/payment')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Choose a payment method; online methods return paymentUrl/deeplink' })
  startPayment(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: StartPaymentDto,
    @Ip() ip: string,
  ) {
    return this.food.startPayment(actor, id, dto.methodCode, ip);
  }

  @Get('orders/:id/driver-location')
  @ApiOperation({
    summary:
      'Customer: courier position while the order is ASSIGNED/PICKED_UP (DEC-PROD-031). location=null when unknown or older than 2 minutes.',
  })
  driverLocation(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.driverLocation(actor, id);
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

  @Post('orders/:id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Merchant declines a new order with a reason (PLACED → CANCELLED)' })
  reject(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectFoodOrderDto,
  ) {
    return this.food.reject(actor, id, dto);
  }

  @Post('orders/:id/changes')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Merchant lowers quantities / removes out-of-stock lines (PLACED|PREPARING); customer must confirm',
  })
  proposeChange(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ProposeFoodOrderChangeDto,
  ) {
    return this.food.proposeChange(actor, id, dto);
  }

  @Get('orders/:id/change')
  @ApiOperation({ summary: 'Latest merchant edit of the order (customer or store owner), or null' })
  latestChange(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.latestChange(actor, id);
  }

  @Post('orders/:id/changes/:changeId/accept')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer accepts the merchant edit (new total applies)' })
  acceptChange(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('changeId', ParseUUIDPipe) changeId: string,
  ) {
    return this.food.respondChange(actor, id, changeId, true);
  }

  @Post('orders/:id/changes/:changeId/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer declines the merchant edit (order cancelled, no fee)' })
  rejectChange(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('changeId', ParseUUIDPipe) changeId: string,
  ) {
    return this.food.respondChange(actor, id, changeId, false);
  }

  @Post('orders/:id/ready')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Merchant marks ready (PREPARING → READY)' })
  ready(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.markReady(actor, id);
  }

  @Post('orders/:id/claim')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver claims a READY order (→ ASSIGNED) or an early-claimable PREPARING one (stays PREPARING, assigned)' })
  claim(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.claim(actor, id);
  }

  @Get('orders/:id/delivery-offers')
  @ApiOperation({ summary: 'Delivery-fee negotiation: fee mode (NEGOTIATE|FIXED), current offer, bounds and driver counters (drivers see only their own; none in FIXED)' })
  listDeliveryOffers(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.listDeliveryOffers(actor, id);
  }

  @Post('orders/:id/delivery-offers')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver counters the customer delivery-fee offer (or edits their pending counter); 409 FOOD_FEE_NEGOTIATION_DISABLED when FOOD_DELIVERY_FEE_MODE=FIXED' })
  counterDeliveryOffer(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FoodDeliveryAmountDto,
  ) {
    return this.food.counterDeliveryOffer(actor, id, dto.amountVnd);
  }

  @Delete('orders/:id/delivery-offers/mine')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Driver withdraws their pending delivery-fee counter' })
  withdrawDeliveryOffer(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.food.withdrawDeliveryOffer(actor, id);
  }

  @Post('orders/:id/delivery-offers/:offerId/select')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer selects a driver counter: assigns that driver at the agreed fee, other offers lose; 409 FOOD_FEE_NEGOTIATION_DISABLED in FIXED mode' })
  selectDeliveryOffer(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Param('offerId', ParseUUIDPipe) offerId: string,
  ) {
    return this.food.selectDeliveryOffer(actor, id, offerId);
  }

  @Post('orders/:id/delivery-fare')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Customer raises their delivery-fee offer while no driver is assigned' })
  raiseDeliveryFare(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FoodDeliveryAmountDto,
  ) {
    return this.food.raiseDeliveryFare(actor, id, dto.amountVnd);
  }

  @Post('orders/:id/release')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Assigned driver hands the order back before pickup (ASSIGNED → READY, early claim → PREPARING); counted as a driver cancellation',
  })
  release(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReleaseFoodOrderDto,
  ) {
    return this.food.release(actor, id, dto.reasonCode);
  }

  @Post('orders/:id/pickup')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Assigned driver picks up (ASSIGNED → PICKED_UP); handoverCode required when FOOD_HANDOVER_CODE_REQUIRED (DEC-PROD-036)',
  })
  pickup(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: PickupFoodOrderDto,
  ) {
    return this.food.pickup(actor, id, dto.handoverCode);
  }

  @Post('orders/:id/deliver')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Assigned driver delivers (PICKED_UP → DELIVERED); deliveryCode required when FOOD_DELIVERY_CODE_REQUIRED (DEC-PROD-036)',
  })
  deliver(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DeliverFoodOrderDto,
  ) {
    return this.food.deliver(actor, id, dto.deliveryCode);
  }

  @Post('orders/:id/fail')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Assigned driver marks delivery failed after pickup (PICKED_UP → FAILED) with a reason; before pickup use release' })
  fail(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: FailFoodOrderDto,
  ) {
    return this.food.fail(actor, id, dto);
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
