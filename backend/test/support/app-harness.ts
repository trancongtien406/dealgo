import { INestApplication, type ModuleMetadata } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../src/modules/identity/identity.repository.js';
import { PLATFORM_SETTINGS_REPOSITORY } from '../../src/platform/settings/platform-settings.constants.js';
import type { MemoryPlatformSettingsRepository } from '../../src/platform/settings/platform-settings.repository.js';
import { MockSmsSender } from '../../src/integrations/sms/sms-sender.js';

export type TestUser = { token: string; userId: string };

/**
 * Memory-backed Nest app for HTTP specs of app-session endpoints, plus a phone-OTP login helper.
 */
export async function createTestApp(
  imports: NonNullable<ModuleMetadata['imports']>,
  options: { settings?: MemoryPlatformSettingsRepository } = {},
) {
  const identity = new MemoryIdentityRepository();
  const sms = new MockSmsSender('test');
  const builder = Test.createTestingModule({
    imports: [
      ConfigModule.forRoot({
        isGlobal: true,
        ignoreEnvFile: true,
        validate: () =>
          loadEnv({
            NODE_ENV: 'test',
            JWT_ACCESS_SECRET: 'test-access-secret',
            SMS_PROVIDER: 'mock',
            PUSH_PROVIDER: 'mock',
            PARTNER_ELIGIBILITY_BYPASS: 'true',
            OTP_THROTTLE_LIMIT: '1000',
          }),
      }),
      ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
      ...imports,
    ],
  })
    .overrideProvider(SMS_SENDER)
    .useValue(sms)
    .overrideProvider(IDENTITY_REPOSITORY)
    .useValue(identity);
  if (options.settings) {
    builder.overrideProvider(PLATFORM_SETTINGS_REPOSITORY).useValue(options.settings);
  }
  const moduleRef = await builder.compile();
  const app: INestApplication = moduleRef.createNestApplication();
  app.useGlobalPipes(createValidationPipe());
  app.useGlobalFilters(new HttpExceptionFilter());
  app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
  await app.init();

  let serial = 0;
  async function login(): Promise<TestUser> {
    serial += 1;
    const phone = `0912${String(serial).padStart(6, '0')}`;
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return {
      token: verified.body.data.accessToken as string,
      userId: verified.body.data.user.id as string,
    };
  }
  return { app, identity, login, http: () => request(app.getHttpServer()) };
}
