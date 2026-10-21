import { Module } from '@nestjs/common';
import { StorageModule } from '../../platform/storage/storage.module.js';
import { IdentityModule } from '../identity/index.js';
import { AvatarController, PublicAvatarController } from './avatar.controller.js';
import { AvatarService } from './avatar.service.js';

@Module({
  imports: [IdentityModule, StorageModule],
  controllers: [AvatarController, PublicAvatarController],
  providers: [AvatarService],
})
export class AvatarModule {}
