import { Injectable } from '@nestjs/common';
import type { RequestActor } from '../identity/access-auth.guard.js';
import type { UpdateStoreLocationDto } from '../food-order/food.dto.js';
import type { StoreDetail } from '../food-order/food.repository.js';
import type { PageResult } from '../../shared/pagination/pagination.js';
import { FoodService, type OpsStoreListItem, type OpsStoreView } from '../food-order/food.service.js';

@Injectable()
export class MerchantService {
  constructor(private readonly food: FoodService) {}

  listStoresForOps(
    page?: number,
    limit?: number,
    filter?: {
      q?: string;
      status?: string;
      sale?: string;
      region?: string;
      category?: string;
      kyb?: string;
    },
  ): Promise<PageResult<OpsStoreListItem>> {
    return this.food.listStoresForOps(page, limit, filter);
  }

  getStoreForOps(id: string): Promise<OpsStoreView> {
    return this.food.getStoreForOps(id);
  }

  updateStoreLocation(actor: RequestActor, dto: UpdateStoreLocationDto): Promise<StoreDetail> {
    return this.food.updateStoreLocation(actor, dto);
  }
}
