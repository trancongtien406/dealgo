-- AlterTable
ALTER TABLE "food_items" ADD COLUMN     "description" VARCHAR(500),
ADD COLUMN     "imageUrl" VARCHAR(400),
ADD COLUMN     "menuCategoryId" UUID,
ADD COLUMN     "prepMinutes" INTEGER;

-- AlterTable
ALTER TABLE "sessions" ADD COLUMN     "deviceLabel" VARCHAR(120),
ADD COLUMN     "ipAddress" VARCHAR(64),
ADD COLUMN     "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "userAgent" VARCHAR(400);

-- CreateTable
CREATE TABLE "food_menu_categories" (
    "id" UUID NOT NULL,
    "storeId" UUID NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "description" VARCHAR(200),
    "position" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "food_menu_categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_notification_preferences" (
    "userId" UUID NOT NULL,
    "ride" BOOLEAN NOT NULL DEFAULT true,
    "food" BOOLEAN NOT NULL DEFAULT true,
    "chat" BOOLEAN NOT NULL DEFAULT true,
    "promotion" BOOLEAN NOT NULL DEFAULT false,
    "news" BOOLEAN NOT NULL DEFAULT false,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_notification_preferences_pkey" PRIMARY KEY ("userId")
);

-- CreateIndex
CREATE INDEX "food_menu_categories_storeId_position_idx" ON "food_menu_categories"("storeId", "position");

-- CreateIndex
CREATE INDEX "food_items_menuCategoryId_idx" ON "food_items"("menuCategoryId");

-- AddForeignKey
ALTER TABLE "food_menu_categories" ADD CONSTRAINT "food_menu_categories_storeId_fkey" FOREIGN KEY ("storeId") REFERENCES "food_stores"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_items" ADD CONSTRAINT "food_items_menuCategoryId_fkey" FOREIGN KEY ("menuCategoryId") REFERENCES "food_menu_categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_notification_preferences" ADD CONSTRAINT "user_notification_preferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

