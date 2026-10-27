import { Controller, Get, Header, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiExcludeController } from '@nestjs/swagger';
import type { AppEnv } from '../../platform/config/index.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { type AppLinksEnv, androidAssetLinks, appleAppSiteAssociation } from './app-links.js';

/** Domain association files; the website proxies /.well-known/* here (DEC-PROD-058). */
@ApiExcludeController()
@Controller('.well-known')
export class AppLinksController {
  constructor(private readonly config: ConfigService<AppEnv, true>) {}

  @Get('apple-app-site-association')
  @SkipResponseEnvelope()
  @Header('content-type', 'application/json')
  @Header('cache-control', 'public, max-age=3600')
  apple() {
    const body = appleAppSiteAssociation(this.env());
    if (!body) {
      throw new NotFoundException();
    }
    return body;
  }

  @Get('assetlinks.json')
  @SkipResponseEnvelope()
  @Header('content-type', 'application/json')
  @Header('cache-control', 'public, max-age=3600')
  android() {
    const body = androidAssetLinks(this.env());
    if (!body) {
      throw new NotFoundException();
    }
    return body;
  }

  private env(): AppLinksEnv {
    return {
      APP_LINKS_IOS_APP_IDS: this.config.get('APP_LINKS_IOS_APP_IDS', { infer: true }),
      APP_LINKS_ANDROID_PACKAGE: this.config.get('APP_LINKS_ANDROID_PACKAGE', { infer: true }),
      APP_LINKS_ANDROID_CERT_SHA256: this.config.get('APP_LINKS_ANDROID_CERT_SHA256', { infer: true }),
      APP_LINKS_PATHS: this.config.get('APP_LINKS_PATHS', { infer: true }),
    };
  }
}
