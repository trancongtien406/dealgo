import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Header,
  Post,
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { AccessAuthGuard, CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { UploadAvatarDto } from '../identity/me.dto.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { AvatarService } from './avatar.service.js';

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/me/avatar')
@UseGuards(AccessAuthGuard)
export class AvatarController {
  constructor(private readonly avatars: AvatarService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Upload avatar (JPEG/PNG/WebP, base64 or data URL, max UPLOAD_MAX_FILE_KB). Returns avatarUrl path under /v1/public/avatars.',
  })
  upload(@CurrentActor() actor: RequestActor, @Body() dto: UploadAvatarDto) {
    return this.avatars.upload(actor.userId, {
      contentBase64: dto.contentBase64,
      dataUrl: dto.dataUrl,
      contentType: dto.contentType,
    });
  }
}

@ApiTags('identity')
@Controller('v1/public/avatars')
@UseGuards(ThrottlerGuard)
export class PublicAvatarController {
  constructor(private readonly avatars: AvatarService) {}

  @Get(':userId/:file')
  @SkipResponseEnvelope()
  @Header('Cache-Control', 'public, max-age=86400, immutable')
  @Header('X-Content-Type-Options', 'nosniff')
  @ApiOperation({ summary: "A user's current avatar image (404 for replaced or unknown files)" })
  async read(@Param('userId') userId: string, @Param('file') file: string): Promise<StreamableFile> {
    const found = await this.avatars.read(userId, file);
    return new StreamableFile(found.body, { type: found.contentType, length: found.body.byteLength });
  }
}
