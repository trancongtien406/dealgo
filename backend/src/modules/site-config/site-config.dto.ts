import { IsObject, IsString, MaxLength, MinLength } from 'class-validator';

export class PatchSiteConfigDto {
  @IsObject()
  config!: Record<string, unknown>;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
