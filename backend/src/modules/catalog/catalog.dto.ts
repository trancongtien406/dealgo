import {
  OpsCatalogCategoriesQueryDto,
  OpsCatalogModerationQueryDto,
} from '../food-order/food.dto.js';

export class CatalogCategoriesQueryDto extends OpsCatalogCategoriesQueryDto {}
export class CatalogModerationQueryDto extends OpsCatalogModerationQueryDto {}

export {
  CatalogCategoriesQueryDto as OpsCatalogCategoriesQueryDto,
  CatalogModerationQueryDto as OpsCatalogModerationQueryDto,
};
