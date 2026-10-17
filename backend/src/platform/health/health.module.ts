import { Module } from '@nestjs/common';
import { DATABASE_PING } from '../database/database-ping.js';
import { PrismaModule } from '../database/prisma.module.js';
import { PrismaService } from '../database/prisma.service.js';
import { HealthController } from './health.controller.js';
import { HealthService } from './health.service.js';
import { REDIS_PROBE, TcpRedisProbe } from './redis-ping.js';

@Module({
  imports: [PrismaModule],
  controllers: [HealthController],
  providers: [
    HealthService,
    TcpRedisProbe,
    { provide: DATABASE_PING, useExisting: PrismaService },
    { provide: REDIS_PROBE, useExisting: TcpRedisProbe },
  ],
})
export class HealthModule {}
