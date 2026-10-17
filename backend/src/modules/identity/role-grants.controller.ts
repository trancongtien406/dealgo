import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { IsIn, IsString } from 'class-validator';
import { CurrentActor, CustomerSessionGuard, type RequestActor } from './access-auth.guard.js';
import { RoleGrantsService, type RequestableRole } from './role-grants.service.js';

export class RequestRoleGrantDto {
  @IsString()
  @IsIn(['CUSTOMER', 'DRIVER', 'MERCHANT'])
  role!: RequestableRole;
}

@ApiTags('identity')
@ApiBearerAuth()
@Controller('v1/me/role-grants')
@UseGuards(CustomerSessionGuard)
export class RoleGrantsController {
  constructor(private readonly roleGrants: RoleGrantsService) {}

  @Get()
  @ApiOperation({ summary: 'List my role grants' })
  listMine(@CurrentActor() actor: RequestActor) {
    return this.roleGrants.listMine(actor.userId);
  }

  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Request a role grant' })
  requestRole(@CurrentActor() actor: RequestActor, @Body() body: RequestRoleGrantDto) {
    return this.roleGrants.requestRole(actor.userId, body.role);
  }
}
