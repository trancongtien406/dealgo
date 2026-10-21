import { Injectable } from '@nestjs/common';
import type { RequestActor } from '../identity/access-auth.guard.js';
import type {
  CreateFoodItemDto,
  ReplaceFoodItemOptionsDto,
  OpsCatalogCategoriesQueryDto,
  OpsCatalogModerationQueryDto,
  SetFoodItemAvailabilityDto,
  UpdateFoodItemDto,
} from '../food-order/food.dto.js';
import type {
  OpsCatalogCategoryItem,
  OpsCatalogCategoryPage,
  OpsCatalogModerationPage,
  StoreDetail,
  StoreItemView,
} from '../food-order/food.repository.js';
import { FoodService } from '../food-order/food.service.js';

@Injectable()
export class CatalogService {
  constructor(private readonly food: FoodService) {}

  getMerchantCatalog(actor: RequestActor): Promise<StoreDetail> {
    return this.food.getMerchantCatalog(actor);
  }

  createItem(actor: RequestActor, dto: CreateFoodItemDto): Promise<StoreItemView> {
    return this.food.createItem(actor, dto);
  }

  updateItem(
    actor: RequestActor,
    itemId: string,
    dto: UpdateFoodItemDto,
  ): Promise<StoreItemView> {
    return this.food.updateItem(actor, itemId, dto);
  }

  replaceItemOptions(
    actor: RequestActor,
    itemId: string,
    dto: ReplaceFoodItemOptionsDto,
  ): Promise<StoreItemView> {
    return this.food.replaceItemOptions(actor, itemId, dto);
  }

  setItemAvailability(
    actor: RequestActor,
    itemId: string,
    dto: SetFoodItemAvailabilityDto,
  ): Promise<StoreItemView> {
    return this.food.setItemAvailability(actor, itemId, dto);
  }

  listCategories(query: OpsCatalogCategoriesQueryDto): Promise<OpsCatalogCategoryPage> {
    return this.food.listStoreCategories(query);
  }

  getCategory(code: string): Promise<OpsCatalogCategoryItem> {
    return this.food.getStoreCategory(code);
  }

  renameCategory(code: string, name: string): Promise<OpsCatalogCategoryItem> {
    return this.food.renameStoreCategory(code, name);
  }

  listModeration(query: OpsCatalogModerationQueryDto): Promise<OpsCatalogModerationPage> {
    return this.food.listCatalogModeration(query);
  }

  approveItem(
    id: string,
  ): Promise<{ success: boolean; id: string; available: boolean; moderationStatus: string }> {
    return this.food.approveCatalogItem(id);
  }

  rejectItem(
    id: string,
  ): Promise<{ success: boolean; id: string; available: boolean; moderationStatus: string }> {
    return this.food.rejectCatalogItem(id);
  }
}
