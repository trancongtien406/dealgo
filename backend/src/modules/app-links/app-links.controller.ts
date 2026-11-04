import { Controller, Get, Header, NotFoundException, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiExcludeController } from '@nestjs/swagger';
import type { AppEnv } from '../../platform/config/index.js';
import { SkipResponseEnvelope } from '../../platform/http/skip-response-envelope.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import { type AppLinksEnv, androidAssetLinks, appleAppSiteAssociation } from './app-links.js';

/** Domain association files; the website proxies /.well-known/* here (DEC-PROD-058). */
@ApiExcludeController()
@Controller('.well-known')
export class AppLinksController {
  constructor(
    private readonly config: ConfigService<AppEnv, true>,
    @Optional() private readonly platformSettings?: PlatformSettingsService,
  ) {}

  @Get('apple-app-site-association')
  @SkipResponseEnvelope()
  @Header('content-type', 'application/json')
  @Header('cache-control', 'public, max-age=3600')
  async apple() {
    const body = appleAppSiteAssociation(await this.env());
    if (!body) {
      throw new NotFoundException();
    }
    return body;
  }

  @Get('assetlinks.json')
  @SkipResponseEnvelope()
  @Header('content-type', 'application/json')
  @Header('cache-control', 'public, max-age=3600')
  async android() {
    const body = androidAssetLinks(await this.env());
    if (!body) {
      throw new NotFoundException();
    }
    return body;
  }

  private async env(): Promise<AppLinksEnv> {
    let ios = this.config.get('APP_LINKS_IOS_APP_IDS', { infer: true });
    let androidPkg = this.config.get('APP_LINKS_ANDROID_PACKAGE', { infer: true });
    let androidCert = this.config.get('APP_LINKS_ANDROID_CERT_SHA256', { infer: true });
    let paths = this.config.get('APP_LINKS_PATHS', { infer: true });

    if (this.platformSettings) {
      ios = (await this.platformSettings.getString('APP_LINKS_IOS_APP_IDS')) || ios;
      androidPkg = (await this.platformSettings.getString('APP_LINKS_ANDROID_PACKAGE')) || androidPkg;
      androidCert = (await this.platformSettings.getString('APP_LINKS_ANDROID_CERT_SHA256')) || androidCert;
      paths = (await this.platformSettings.getString('APP_LINKS_PATHS')) || paths;
    }

    return {
      APP_LINKS_IOS_APP_IDS: ios,
      APP_LINKS_ANDROID_PACKAGE: androidPkg,
      APP_LINKS_ANDROID_CERT_SHA256: androidCert,
      APP_LINKS_PATHS: paths,
    };
  }
}
