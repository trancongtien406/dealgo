import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
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
import { AvailableVouchersQueryDto, ValidateVoucherBodyDto } from './promotion.dto.js';
import { PromotionService } from './promotion.service.js';

@ApiTags('promotions')
@ApiBearerAuth()
@Controller('v1/promotions')
@UseGuards(CustomerSessionGuard)
export class PromotionClientController {
  constructor(private readonly promotions: PromotionService) {}

  @Get('available')
  @ApiOperation({
    summary:
      'Vouchers the signed-in customer can still use (ACTIVE, running, budget left, per-user limit not reached)',
  })
  available(@CurrentActor() actor: RequestActor, @Query() query: AvailableVouchersQueryDto) {
    return this.promotions.listAvailableForCustomer(actor.userId, query.serviceType);
  }

  @Post('validate')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Validate and calculate discount for Ride or Food order checkout (customer session)',
  })
  validate(
    @CurrentActor() actor: RequestActor,
    @Body() body: ValidateVoucherBodyDto,
  ) {
    return this.promotions.validateAndCalculate({
      voucherCode: body.voucherCode,
      serviceType: body.serviceType,
      orderAmount: body.orderAmount,
      deliveryFee: body.deliveryFee,
      customerId: actor.userId,
      storeId: body.storeId,
    });
  }
}
