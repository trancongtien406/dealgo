-- DEC-PROD-067: admin-managed food store categories. Stores point at a category
-- by code; legacy free-text values are mapped onto the 9 defaults, anything
-- else becomes its own category so no store loses its label.
ALTER TYPE "OpsAuditEntityType" ADD VALUE 'FOOD_CATEGORY';
ALTER TYPE "OpsAuditAction" ADD VALUE 'FOOD_CATEGORY_CREATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'FOOD_CATEGORY_UPDATE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'FOOD_CATEGORY_DELETE';
ALTER TYPE "OpsAuditAction" ADD VALUE 'FOOD_CATEGORY_REORDER';

CREATE TABLE "food_categories" (
    "code" VARCHAR(64) NOT NULL,
    "nameVi" VARCHAR(60) NOT NULL,
    "nameEn" VARCHAR(60) NOT NULL,
    "icon" VARCHAR(32) NOT NULL,
    "tone" VARCHAR(16) NOT NULL,
    "imageUrl" VARCHAR(300),
    "sortOrder" INTEGER NOT NULL DEFAULT 0,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_categories_pkey" PRIMARY KEY ("code")
);

CREATE INDEX "food_categories_active_sortOrder_idx" ON "food_categories"("active", "sortOrder");

INSERT INTO "food_categories" ("code", "nameVi", "nameEn", "icon", "tone", "sortOrder", "updatedAt") VALUES
    ('pho',       'Phở',       'Pho',       'soup',          'orange', 0,  CURRENT_TIMESTAMP),
    ('noodles',   'Bún, mì',   'Noodles',   'cooking-pot',   'amber',  10, CURRENT_TIMESTAMP),
    ('rice',      'Cơm',       'Rice',      'utensils',      'red',    20, CURRENT_TIMESTAMP),
    ('banh_mi',   'Bánh mì',   'Banh mi',   'sandwich',      'brown',  30, CURRENT_TIMESTAMP),
    ('tea',       'Trà sữa',   'Milk tea',  'cup-soda',      'pink',   40, CURRENT_TIMESTAMP),
    ('cafe',      'Cà phê',    'Coffee',    'coffee',        'blue',   50, CURRENT_TIMESTAMP),
    ('fast_food', 'Ăn nhanh',  'Fast food', 'hamburger',     'green',  60, CURRENT_TIMESTAMP),
    ('snack',     'Ăn vặt',    'Snacks',    'popcorn',       'purple', 70, CURRENT_TIMESTAMP),
    ('mart',      'Siêu thị',  'Grocery',   'shopping-cart', 'indigo', 80, CURRENT_TIMESTAMP);

-- Legacy value -> slug (Vietnamese accents stripped) -> canonical code.
CREATE TEMP TABLE "legacy_store_category" AS
SELECT DISTINCT
    "category" AS "raw",
    NULLIF(
        btrim(
            regexp_replace(
                translate(
                    lower(btrim("category")),
                    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ',
                    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
                ),
                '[^a-z0-9]+', '_', 'g'
            ),
            '_'
        ),
        ''
    ) AS "code"
FROM "food_stores"
WHERE "category" IS NOT NULL;

UPDATE "legacy_store_category" SET "code" = CASE "code"
    WHEN 'bun' THEN 'noodles'
    WHEN 'mi' THEN 'noodles'
    WHEN 'bun_mi' THEN 'noodles'
    WHEN 'com' THEN 'rice'
    WHEN 'coffee' THEN 'cafe'
    WHEN 'ca_phe' THEN 'cafe'
    WHEN 'milk_tea' THEN 'tea'
    WHEN 'tra_sua' THEN 'tea'
    WHEN 'fastfood' THEN 'fast_food'
    WHEN 'an_nhanh' THEN 'fast_food'
    WHEN 'burger' THEN 'fast_food'
    WHEN 'pizza' THEN 'fast_food'
    WHEN 'chicken' THEN 'fast_food'
    WHEN 'an_vat' THEN 'snack'
    WHEN 'grocery' THEN 'mart'
    WHEN 'sieu_thi' THEN 'mart'
    WHEN 'tap_hoa' THEN 'mart'
    ELSE left("code", 64)
END;

INSERT INTO "food_categories" ("code", "nameVi", "nameEn", "icon", "tone", "sortOrder", "updatedAt")
SELECT DISTINCT ON (l."code")
    l."code",
    left(upper(left(btrim(l."raw"), 1)) || substr(btrim(l."raw"), 2), 60),
    left(upper(left(btrim(l."raw"), 1)) || substr(btrim(l."raw"), 2), 60),
    'utensils', 'orange', 1000, CURRENT_TIMESTAMP
FROM "legacy_store_category" l
WHERE l."code" IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM "food_categories" c WHERE c."code" = l."code")
ORDER BY l."code", l."raw";

UPDATE "food_stores" s SET "category" = l."code"
FROM "legacy_store_category" l
WHERE s."category" = l."raw";

DROP TABLE "legacy_store_category";

ALTER TABLE "food_stores" ADD CONSTRAINT "food_stores_category_fkey" FOREIGN KEY ("category") REFERENCES "food_categories"("code") ON DELETE RESTRICT ON UPDATE CASCADE;
