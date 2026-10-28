import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { FoodService } from '../food-order/food.service.js';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { CreateStoreOfferDto, UpdateStoreOfferStatusDto } from '../promotion/promotion.dto.js';
import { PromotionService } from '../promotion/promotion.service.js';

/** Store-funded offers the merchant runs for its own store (applies only at that store). */
@ApiTags('food-merchant')
@ApiBearerAuth()
@Controller('v1/food/merchant/promotions')
@UseGuards(CustomerSessionGuard)
export class MerchantPromotionController {
  constructor(
    private readonly food: FoodService,
    private readonly promotions: PromotionService,
  ) {}

  @Get()
  @ApiOperation({ summary: 'Offers of the signed-in merchant store (all statuses)' })
  async list(@CurrentActor() actor: RequestActor) {
    const storeId = await this.food.merchantStoreId(actor);
    return { items: await this.promotions.listStoreOffersForMerchant(storeId) };
  }

  @Post()
  @ApiOperation({ summary: 'Create a store offer (percent with cap or fixed, min order, dates, usage limits)' })
  async create(@CurrentActor() actor: RequestActor, @Body() body: CreateStoreOfferDto) {
    const storeId = await this.food.merchantStoreId(actor);
    return this.promotions.createStoreOffer(storeId, body);
  }

  @Patch(':id/status')
  @ApiOperation({ summary: 'Pause, resume or end one of the store offers' })
  async setStatus(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateStoreOfferStatusDto,
  ) {
    const storeId = await this.food.merchantStoreId(actor);
    return this.promotions.setStoreOfferStatus(storeId, id, body.status);
  }
}
