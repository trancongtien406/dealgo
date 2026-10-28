import type {
  FoodCategoryPayload,
  FoodCategoryRow,
} from "@/features/food-categories/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export async function fetchFoodCategories(): Promise<FoodCategoryRow[]> {
  const envelope = await apiFetch<Envelope<{ items: FoodCategoryRow[] }>>(
    apiPaths.opsFoodCategories(),
  );
  return envelope.data.items;
}

export async function createFoodCategory(
  input: FoodCategoryPayload,
): Promise<FoodCategoryRow> {
  const envelope = await apiFetch<Envelope<FoodCategoryRow>>(
    apiPaths.opsFoodCategories(),
    { method: "POST", body: input },
  );
  return envelope.data;
}

export async function patchFoodCategory(
  code: string,
  input: Partial<FoodCategoryPayload> & { imageUrl?: null },
): Promise<FoodCategoryRow> {
  const envelope = await apiFetch<Envelope<FoodCategoryRow>>(
    apiPaths.opsFoodCategory(code),
    { method: "PATCH", body: input },
  );
  return envelope.data;
}

export async function deleteFoodCategory(code: string): Promise<void> {
  await apiFetch(apiPaths.opsFoodCategory(code), { method: "DELETE" });
}

export async function uploadFoodCategoryImage(
  code: string,
  dataUrl: string,
): Promise<FoodCategoryRow> {
  const envelope = await apiFetch<Envelope<FoodCategoryRow>>(
    apiPaths.opsFoodCategoryImage(code),
    { method: "POST", body: { dataUrl } },
  );
  return envelope.data;
}

export async function reorderFoodCategories(
  codes: string[],
): Promise<FoodCategoryRow[]> {
  const envelope = await apiFetch<Envelope<{ items: FoodCategoryRow[] }>>(
    apiPaths.opsFoodCategoriesReorder(),
    { method: "POST", body: { codes } },
  );
  return envelope.data.items;
}
