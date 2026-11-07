import { Injectable } from '@nestjs/common';
import type { RequestActor } from '../identity/access-auth.guard.js';
import type {
  CreateFoodItemDto,
  ReplaceFoodItemOptionsDto,
  OpsCatalogModerationQueryDto,
  SetFoodItemAvailabilityDto,
  UpdateFoodItemDto,
} from '../food-order/food.dto.js';
import type {
  OpsCatalogModerationPage,
  StoreDetail,
  StoreItemView,
} from '../food-order/food.repository.js';
import { FoodService } from '../food-order/food.service.js';
import { opsDateWindow } from '../operations/ops-date-window.js';
import { MenuItemImageService } from './menu-item-image.service.js';

@Injectable()
export class CatalogService {
  constructor(
    private readonly food: FoodService,
    private readonly itemImages: MenuItemImageService,
  ) {}

  getMerchantCatalog(actor: RequestActor): Promise<StoreDetail> {
    return this.food.getMerchantCatalog(actor);
  }

  async createItem(
    actor: RequestActor,
    dto: CreateFoodItemDto,
  ): Promise<StoreItemView> {
    const created = await this.food.createItem(actor, dto);
    if (dto.newImages && dto.newImages.length > 0) {
      return this.itemImages.syncFormImages(actor, created, {
        newImages: dto.newImages,
      });
    }
    return created;
  }

  async updateItem(
    actor: RequestActor,
    itemId: string,
    dto: UpdateFoodItemDto,
  ): Promise<StoreItemView> {
    const hasImageChanges =
      dto.imageUrls !== undefined ||
      dto.imageUrl === null ||
      (dto.newImages !== undefined && dto.newImages.length > 0);
    if (!hasImageChanges) {
      return this.food.updateItem(actor, itemId, dto);
    }
    // Load existing item before updating so we know which old images were removed.
    const catalog = await this.food.getMerchantCatalog(actor);
    const existing = catalog.items.find((row) => row.id === itemId);
    const { imageUrls, newImages, imageUrl, ...fieldDto } = dto;
    const hasFieldUpdates =
      fieldDto.name !== undefined ||
      fieldDto.priceVnd !== undefined ||
      fieldDto.originalPriceVnd !== undefined ||
      fieldDto.available !== undefined ||
      fieldDto.description !== undefined ||
      fieldDto.prepMinutes !== undefined ||
      fieldDto.menuCategoryId !== undefined ||
      fieldDto.optionGroups !== undefined ||
      (imageUrl !== undefined && imageUrl !== null && imageUrls === undefined);

    let current = existing;
    if (hasFieldUpdates || !current) {
      current = await this.food.updateItem(actor, itemId, {
        ...fieldDto,
        ...(imageUrl !== undefined && imageUrl !== null && imageUrls === undefined
          ? { imageUrl }
          : {}),
      });
    }
    return this.itemImages.syncFormImages(actor, current, {
      keptImageUrls: imageUrls,
      clearAll: imageUrl === null && imageUrls === undefined,
      newImages,
    });
  }

  async deleteItem(
    actor: RequestActor,
    itemId: string,
  ): Promise<{ deleted: true; id: string }> {
    const res = await this.food.deleteItem(actor, itemId);
    await this.itemImages.discardUrls(res.imageUrls);
    return { deleted: true, id: res.id };
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

  listModeration(query: OpsCatalogModerationQueryDto): Promise<OpsCatalogModerationPage> {
    return this.food.listCatalogModeration({
      page: query.page,
      limit: query.limit,
      q: query.q,
      store: query.store,
      category: query.category,
      status: query.status,
      window: opsDateWindow(query),
    });
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
