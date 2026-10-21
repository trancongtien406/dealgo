import { Body, Controller, Get, HttpCode, HttpStatus, Param, Patch, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { AuthMethodPolicyService } from '../identity/auth-method-policy.service.js';
import { PatchAuthMethodDto } from './ops-auth-methods.dto.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/auth-methods')
@UseGuards(OpsPermissionGuard)
export class OpsAuthMethodsController {
  constructor(private readonly authMethods: AuthMethodPolicyService) {}

  @Get()
  @ApiOperation({
    summary:
      'List global auth method flags (PASSKEY, PHONE_SMS, EMAIL_LOGIN_IDENTIFIER). Defaults ENABLED.',
  })
  list() {
    return this.authMethods.list();
  }

  @RequireOpsPermission('settings.write')
  @Patch(':method')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Enable/disable a global auth method with reason; refuses disabling the last enabled method. Writes OpsAuditLog.',
  })
  patch(
    @CurrentActor() actor: RequestActor,
    @Param('method') method: string,
    @Body() body: PatchAuthMethodDto,
  ) {
    return this.authMethods.setEnabled(method, body.enabled, body.reason, actor.userId);
  }
}
