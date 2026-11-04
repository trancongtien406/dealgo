import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { Throttle, ThrottlerGuard } from '@nestjs/throttler';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { CreateDriverTopUpDto, DriverTopUpListQueryDto } from './driver-credit.dto.js';
import { DriverCreditService } from './driver-credit.service.js';

@ApiTags('driver')
@ApiBearerAuth()
@Controller('v1/driver/credit')
@UseGuards(CustomerSessionGuard)
export class DriverCreditController {
  constructor(private readonly credit: DriverCreditService) {}

  @Get()
  @ApiOperation({
    summary: 'Prepaid balance, outstanding fee debt and current top-up limits for the driver',
  })
  summary(@CurrentActor() actor: RequestActor) {
    return this.credit.summary(actor.userId);
  }

  @Get('top-ups')
  @ApiOperation({ summary: 'Recent driver top-ups, newest first' })
  list(@CurrentActor() actor: RequestActor, @Query() query: DriverTopUpListQueryDto) {
    return this.credit.listTopUps(actor.userId, query.limit ?? 20);
  }

  @Get('top-ups/:id')
  @ApiOperation({ summary: 'One top-up with the host checkout URL and QR payload' })
  get(
    @CurrentActor() actor: RequestActor,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.credit.topUp(actor.userId, id);
  }

  @Post('top-ups')
  @UseGuards(ThrottlerGuard)
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @ApiHeader({ name: 'Idempotency-Key', required: false })
  @ApiOperation({ summary: 'Create a prepayment link (PayOS or VNPAY); returns checkout URL + QR' })
  create(
    @CurrentActor() actor: RequestActor,
    @Body() body: CreateDriverTopUpDto,
    @Headers('idempotency-key') idempotencyKey?: string,
  ) {
    return this.credit.createTopUp({
      driverId: actor.userId,
      amountVnd: body.amountVnd,
      idempotencyKey: idempotencyKey?.slice(0, 120) ?? null,
    });
  }

  @Post('top-ups/:id/cancel')
  @ApiOperation({ summary: 'Cancel a top-up that is still waiting for payment' })
  cancel(
    @CurrentActor() actor: RequestActor,
    @Param('id', new ParseUUIDPipe({ version: '4' })) id: string,
  ) {
    return this.credit.cancelTopUp(actor.userId, id);
  }
}
