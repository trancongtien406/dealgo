import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, OpsSessionGuard, type RequestActor } from './access-auth.guard.js';
import {
  OpsStaffPasswordResetDto,
  OpsStaffRoleDto,
  OpsStaffSuperAdminDto,
  OpsUsersPageQueryDto,
} from './ops-users.dto.js';
import {
  OPS_PERMISSIONS,
  OPS_ROLE_PERMISSIONS,
  OPS_STAFF_ROLES,
} from './ops-rbac/ops-permissions.js';
import { OpsStaffSecurityService } from './ops-staff-security.service.js';
import { OpsUsersService } from './ops-users.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/staff')
@UseGuards(OpsSessionGuard)
export class OpsStaffController {
  constructor(
    private readonly users: OpsUsersService,
    private readonly security: OpsStaffSecurityService,
  ) {}

  @Get('me')
  @ApiOperation({ summary: 'The signed-in operator: id + superAdmin (DEC-PROD-036)' })
  me(@CurrentActor() actor: RequestActor) {
    return this.security.self(actor.userId);
  }

  @Post(':id/password-reset')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Super-admin sets another operator password; revokes their Admin sessions; audited (DEC-PROD-036)',
  })
  resetPassword(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsStaffPasswordResetDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.security.resetPassword({
      actorUserId: actor.userId,
      targetUserId: id,
      newPassword: body.newPassword,
      reason: body.reason,
    });
  }

  @Post(':id/super-admin')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Super-admin grants/revokes the super-admin flag; the last one cannot be revoked; audited',
  })
  setSuperAdmin(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsStaffSuperAdminDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.security.setSuperAdmin({
      actorUserId: actor.userId,
      targetUserId: id,
      superAdmin: body.superAdmin,
      reason: body.reason,
    });
  }

  @Get('rbac-matrix')
  @ApiOperation({ summary: 'Default ops role → permission matrix (DEC-PROD-043)' })
  rbacMatrix() {
    return {
      roles: [...OPS_STAFF_ROLES],
      permissions: [...OPS_PERMISSIONS],
      grants: Object.fromEntries(
        OPS_STAFF_ROLES.map((role) => [role, [...OPS_ROLE_PERMISSIONS[role]]]),
      ),
    };
  }

  @Post(':id/staff-role')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Super-admin assigns OpsStaffRole; audited (DEC-PROD-043)',
  })
  setStaffRole(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: OpsStaffRoleDto,
    @CurrentActor() actor: RequestActor,
  ) {
    return this.security.setStaffRole({
      actorUserId: actor.userId,
      targetUserId: id,
      staffRole: body.staffRole,
      reason: body.reason,
    });
  }

  @Get()
  @ApiOperation({ summary: 'Ops paginated staff members (users with OPS role grant)' })
  list(@Query() query: OpsUsersPageQueryDto) {
    return this.users.listStaff(query.page, query.limit, {
      q: query.q,
      status: query.status,
      role: query.role,
      scope: query.scope,
    });
  }

  @Get(':id')
  @ApiOperation({
    summary: 'Ops staff detail (safe fields; no credentials or session tokens)',
  })
  get(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.getStaff(id);
  }
}
