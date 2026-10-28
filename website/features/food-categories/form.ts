import {
  FOOD_CATEGORY_ICONS,
  FOOD_CATEGORY_TONES,
  type FoodCategoryDraft,
  type FoodCategoryIcon,
  type FoodCategoryPayload,
  type FoodCategoryRow,
  type FoodCategoryTone,
} from "@/features/food-categories/types";

export const FOOD_CATEGORY_IMAGE_MAX_BYTES = 1_000_000;

/** Bundled photo per default-image key — the same set the app ships, so a
 * category always shows a picture until ops upload their own. */
export const FOOD_CATEGORY_PHOTOS = {
  pho: "Phở",
  noodles: "Bún, mì",
  rice: "Cơm",
  banh_mi: "Bánh mì",
  tea: "Trà sữa",
  cafe: "Cà phê",
  fast_food: "Ăn nhanh",
  snack: "Ăn vặt",
  mart: "Siêu thị",
} as const;
export type FoodCategoryPhoto = keyof typeof FOOD_CATEGORY_PHOTOS;

/** Stored `icon` key → bundled photo (legacy keys share the closest photo). */
export const FOOD_CATEGORY_ICON_PHOTO: Record<FoodCategoryIcon, FoodCategoryPhoto> = {
  soup: "pho",
  "cooking-pot": "noodles",
  utensils: "rice",
  sandwich: "banh_mi",
  "cup-soda": "tea",
  coffee: "cafe",
  hamburger: "fast_food",
  pizza: "fast_food",
  drumstick: "fast_food",
  beef: "rice",
  fish: "rice",
  salad: "snack",
  "egg-fried": "rice",
  croissant: "banh_mi",
  "cake-slice": "tea",
  cookie: "snack",
  "ice-cream-cone": "tea",
  popcorn: "snack",
  beer: "cafe",
  apple: "mart",
  wheat: "mart",
  "shopping-cart": "mart",
  store: "mart",
};

/** One stored key per photo — what the default-image picker offers. */
export const FOOD_CATEGORY_PHOTO_ICONS: readonly FoodCategoryIcon[] = [
  "soup",
  "cooking-pot",
  "utensils",
  "sandwich",
  "cup-soda",
  "coffee",
  "hamburger",
  "salad",
  "apple",
];

export function foodCategoryPhotoSrc(photo: FoodCategoryPhoto): string {
  return `/assets/food-categories/${photo}.jpg`;
}

/** Default picture: the code's own photo for the seeded set, else the icon key's. */
export function foodCategoryDefaultPhoto(code: string | null, icon: FoodCategoryIcon): FoodCategoryPhoto {
  if (code && Object.hasOwn(FOOD_CATEGORY_PHOTOS, code)) return code as FoodCategoryPhoto;
  return FOOD_CATEGORY_ICON_PHOTO[icon] ?? "rice";
}


/** Same palette as the app tiles (`foodCategoryTone` in Flutter). */
export const FOOD_CATEGORY_TONE_META: Record<
  FoodCategoryTone,
  { label: string; fg: string; bg: string }
> = {
  orange: { label: "Cam", fg: "#EA580C", bg: "#FFF1E6" },
  amber: { label: "Vàng", fg: "#D97706", bg: "#FEF6E0" },
  red: { label: "Đỏ", fg: "#DC2626", bg: "#FDECEC" },
  pink: { label: "Hồng", fg: "#DB2777", bg: "#FDEBF3" },
  purple: { label: "Tím", fg: "#7C3AED", bg: "#F1EBFE" },
  indigo: { label: "Chàm", fg: "#4F46E5", bg: "#ECEDFD" },
  blue: { label: "Xanh dương", fg: "#2563EB", bg: "#E8F0FE" },
  green: { label: "Xanh lá", fg: "#16A34A", bg: "#E8F7EE" },
  brown: { label: "Nâu", fg: "#92400E", bg: "#F6EDE4" },
};

/** Mirrors Nest `slugifyFoodCategory` so the form can preview the code. */
export function slugifyFoodCategory(name: string): string {
  return name
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/đ/g, "d")
    .replace(/Đ/g, "D")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .slice(0, 40)
    .replace(/_+$/g, "");
}

/** Code Nest will assign for a new category (slug + `_2`… when taken). */
export function previewFoodCategoryCode(
  nameVi: string,
  taken: readonly string[],
): string {
  const base = slugifyFoodCategory(nameVi) || "danh_muc";
  const used = new Set(taken);
  if (!used.has(base)) return base;
  for (let n = 2; ; n += 1) {
    if (!used.has(`${base}_${n}`)) return `${base}_${n}`;
  }
}

