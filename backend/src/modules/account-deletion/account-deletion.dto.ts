import { ApiPropertyOptional, ApiProperty } from '@nestjs/swagger';
import { IsNotEmpty, IsOptional, IsString, Matches, MaxLength, MinLength } from 'class-validator';

export class ConfirmAccountDeletionDto {
  @ApiPropertyOptional({ description: '6-digit SMS code when method = PHONE_OTP' })
  @IsOptional()
  @IsString()
  @Matches(/^\d{4,8}$/)
  code?: string;

  @ApiPropertyOptional({ description: 'Account password when method = PASSWORD' })
  @IsOptional()
  @IsString()
  @MaxLength(200)
  password?: string;
}

export class OpsReasonDto {
  @ApiProperty({ minLength: 3, maxLength: 500 })
  @IsString()
  @IsNotEmpty()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;
}
