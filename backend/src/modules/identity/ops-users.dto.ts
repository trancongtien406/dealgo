import { Type } from 'class-transformer';
import { IsBoolean, IsIn, IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';

export class OpsUsersPageQueryDto {
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  page?: number;

  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  @Max(50)
  limit?: number;

  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  q?: string;

  @IsOptional()
  @IsString()
  service?: string;

  @IsOptional()
  @IsString()
  region?: string;

  @IsOptional()
  @IsString()
  activity?: string;

  @IsOptional()
  @IsString()
  kyc?: string;

  @IsOptional()
  @IsString()
  role?: string;

  @IsOptional()
  @IsString()
  scope?: string;
}

/** DEC-PROD-036: a super-admin sets another operator's password. */
export class OpsStaffPasswordResetDto {
  @IsString()
  @MinLength(12)
  @MaxLength(128)
  newPassword!: string;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}

export class OpsStaffSuperAdminDto {
  @IsBoolean()
  superAdmin!: boolean;

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}


/** DEC-PROD-043: assign coarse ops staff role (super-admin only; audited). */
export class OpsStaffRoleDto {
  @IsIn(['ADMIN', 'SUPPORT', 'OPERATIONS', 'FINANCE'])
  staffRole!: 'ADMIN' | 'SUPPORT' | 'OPERATIONS' | 'FINANCE';

  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
