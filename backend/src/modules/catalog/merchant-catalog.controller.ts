import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  CustomerSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  CreateFoodItemDto,
  SetFoodItemAvailabilityDto,
  UpdateFoodItemDto,
  UpdateStoreLocationDto,
} from '../food-order/food.dto.js';
import { CatalogService } from './catalog.service.js';
import { FoodService } from '../food-order/food.service.js';

@ApiTags('food')
@ApiBearerAuth()
@Controller('v1/food/merchant')
@UseGuards(CustomerSessionGuard)
export class MerchantCatalogController {
  constructor(
    private readonly catalog: CatalogService,
    private readonly food: FoodService,
  ) {}

  @Get('catalog')
  @ApiOperation({
    summary: 'Get the authenticated merchant store catalog (creates an empty store if none)',
  })
  getCatalog(@CurrentActor() actor: RequestActor) {
    return this.catalog.getMerchantCatalog(actor);
  }

  @Patch('store/location')
  @ApiOperation({ summary: 'Set optional lat/lng for the merchant-owned store' })
  updateStoreLocation(@CurrentActor() actor: RequestActor, @Body() dto: UpdateStoreLocationDto) {
    return this.food.updateStoreLocation(actor, dto);
  }

  @Post('items')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Create a catalog item on the merchant-owned store' })
  createItem(@CurrentActor() actor: RequestActor, @Body() dto: CreateFoodItemDto) {
    return this.catalog.createItem(actor, dto);
  }

  @Patch('items/:itemId')
  @ApiOperation({ summary: 'Update name/price of an owned catalog item' })
  updateItem(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateFoodItemDto,
  ) {
    return this.catalog.updateItem(actor, itemId, dto);
  }

  @Patch('items/:itemId/availability')
  @ApiOperation({ summary: 'Toggle availability of an owned catalog item' })
  setAvailability(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: SetFoodItemAvailabilityDto,
  ) {
    return this.catalog.setItemAvailability(actor, itemId, dto);
  }
}
