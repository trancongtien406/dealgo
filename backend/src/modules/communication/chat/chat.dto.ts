import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Max, MaxLength, Min, MinLength } from 'class-validator';
import { CHAT_BODY_MAX_LENGTH } from './chat.constants.js';

export class PostChatMessageDto {
  @ApiProperty({ maxLength: CHAT_BODY_MAX_LENGTH })
  @IsString()
  @MinLength(1)
  @MaxLength(CHAT_BODY_MAX_LENGTH)
  body!: string;
}

export class ChatPageQueryDto {
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
}

/** DEC-PROD-056: ops chat review. The reason is stored in the audit log. */
export class ChatReviewDto {
  @ApiProperty({ enum: ['ride', 'food'] })
  @IsIn(['ride', 'food'])
  kind!: 'ride' | 'food';

  @ApiProperty({ format: 'uuid' })
  @IsUUID()
  id!: string;

  @ApiProperty({ minLength: 3, maxLength: 500 })
  @IsString()
  @MinLength(3)
  @MaxLength(500)
  reason!: string;


  @ApiProperty({ required: false, format: 'uuid', description: 'Support ticket that prompted the review' })
  @IsOptional()
  @IsUUID()
  ticketId?: string;
}
