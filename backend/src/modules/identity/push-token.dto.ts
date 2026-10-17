import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';

export class RegisterPushTokenDto {
  @IsString()
  @MinLength(8)
  @MaxLength(512)
  token!: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  platform?: string;
}
