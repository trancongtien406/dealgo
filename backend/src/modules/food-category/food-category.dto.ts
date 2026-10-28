import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsIn,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';
import {
  FOOD_CATEGORY_ICONS,
  FOOD_CATEGORY_TONES,
  type FoodCategoryIcon,
  type FoodCategoryTone,
} from './food-category.js';

const trim = ({ value }: { value: unknown }) => (typeof value === 'string' ? value.trim() : value);

export class CreateFoodCategoryDto {
  /** The code is generated from this name (accents stripped) and never changes. */
  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  nameVi!: string;

  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  nameEn!: string;

  @IsIn(FOOD_CATEGORY_ICONS)
  icon!: FoodCategoryIcon;

  @IsIn(FOOD_CATEGORY_TONES)
  tone!: FoodCategoryTone;

  @IsOptional()
  @IsBoolean()
  active?: boolean;
}

export class PatchFoodCategoryDto {
  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  nameVi?: string;

  @IsOptional()
  @Transform(trim)
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  nameEn?: string;

  @IsOptional()
  @IsIn(FOOD_CATEGORY_ICONS)
  icon?: FoodCategoryIcon;

  @IsOptional()
  @IsIn(FOOD_CATEGORY_TONES)
  tone?: FoodCategoryTone;

  @IsOptional()
  @IsBoolean()
  active?: boolean;

  /** Only `null` (remove the image); uploads go through POST :code/image. */
  @IsOptional()
  @IsIn([null])
  imageUrl?: null;
}

export class ReorderFoodCategoriesDto {
  @IsArray()
  @ArrayMinSize(1)
  @ArrayMaxSize(200)
  @IsString({ each: true })
  @MaxLength(64, { each: true })
  codes!: string[];
}

export class UploadFoodCategoryImageDto {
  @ValidateIf((body: UploadFoodCategoryImageDto) => !body.dataUrl)
  @IsString()
  @MinLength(8)
  @MaxLength(1_400_000)
  contentBase64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  @ValidateIf((body: UploadFoodCategoryImageDto) => !body.contentBase64)
  @IsString()
  @MinLength(20)
  @MaxLength(1_400_000)
  dataUrl?: string;
}
