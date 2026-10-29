import {
  IsEmail,
  IsIn,
  IsISO8601,
  IsOptional,
  IsString,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

/** API gender values. UI labels: Nam→MALE, Nữ→FEMALE, Khác→OTHER. */
export const USER_GENDERS = ['MALE', 'FEMALE', 'OTHER'] as const;
export type UserGenderDto = (typeof USER_GENDERS)[number];

export class UpdateMeDto {
  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  displayName?: string;

  @IsOptional()
  @IsEmail({ require_tld: false })
  email?: string;

  /** Contact number (VN mobile), saved as typed — no OTP (profile completion). */
  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsString()
  @MaxLength(20)
  contactPhone?: string | null;

  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsISO8601({ strict: true })
  dateOfBirth?: string | null;

  @IsOptional()
  @ValidateIf((_, value) => value !== null)
  @IsIn(USER_GENDERS)
  gender?: UserGenderDto | null;
}

export class UploadAvatarDto {
  @ValidateIf((body: UploadAvatarDto) => !body.dataUrl)
  @IsString()
  @MinLength(8)
  @MaxLength(2_000_000)
  contentBase64?: string;

  @IsOptional()
  @IsString()
  @MaxLength(120)
  contentType?: string;

  @ValidateIf((body: UploadAvatarDto) => !body.contentBase64)
  @IsString()
  @MinLength(20)
  @MaxLength(2_000_000)
  dataUrl?: string;
}
