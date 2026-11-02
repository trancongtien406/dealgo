import { IsObject, IsString, MaxLength, MinLength } from 'class-validator';

export class PatchAppVersionPolicyDto {
  @IsObject()
  policy!: Record<string, unknown>;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
