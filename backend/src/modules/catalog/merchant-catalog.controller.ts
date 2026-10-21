import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Put,
  Query,
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
  ReplaceFoodItemOptionsDto,
  SetFoodItemAvailabilityDto,
  UpdateFoodItemDto,
  UpdateStoreLocationDto,
  UpdateStoreProfileDto,
  UpdateStoreServiceModeDto,
  UpdateStoreAcceptSettingsDto,
  UpdateStoreHoursDto,
  UpsertMenuCategoryDto,
  ReorderMenuCategoriesDto,
  MerchantHistoryQueryDto,
} from '../food-order/food.dto.js';
import { CatalogService } from './catalog.service.js';
import { FoodService } from '../food-order/food.service.js';
import { UploadAvatarDto } from '../identity/me.dto.js';
import { MenuItemImageService } from './menu-item-image.service.js';
import { StoreLogoService } from './store-logo.service.js';

@ApiTags('food')
@ApiBearerAuth()
@Controller('v1/food/merchant')
@UseGuards(CustomerSessionGuard)
export class MerchantCatalogController {
  constructor(
    private readonly catalog: CatalogService,
    private readonly food: FoodService,
    private readonly itemImages: MenuItemImageService,
    private readonly logos: StoreLogoService,
  ) {}

  @Get('catalog')
  @ApiOperation({
    summary: 'Get the authenticated merchant store catalog (creates an empty store if none)',
  })
  getCatalog(@CurrentActor() actor: RequestActor) {
    return this.catalog.getMerchantCatalog(actor);
  }

  @Patch('store/profile')
  @ApiOperation({ summary: 'M030 rename the merchant-owned store (2–120 chars)' })
  updateStoreProfile(@CurrentActor() actor: RequestActor, @Body() dto: UpdateStoreProfileDto) {
    return this.food.updateStoreProfile(actor, dto);
  }

  @Post('store/logo')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'M030 upload the store logo (JPEG/PNG/WebP, base64 or data URL, max UPLOAD_MAX_FILE_KB). Returns the store with logoUrl under /v1/public/store-logos.',
  })
  uploadStoreLogo(@CurrentActor() actor: RequestActor, @Body() dto: UploadAvatarDto) {
    return this.logos.upload(actor, {
      contentBase64: dto.contentBase64,
      dataUrl: dto.dataUrl,
      contentType: dto.contentType,
    });
  }

  @Delete('store/logo')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'M030 remove the store logo and discard the stored object' })
  clearStoreLogo(@CurrentActor() actor: RequestActor) {
    return this.logos.clear(actor);
  }

  @Patch('store/location')
  @ApiOperation({ summary: 'Set optional lat/lng for the merchant-owned store' })
  updateStoreLocation(@CurrentActor() actor: RequestActor, @Body() dto: UpdateStoreLocationDto) {
    return this.food.updateStoreLocation(actor, dto);
  }

  @Put('store/hours')
  @ApiOperation({ summary: 'Replace the merchant store weekly hours, closed days and cut-off' })
  updateStoreHours(@CurrentActor() actor: RequestActor, @Body() dto: UpdateStoreHoursDto) {
    return this.food.updateStoreHours(actor, dto);
  }

  @Put('store/accept-settings')
  @ApiOperation({ summary: 'Set M022 order acceptance: manual/auto, active-order cap, prep minutes' })
  updateStoreAcceptSettings(
    @CurrentActor() actor: RequestActor,
    @Body() dto: UpdateStoreAcceptSettingsDto,
  ) {
    return this.food.updateStoreAcceptSettings(actor, dto);
  }

  @Patch('store/status')
  @ApiOperation({
    summary: 'Set the merchant store intake mode (OPEN / BUSY / PAUSED, optional auto-resume)',
  })
  updateStoreServiceMode(
    @CurrentActor() actor: RequestActor,
    @Body() dto: UpdateStoreServiceModeDto,
  ) {
    return this.food.updateStoreServiceMode(actor, dto);
  }

  @Get('menu-categories')
  @ApiOperation({ summary: 'M025 list store menu categories (DEC-PROD-039)' })
  listMenuCategories(@CurrentActor() actor: RequestActor) {
    return this.food.listMenuCategories(actor);
  }

  @Post('menu-categories')
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'M025 create a menu category' })
  createMenuCategory(@CurrentActor() actor: RequestActor, @Body() dto: UpsertMenuCategoryDto) {
    return this.food.createMenuCategory(actor, dto);
  }

  @Patch('menu-categories/:categoryId')
  @ApiOperation({ summary: 'M025 rename/update a menu category' })
  updateMenuCategory(
    @CurrentActor() actor: RequestActor,
    @Param('categoryId', ParseUUIDPipe) categoryId: string,
    @Body() dto: UpsertMenuCategoryDto,
  ) {
    return this.food.updateMenuCategory(actor, categoryId, dto);
  }

  @Delete('menu-categories/:categoryId')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'M025 delete a menu category (items become uncategorized)' })
  deleteMenuCategory(
    @CurrentActor() actor: RequestActor,
    @Param('categoryId', ParseUUIDPipe) categoryId: string,
  ) {
    return this.food.deleteMenuCategory(actor, categoryId);
  }

  @Put('menu-categories/reorder')
  @ApiOperation({ summary: 'M025 reorder menu categories' })
  reorderMenuCategories(
    @CurrentActor() actor: RequestActor,
    @Body() dto: ReorderMenuCategoriesDto,
  ) {
    return this.food.reorderMenuCategories(actor, dto.orderedIds);
  }

  @Get('orders/history')
  @ApiOperation({ summary: 'M020 finished order history with filters (DEC-PROD-039)' })
  orderHistory(@CurrentActor() actor: RequestActor, @Query() query: MerchantHistoryQueryDto) {
    return this.food.merchantHistory(actor, query);
  }


  @Post('items/:itemId/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'M027 upload menu item photo (JPEG/PNG/WebP, base64 or data URL, max UPLOAD_MAX_FILE_KB). Returns updated item with imageUrl under /v1/public/menu-items.',
  })
  uploadItemImage(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UploadAvatarDto,
  ) {
    return this.itemImages.upload(actor, itemId, {
      contentBase64: dto.contentBase64,
      dataUrl: dto.dataUrl,
      contentType: dto.contentType,
    });
  }

  @Delete('items/:itemId/image')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'M027 clear menu item photo and discard the stored object' })
  clearItemImage(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
  ) {
    return this.itemImages.clear(actor, itemId);
  }

  @Post('items')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Create a catalog item on the merchant-owned store' })
  createItem(@CurrentActor() actor: RequestActor, @Body() dto: CreateFoodItemDto) {
    return this.catalog.createItem(actor, dto);
  }

  @Patch('items/:itemId')
  @ApiOperation({ summary: 'M027 update an owned catalog item (name/price/description/category/prep/image/availability)' })
  updateItem(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: UpdateFoodItemDto,
  ) {
    return this.catalog.updateItem(actor, itemId, dto);
  }

  @Put('items/:itemId/options')
  @ApiOperation({
    summary:
      'Replace option groups of an owned dish (min/max select, price deltas); ids on this dish are kept',
  })
  replaceItemOptions(
    @CurrentActor() actor: RequestActor,
    @Param('itemId', ParseUUIDPipe) itemId: string,
    @Body() dto: ReplaceFoodItemOptionsDto,
  ) {
    return this.catalog.replaceItemOptions(actor, itemId, dto);
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
