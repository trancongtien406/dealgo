import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Put,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import {
  IssueListQueryDto,
  PutSentrySettingsDto,
  TestSentryDto,
  UpdateIssueStatusDto,
} from './system-errors.dto.js';
import { SystemErrorsService } from './system-errors.service.js';

/** Admin › Cài đặt › Sentry: org, region, projects and the encrypted auth token. */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/integrations/sentry')
@UseGuards(OpsPermissionGuard)
export class OpsSentrySettingsController {
  constructor(private readonly service: SystemErrorsService) {}

  @Get()
  @RequireOpsPermission('settings.write')
  @ApiOperation({
    summary:
      'Sentry settings: org, region, projects, token set/unset (last 4), scopes, test status.',
  })
  view() {
    return this.service.settingsView();
  }

  @Put()
  @RequireOpsPermission('settings.write')
  @ApiOperation({
    summary:
      'Update Sentry settings; null/"" clears a field. Token is encrypted. Audited with reason.',
  })
  update(
    @CurrentActor() actor: RequestActor,
    @Body() body: PutSentrySettingsDto,
  ) {
    return this.service.updateSettings(body, actor.userId);
  }

  @Post('test')
  @HttpCode(HttpStatus.OK)
  @RequireOpsPermission('settings.write')
  @ApiOperation({
    summary:
      'Check the token scopes and that every configured project is readable. Audited.',
  })
  test(@CurrentActor() actor: RequestActor, @Body() body: TestSentryDto) {
    return this.service.test(body.reason, actor.userId);
  }
}

/** Admin › Lỗi hệ thống: Sentry issues of the configured projects (read through the server). */
@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/system-errors')
@UseGuards(OpsPermissionGuard)
export class OpsSystemErrorsController {
  constructor(private readonly service: SystemErrorsService) {}

  @Get('issues')
  @RequireOpsPermission('errors.read')
  @ApiOperation({
    summary:
      'Sentry issues (25 per page) filtered by project, environment, status, period, search.',
  })
  list(@Query() query: IssueListQueryDto) {
    return this.service.listIssues(query);
  }

  @Get('issues/count')
  @RequireOpsPermission('errors.read')
  @ApiOperation({
    summary:
      'Unresolved issues in the last 14 days (nav badge); count is null when not configured.',
  })
  count() {
    return this.service.unresolvedCount();
  }

  @Get('issues/:id')
  @RequireOpsPermission('errors.read')
  @ApiOperation({
    summary: 'Issue detail with the latest event (top frames, tags).',
  })
  detail(@Param('id') id: string) {
    return this.service.issueDetail(id);
  }

  @Put('issues/:id/status')
  @RequireOpsPermission('errors.write')
  @ApiOperation({
    summary:
      'Resolve / ignore / unresolve (needs a token with event:write). Audited with reason.',
  })
  updateStatus(
    @CurrentActor() actor: RequestActor,
    @Param('id') id: string,
    @Body() body: UpdateIssueStatusDto,
  ) {
    return this.service.updateStatus(
      id,
      body.status,
      body.reason,
      actor.userId,
    );
  }
}
