import { ConfigModule } from '@nestjs/config';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { afterEach, describe, expect, it } from 'vitest';
import type { INestApplication } from '@nestjs/common';
import { AppLinksModule } from './app-links.module.js';

async function boot(env: Record<string, string>): Promise<INestApplication> {
  const moduleRef = await Test.createTestingModule({
    imports: [ConfigModule.forRoot({ ignoreEnvFile: true, load: [() => env], isGlobal: true }), AppLinksModule],
  }).compile();
  const app = moduleRef.createNestApplication();
  await app.init();
  return app;
}

describe('AppLinksController', () => {
  let app: INestApplication | undefined;
  afterEach(async () => app?.close());

  it('serves both association files from env', async () => {
    app = await boot({
      APP_LINKS_IOS_APP_IDS: 'TEAM1.com.trancongtien.dealgo',
      APP_LINKS_ANDROID_PACKAGE: 'com.trancongtien.dealgo',
      APP_LINKS_ANDROID_CERT_SHA256: Array.from({ length: 32 }, () => 'AB').join(':'),
    });
    const aasa = await request(app.getHttpServer()).get('/.well-known/apple-app-site-association');
    expect(aasa.status).toBe(200);
    expect(aasa.headers['content-type']).toContain('application/json');
    expect(aasa.body.webcredentials.apps).toEqual(['TEAM1.com.trancongtien.dealgo']);
    const assetlinks = await request(app.getHttpServer()).get('/.well-known/assetlinks.json');
    expect(assetlinks.status).toBe(200);
    expect(assetlinks.body[0].target.package_name).toBe('com.trancongtien.dealgo');
  });

  it('returns 404 when not configured', async () => {
    app = await boot({});
    await request(app.getHttpServer()).get('/.well-known/apple-app-site-association').expect(404);
    await request(app.getHttpServer()).get('/.well-known/assetlinks.json').expect(404);
  });
});
