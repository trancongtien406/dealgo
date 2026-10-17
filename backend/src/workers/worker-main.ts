import { NestFactory } from '@nestjs/core';
import { Logger } from '@nestjs/common';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { loadEnv } from '../platform/config/index.js';
import { WorkersModule } from './workers.module.js';

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      validate: (config) => loadEnv(config),
    }),
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
