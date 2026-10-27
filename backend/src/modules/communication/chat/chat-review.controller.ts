import { Body, Controller, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { CurrentActor, type RequestActor } from '../../identity/access-auth.guard.js';
import { OpsPermissionGuard } from '../../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../../identity/ops-rbac/ops-permission.decorator.js';
import { ChatReviewDto } from './chat.dto.js';
import { ChatReviewService } from './chat-review.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/chat-review')
@UseGuards(OpsPermissionGuard)
export class OpsChatReviewController {
  constructor(private readonly review: ChatReviewService) {}

  @RequireOpsPermission('chat.review')
  @Post()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary: 'Read the decrypted chat of a ride or food order (chat.review; audited with reason)',
  })
  read(@CurrentActor() actor: RequestActor, @Body() body: ChatReviewDto) {
    return this.review.review(body, actor.userId);
  }
}
