/** DEC-PROD-067 — store categories managed by ops (Nest `/v1/ops/food-categories`). */
export const FOOD_CATEGORY_ICONS = [
  "soup",
  "cooking-pot",
  "utensils",
  "sandwich",
  "cup-soda",
  "coffee",
  "hamburger",
  "pizza",
  "drumstick",
  "beef",
  "fish",
  "salad",
  "egg-fried",
  "croissant",
  "cake-slice",
  "cookie",
  "ice-cream-cone",
  "popcorn",
  "beer",
  "apple",
  "wheat",
  "shopping-cart",
  "store",
] as const;
export type FoodCategoryIcon = (typeof FOOD_CATEGORY_ICONS)[number];

export const FOOD_CATEGORY_TONES = [
  "orange",
  "amber",
  "red",
  "pink",
  "purple",
  "indigo",
  "blue",
  "green",
  "brown",
] as const;
export type FoodCategoryTone = (typeof FOOD_CATEGORY_TONES)[number];

export type FoodCategoryRow = {
  code: string;
  nameVi: string;
  nameEn: string;
  icon: FoodCategoryIcon;
  tone: FoodCategoryTone;
  imageUrl: string | null;
  sortOrder: number;
  active: boolean;
  storeCount: number;
  createdAt: string;
  updatedAt: string;
};

export type FoodCategoryDraft = {
  nameVi: string;
  nameEn: string;
  icon: FoodCategoryIcon;
  tone: FoodCategoryTone;
  active: boolean;
};

export type FoodCategoryPayload = FoodCategoryDraft;
