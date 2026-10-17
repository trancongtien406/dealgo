import { Module } from '@nestjs/common';
import { PrismaModule } from '../../platform/database/index.js';
import { IdentityModule } from '../identity/index.js';
import { SettlementController } from './settlement.controller.js';
import { SettlementService } from './settlement.service.js';

@Module({
  imports: [PrismaModule, IdentityModule],
  controllers: [SettlementController],
  providers: [SettlementService],
  exports: [SettlementService],
})
export class SettlementModule {}
