import { NestFactory } from '@nestjs/core';
import type { NestExpressApplication } from '@nestjs/platform-express';
import { ConfigService } from '@nestjs/config';
import { SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';
import {
  buildOpenApiDocument,
  localDevCors,
  applyTrustProxy,
  registerRouteBodyParsers,
  requestIdMiddleware,
  shouldServeSwagger,
} from './platform/http/index.js';
import {
  createAppLogger,
  createMorganMiddleware,
  initSentry,
  sentryOptionsFromEnv,
} from './platform/observability/index.js';
import type { AppEnv } from './platform/config/index.js';

async function bootstrap(): Promise<void> {
  initSentry(sentryOptionsFromEnv(process.env, 'api'));
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    logger: createAppLogger(),
  });
  // Before any middleware reads req.ip (throttling, audit): DEC-PROD-053.
  applyTrustProxy(app, process.env.TRUST_PROXY);
  app.use(requestIdMiddleware);

  app.use(createMorganMiddleware());
  registerRouteBodyParsers(app);
  app.enableShutdownHooks();
  const config = app.get(ConfigService<AppEnv, true>);
  const nodeEnv = config.get('NODE_ENV', { infer: true });
  app.enableCors(
    localDevCors({
      CORS_ALLOWED_ORIGINS: config.get('CORS_ALLOWED_ORIGINS', { infer: true }),
      NODE_ENV: nodeEnv,
    }),
  );
  if (shouldServeSwagger(nodeEnv, config.get('SWAGGER_ENABLED', { infer: true }))) {
    const document = buildOpenApiDocument(app);
    SwaggerModule.setup('docs', app, document, {
      jsonDocumentUrl: 'docs-json',
      yamlDocumentUrl: 'docs-yaml',
    });
  }
  await app.listen(config.get('PORT', { infer: true }));
}

await bootstrap();
