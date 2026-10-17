import { NestFactory } from '@nestjs/core';
import { ConfigService } from '@nestjs/config';
import { SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module.js';
import {
  buildOpenApiDocument,
  localDevCors,
  requestIdMiddleware,
  shouldServeSwagger,
} from './platform/http/index.js';
import { createMorganMiddleware } from './platform/observability/index.js';
import type { AppEnv } from './platform/config/index.js';

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  app.use(requestIdMiddleware);
  app.use(createMorganMiddleware());
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
