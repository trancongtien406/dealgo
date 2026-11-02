import {
  IsEmail,
  IsObject,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  IsUUID,
} from 'class-validator';

export class PhoneChallengeDto {
  @IsString()
  @Matches(/^[+0-9][0-9\s\-()]{7,19}$/)
  phone!: string;
}

export class VerifyCodeDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class EmailVerificationDto {
  @IsEmail({ require_tld: false, allow_utf8_local_part: false })
  email!: string;
}

export class ConfirmEmailDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}

export class PasswordResetRequestDto {
  @IsEmail({ require_tld: false, allow_utf8_local_part: false })
  email!: string;
}

/** DEC-PROD-045: the emailed 6-digit code (the old link token is retired). */
export class PasswordResetConfirmDto {
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password!: string;
}

export class RefreshSessionDto {
  @IsString()
  @MinLength(20)
  @MaxLength(512)
  refreshToken!: string;
}

export class OpsLoginDto {
  @IsEmail({ require_tld: false, allow_utf8_local_part: false })
  email!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(200)
  password!: string;
}

export class EmailPasswordRegisterDto {
  @IsEmail({ require_tld: false, allow_utf8_local_part: false })
  email!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password!: string;

  @IsOptional()
  @IsString()
  @MinLength(1)
  @MaxLength(120)
  displayName?: string;
}

export class EmailPasswordLoginDto {
  @IsEmail({ require_tld: false, allow_utf8_local_part: false })
  email!: string;

  @IsString()
  @MinLength(6)
  @MaxLength(200)
  password!: string;
}

export class RegistrationVerifyDto {
  @IsString()
  id!: string;

  @IsString()
  rawId!: string;

  @IsObject()
  response!: Record<string, unknown>;

  @IsString()
  type!: string;

  @IsObject()
  clientExtensionResults!: Record<string, unknown>;

  @IsOptional()
  @IsString()
  authenticatorAttachment?: string;
}

export class PasskeySignupVerifyDto extends RegistrationVerifyDto {
  @IsUUID()
  ceremonyId!: string;
}

export class AuthenticationVerifyDto {
  @IsUUID()
  ceremonyId!: string;

  @IsString()
  id!: string;

  @IsString()
  rawId!: string;

  @IsObject()
  response!: Record<string, unknown>;

  @IsString()
  type!: string;

  @IsObject()
  clientExtensionResults!: Record<string, unknown>;

  @IsOptional()
  @IsString()
  authenticatorAttachment?: string;
}
