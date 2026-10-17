import {
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import {
  CurrentActor,
  OpsSessionGuard,
  type RequestActor,
} from '../identity/access-auth.guard.js';
import { CreateOpsFaqDto, ListOpsFaqQueryDto, PatchOpsFaqDto } from './ops-faqs.dto.js';
import { OpsFaqService } from './ops-faq.service.js';

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/faqs')
@UseGuards(OpsSessionGuard)
export class OpsFaqsController {
  constructor(private readonly faqs: OpsFaqService) {}

  @Get()
  @ApiOperation({
    summary:
      'List Ops FAQ entries (Admin sees all statuses). Lazy-seeds OPEN-001..021 DRAFT answers labeled PROPOSED. Filter ?status=',
  })
  list(@Query() query: ListOpsFaqQueryDto) {
    return this.faqs.list(query.status);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({
    summary: 'Create an Ops FAQ entry; writes OpsAuditLog FAQ_UPDATE.',
  })
  create(@CurrentActor() actor: RequestActor, @Body() body: CreateOpsFaqDto) {
    return this.faqs.create({
      openId: body.openId,
      question: body.question,
      suggestedAnswer: body.suggestedAnswer,
      category: body.category,
      status: body.status,
      sortOrder: body.sortOrder,
      actorUserId: actor.userId,
      reason: body.reason,
    });
  }

  @Patch(':id')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({
    summary:
      'Patch FAQ (question/answer/status/category/sortOrder). Only PUBLISHED intended for future public/help.',
  })
  patch(
    @CurrentActor() actor: RequestActor,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: PatchOpsFaqDto,
  ) {
    return this.faqs.patch({
      id,
      openId: body.openId,
      question: body.question,
      suggestedAnswer: body.suggestedAnswer,
      status: body.status,
      category: body.category,
      sortOrder: body.sortOrder,
      actorUserId: actor.userId,
      reason: body.reason,
    });
  }
}
