import {
  IsBoolean,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
} from 'class-validator';

export class UpdateNotificationPrefsDto {
  @IsOptional()
  @IsBoolean()
  ride?: boolean;

  @IsOptional()
  @IsBoolean()
  food?: boolean;

  @IsOptional()
  @IsBoolean()
  chat?: boolean;

  @IsOptional()
  @IsBoolean()
  promotion?: boolean;

  @IsOptional()
  @IsBoolean()
  news?: boolean;
}

export class ChangePasswordDto {
  @IsString()
  @MinLength(1)
  @MaxLength(128)
  currentPassword!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(128)
  newPassword!: string;
}

export class SessionDeviceDto {
  @IsOptional()
  @IsString()
  @MaxLength(120)
  deviceLabel?: string;
}
