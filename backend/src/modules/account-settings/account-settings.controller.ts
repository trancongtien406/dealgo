import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Request } from 'express';
import { extractClientIp } from '../../platform/http/client-ip.decorator.js';
import {
  AccessAuthGuard,
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  AuthMethodEnabledGuard,
  RequireAuthMethod,
} from '../identity/auth-method-enabled.guard.js';
import {
  ChangePasswordDto,
  SessionDeviceDto,
  UpdateNotificationPrefsDto,
} from './account-settings.dto.js';
import { AccountSettingsService } from './account-settings.service.js';

@ApiTags('me')
@ApiBearerAuth()
@Controller('v1/me')
@UseGuards(AccessAuthGuard)
export class AccountSettingsController {
  constructor(private readonly settings: AccountSettingsService) {}

  @Get('notification-preferences')
  @ApiOperation({ summary: 'S024 notification category preferences (DEC-PROD-038)' })
  getPrefs(@CurrentActor() actor: RequestActor) {
    return this.settings.getNotificationPrefs(actor.userId);
  }

  @Patch('notification-preferences')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update S024 notification preferences (DEC-PROD-038)' })
  updatePrefs(@CurrentActor() actor: RequestActor, @Body() dto: UpdateNotificationPrefsDto) {
    return this.settings.updateNotificationPrefs(actor.userId, dto);
  }

  @Get('sessions')
  @ApiOperation({ summary: 'S028 list active sessions (DEC-PROD-038)' })
  listSessions(@CurrentActor() actor: RequestActor) {
    return this.settings.listSessions(actor.userId, actor.sessionId);
  }

  @Delete('sessions/others')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'S028 revoke every session except the current one' })
  revokeOthers(@CurrentActor() actor: RequestActor) {
    return this.settings.revokeOtherSessions(actor.userId, actor.sessionId);
  }

  @Delete('sessions/:id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'S028 revoke one other session' })
  revokeOne(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.settings.revokeSession(actor.userId, id, actor.sessionId);
  }

  @Patch('sessions/current')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Update the current session device label (S028)' })
  touchCurrent(
    @CurrentActor() actor: RequestActor,
    @Body() dto: SessionDeviceDto,
    @Req() req: Request,
  ) {
    return this.settings.touchCurrentDevice(actor.sessionId, {
      deviceLabel: dto.deviceLabel ?? null,
      userAgent: typeof req.headers['user-agent'] === 'string' ? req.headers['user-agent'] : null,
      ipAddress: extractClientIp(req),
    });
  }

  @Post('password')
  @RequireAuthMethod('EMAIL_LOGIN_IDENTIFIER')
  @UseGuards(AuthMethodEnabledGuard)
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'S025 change customer password; revokes other sessions' })
  changePassword(@CurrentActor() actor: RequestActor, @Body() dto: ChangePasswordDto) {
    return this.settings.changePassword(
      actor.userId,
      actor.sessionId,
      dto.currentPassword,
      dto.newPassword,
    );
  }
}
