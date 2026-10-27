import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post, Put, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiOperation, ApiTags } from '@nestjs/swagger';
import { ThrottlerGuard } from '@nestjs/throttler';
import { CurrentActor, type RequestActor } from '../identity/access-auth.guard.js';
import { OpsPermissionGuard } from '../identity/ops-rbac/ops-permission.guard.js';
import { RequireOpsPermission } from '../identity/ops-rbac/ops-permission.decorator.js';
import { PublicPageQueryDto, PublishPublicPageDto, SavePublicPageDraftDto } from './public-pages.dto.js';
import { PublicPagesService } from './public-pages.service.js';

/** Published privacy/terms/support content for the website and apps (DEC-PROD-055). */
@ApiTags('public')
@Controller('v1/public/pages')
@UseGuards(ThrottlerGuard)
export class PublicPagesController {
  constructor(private readonly pages: PublicPagesService) {}

  @Get(':slug')
  @ApiOperation({ summary: 'Published public page (privacy | terms | support); falls back to vi, then default' })
  get(@Param('slug') slug: string, @Query() query: PublicPageQueryDto) {
    return this.pages.getPublic(this.pages.parseSlug(slug), this.pages.parseLocale(query.locale));
  }
}

@ApiTags('ops')
@ApiBearerAuth()
@Controller('v1/ops/public-pages')
@UseGuards(OpsPermissionGuard)
export class OpsPublicPagesController {
  constructor(private readonly pages: PublicPagesService) {}

  @RequireOpsPermission('content.write')
  @Get()
  @ApiOperation({ summary: 'All public pages (draft state) for every locale' })
  list() {
    return this.pages.listOps();
  }

  @RequireOpsPermission('content.write')
  @Get(':slug/:locale')
  get(@Param('slug') slug: string, @Param('locale') locale: string) {
    return this.pages.getOps(this.pages.parseSlug(slug), this.pages.parseLocale(locale));
  }

  @RequireOpsPermission('content.write')
  @Put(':slug/:locale')
  @ApiOperation({ summary: 'Save draft (not public until published)' })
  save(
    @CurrentActor() actor: RequestActor,
    @Param('slug') slug: string,
    @Param('locale') locale: string,
    @Body() body: SavePublicPageDraftDto,
  ) {
    return this.pages.saveDraft(this.pages.parseSlug(slug), this.pages.parseLocale(locale), body, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Post(':slug/:locale/publish')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Publish draft as a new version (audited with reason)' })
  publish(
    @CurrentActor() actor: RequestActor,
    @Param('slug') slug: string,
    @Param('locale') locale: string,
    @Body() body: PublishPublicPageDto,
  ) {
    return this.pages.publish(this.pages.parseSlug(slug), this.pages.parseLocale(locale), body.reason, actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Post(':slug/:locale/reset')
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Replace the draft with the built-in default content' })
  reset(@CurrentActor() actor: RequestActor, @Param('slug') slug: string, @Param('locale') locale: string) {
    return this.pages.reset(this.pages.parseSlug(slug), this.pages.parseLocale(locale), actor.userId);
  }

  @RequireOpsPermission('content.write')
  @Get(':slug/:locale/revisions')
  revisions(@Param('slug') slug: string, @Param('locale') locale: string) {
    return this.pages.revisions(this.pages.parseSlug(slug), this.pages.parseLocale(locale));
  }
}
