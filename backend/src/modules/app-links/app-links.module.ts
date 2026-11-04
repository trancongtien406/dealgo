import { Module } from '@nestjs/common';
import { AppLinksController } from './app-links.controller.js';

@Module({
  controllers: [AppLinksController],
})
export class AppLinksModule {}
