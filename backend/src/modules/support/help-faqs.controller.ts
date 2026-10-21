import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { HelpFaqQueryDto } from './ops-faqs.dto.js';
import { OpsFaqService } from './ops-faq.service.js';

/** Public in-app/website help (PUBLISHED entries only; DEC-PROD-021). */
@ApiTags('support')
@Controller('v1/public/help/faqs')
@UseGuards(ThrottlerGuard)
export class HelpFaqsController {
  constructor(private readonly faqs: OpsFaqService) {}

  @Get()
  @ApiOperation({ summary: 'Published help FAQ for an audience (default CUSTOMER)' })
  list(@Query() query: HelpFaqQueryDto) {
    return this.faqs.listHelp(query.audience ?? 'CUSTOMER');
  }
}