/** Keyword → icon/tone so typing a name pre-picks a sensible look. */
const SUGGESTIONS: Array<[RegExp, FoodCategoryIcon, FoodCategoryTone]> = [
  [/pho|bun|mi|hu tieu|mien|chao|lau/, "soup", "orange"],
  [/com|xoi/, "utensils", "red"],
  [/banh mi|sandwich/, "sandwich", "brown"],
  [/trai cay|hoa qua|fruit/, "apple", "green"],
  [/tra|sinh to|nuoc|do uong|juice|tea/, "cup-soda", "pink"],
  [/ca phe|cafe|coffee/, "coffee", "blue"],
  [/ga|chicken/, "drumstick", "amber"],
  [/pizza/, "pizza", "red"],
  [/burger|an nhanh|fast/, "hamburger", "green"],
  [/hai san|ca |oc|tom|cua|fish|seafood/, "fish", "blue"],
  [/chay|salad|healthy/, "salad", "green"],
  [/banh ngot|bakery|banh kem|cake/, "cake-slice", "pink"],
  [/kem|ice/, "ice-cream-cone", "purple"],
  [/an vat|snack/, "popcorn", "purple"],
  [/bia|nhau|beer/, "beer", "amber"],
  [/thit|bo|nuong|bbq|beef/, "beef", "red"],
  [/sieu thi|tap hoa|mart|grocery/, "shopping-cart", "indigo"],
];

export function suggestFoodCategoryLook(
  nameVi: string,
): { icon: FoodCategoryIcon; tone: FoodCategoryTone } | null {
  const plain = ` ${slugifyFoodCategory(nameVi).replace(/_/g, " ")} `;
  for (const [re, icon, tone] of SUGGESTIONS) {
    if (re.test(plain)) return { icon, tone };
  }
  return null;
}

export function emptyFoodCategoryDraft(): FoodCategoryDraft {
  return {
    nameVi: "",
    nameEn: "",
    icon: "utensils",
    tone: "orange",
    active: true,
  };
}

export function draftFromFoodCategory(row: FoodCategoryRow): FoodCategoryDraft {
  return {
    nameVi: row.nameVi,
    nameEn: row.nameEn,
    icon: row.icon,
    tone: row.tone,
    active: row.active,
  };
}

export type FoodCategoryCheck =
  | { ok: true; payload: FoodCategoryPayload }
  | { ok: false; message: string };

/** English name is optional in the form: blank reuses the Vietnamese name. */
export function checkFoodCategoryDraft(
  draft: FoodCategoryDraft,
): FoodCategoryCheck {
  const nameVi = draft.nameVi.trim().replace(/\s+/g, " ");
  const nameEn = draft.nameEn.trim().replace(/\s+/g, " ") || nameVi;
  if (nameVi.length < 2 || nameVi.length > 60) {
    return { ok: false, message: "Tên danh mục cần 2–60 ký tự." };
  }
  if (nameEn.length < 2 || nameEn.length > 60) {
    return { ok: false, message: "Tên tiếng Anh cần 2–60 ký tự." };
  }
  if (!FOOD_CATEGORY_ICONS.includes(draft.icon)) {
    return { ok: false, message: "Chọn biểu tượng." };
  }
  if (!FOOD_CATEGORY_TONES.includes(draft.tone)) {
    return { ok: false, message: "Chọn màu." };
  }
  return {
    ok: true,
    payload: { nameVi, nameEn, icon: draft.icon, tone: draft.tone, active: draft.active },
  };
}

/** Only changed fields (Nest skips no-op patches but audits real ones). */
export function diffFoodCategoryPayload(
  row: FoodCategoryRow,
  payload: FoodCategoryPayload,
): Partial<FoodCategoryPayload> {
  const patch: Partial<FoodCategoryPayload> = {};
  if (payload.nameVi !== row.nameVi) patch.nameVi = payload.nameVi;
  if (payload.nameEn !== row.nameEn) patch.nameEn = payload.nameEn;
  if (payload.icon !== row.icon) patch.icon = payload.icon;
  if (payload.tone !== row.tone) patch.tone = payload.tone;
  if (payload.active !== row.active) patch.active = payload.active;
  return patch;
}

/** Drag-and-drop result: move `from` to the slot of `to`. */
export function moveFoodCategoryCode(
  codes: readonly string[],
  from: string,
  to: string,
): string[] | null {
  const a = codes.indexOf(from);
  const b = codes.indexOf(to);
  if (a < 0 || b < 0 || a === b) return null;
  const next = [...codes];
  next.splice(a, 1);
  next.splice(b, 0, from);
  return next;
}

export function foodCategoryImageSrc(imageUrl: string | null): string | null {
  const prefix = "/v1/public/food-categories/images/";
  if (!imageUrl?.startsWith(prefix)) return null;
  return `/api/public/food-categories/images/${imageUrl.slice(prefix.length)}`;
}
