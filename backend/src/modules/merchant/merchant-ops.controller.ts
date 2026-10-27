import { Controller, Get, Param, ParseUUIDPipe, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { OpsSessionGuard } from '../identity/access-auth.guard.js';
import { OpsPageQueryDto } from '../food-order/food.dto.js';
import { MerchantService } from './merchant.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/stores')
@UseGuards(OpsSessionGuard)
export class MerchantOpsController {
  constructor(private readonly merchant: MerchantService) {}

  @Get()
  @ApiOperation({ summary: 'Ops paginated food store list' })
  list(@Query() query: OpsPageQueryDto) {
    return this.merchant.listStoresForOps(query.page, query.limit, {
      q: query.q,
      status: query.status,
      sale: query.sale,
      region: query.region,
      category: query.category,
      kyb: query.kyb,
      location: query.location,
    });
  }

  @Get(':id')
  @ApiOperation({ summary: 'Ops food store detail (catalog items included)' })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.merchant.getStoreForOps(id);
  }
}

export {
  MerchantOpsController as OpsStoresController,
  MerchantOpsController as StoreOpsController,
};
