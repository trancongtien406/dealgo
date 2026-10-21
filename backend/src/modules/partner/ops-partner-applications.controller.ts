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
  StreamableFile,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import {
  OpsPartnerApplicationQueryDto,
  PartnerDocumentParamsDto,
  RejectPartnerApplicationDto,
} from './partner.dto.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { PartnerService } from './partner.service.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/partner-applications')
@UseGuards(OpsPermissionGuard)
export class OpsPartnerApplicationsController {
  constructor(private readonly partners: PartnerService) {}

  @Get()
  @ApiOperation({ summary: 'List partner applications (default status=SUBMITTED)' })
  list(@Query() query: OpsPartnerApplicationQueryDto) {
    return this.partners.listForOps(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get partner application by ID for ops' })
  getById(@Param('id', ParseUUIDPipe) id: string) {
    return this.partners.getForOps(id);
  }

  @RequireOpsPermission('kyc.review')
  @Get(':id/documents/:index')
  @SkipResponseEnvelope()
  @ApiOperation({ summary: 'Download one stored KYC/KYB document (ops review only)' })
  async document(@Param() params: PartnerDocumentParamsDto): Promise<StreamableFile> {
    const file = await this.partners.readDocumentForOps(params.id, params.index);
    return new StreamableFile(file.body, {
      type: file.contentType,
      length: file.body.byteLength,
      disposition: `inline; filename="${file.filename}"`,
    });
  }

  @RequireOpsPermission('kyc.review')
  @Post(':id/approve')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Approve submitted KYC/KYB; sets RoleGrant ACTIVE' })
  approve(@CurrentActor() actor: RequestActor, @Param('id', ParseUUIDPipe) id: string) {
    return this.partners.approve(id, actor.userId);
  }

  @RequireOpsPermission('kyc.review')
  @Post(':id/reject')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Reject submitted KYC/KYB with reason; sets RoleGrant SUSPENDED',
  })
  reject(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: RejectPartnerApplicationDto,
  ) {
    return this.partners.reject(id, actor.userId, body.reason, body.issues ?? []);
  }
}
