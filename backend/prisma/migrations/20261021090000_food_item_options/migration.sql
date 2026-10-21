-- AlterTable
ALTER TABLE "food_order_lines" ADD COLUMN     "options" JSONB NOT NULL DEFAULT '[]';

-- CreateTable
CREATE TABLE "food_option_groups" (
    "id" UUID NOT NULL,
    "itemId" UUID NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "minSelect" INTEGER NOT NULL DEFAULT 0,
    "maxSelect" INTEGER NOT NULL DEFAULT 1,
    "position" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "food_option_groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "food_options" (
    "id" UUID NOT NULL,
    "groupId" UUID NOT NULL,
    "name" VARCHAR(80) NOT NULL,
    "priceDeltaVnd" INTEGER NOT NULL DEFAULT 0,
    "available" BOOLEAN NOT NULL DEFAULT true,
    "position" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "food_options_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "food_option_groups_itemId_idx" ON "food_option_groups"("itemId");

-- CreateIndex
CREATE INDEX "food_options_groupId_idx" ON "food_options"("groupId");

-- AddForeignKey
ALTER TABLE "food_option_groups" ADD CONSTRAINT "food_option_groups_itemId_fkey" FOREIGN KEY ("itemId") REFERENCES "food_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "food_options" ADD CONSTRAINT "food_options_groupId_fkey" FOREIGN KEY ("groupId") REFERENCES "food_option_groups"("id") ON DELETE CASCADE ON UPDATE CASCADE;

