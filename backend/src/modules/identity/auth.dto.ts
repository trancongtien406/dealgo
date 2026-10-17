import { IsEmail, IsObject, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

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
  @IsEmail({ require_tld: false })
  email!: string;
}

export class ConfirmEmailDto {
  @IsString()
  @MinLength(20)
  @MaxLength(512)
  token!: string;
}

export class RefreshSessionDto {
  @IsString()
  @MinLength(20)
  @MaxLength(512)
  refreshToken!: string;
}

export class OpsLoginDto {
  @IsEmail({ require_tld: false })
  email!: string;

  @IsString()
  @MinLength(8)
  @MaxLength(200)
  password!: string;
}

export class PasskeyAuthenticationOptionsDto {
  @IsString()
  @Matches(/^[+0-9][0-9\s\-()]{7,19}$/)
  phone!: string;
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

export class AuthenticationVerifyDto {
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
