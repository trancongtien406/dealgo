import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { loadEnv } from '../platform/config/index.js';
import { WorkersModule } from './workers.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => loadEnv(config),
    }),
    // No HTTP here; this only satisfies ThrottlerGuard DI on controllers pulled in
    // through RideModule -> IdentityModule. Without it the worker fails to boot.
    ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1_000 }]),
    WorkersModule,
  ],
})
export class StandaloneWorkerModule {}

async function bootstrap() {
  const logger = new Logger('WorkerMain');
  logger.log('Starting DealGo standalone background worker process...');
  const app = await NestFactory.createApplicationContext(StandaloneWorkerModule);
  app.enableShutdownHooks();
  logger.log('DealGo background workers are active (outbox, ride-expiry, schedulers).');
}

if (process.env.NODE_ENV !== 'test') {
  bootstrap().catch((err) => {
    // eslint-disable-next-line no-console
    console.error('Fatal error in worker-main:', err);
    process.exit(1);
  });
}
