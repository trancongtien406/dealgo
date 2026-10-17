import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { ListCmsQueryDto } from './notification.dto.js';
import { NotificationService } from './notification.service.js';

@ApiTags('public')
@Controller('v1/public/cms')
export class PublicCmsController {
  constructor(private readonly notifications: NotificationService) {}

  @Get()
  @ApiOperation({ summary: 'Public CMS content (terms, privacy, support). ?kind= &q=' })
  list(@Query() query: ListCmsQueryDto) {
    return this.notifications.listCms({
      kind: query.kind,
      status: 'PUBLISHED',
      q: query.q,
    });
  }
}
