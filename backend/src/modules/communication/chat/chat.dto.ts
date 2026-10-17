import { ApiProperty } from '@nestjs/swagger';
import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Max, MaxLength, Min, MinLength } from 'class-validator';
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
