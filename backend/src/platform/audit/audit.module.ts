import { Module } from '@nestjs/common';
import { PrismaModule } from '../database/prisma.module.js';
import { AuditLogsService } from './audit-logs.service.js';

@Module({
  imports: [PrismaModule],
  providers: [AuditLogsService],
  exports: [AuditLogsService],
})
export class AuditModule {}
