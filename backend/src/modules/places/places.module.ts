import { Module } from '@nestjs/common';
import { MapsModule } from '../../integrations/maps/maps.module.js';
import { IdentityModule } from '../identity/index.js';
import { PlacesController } from './places.controller.js';
import { PlacesService } from './places.service.js';

@Module({
  imports: [MapsModule, IdentityModule],
  controllers: [PlacesController],
  providers: [PlacesService],
})
export class PlacesModule {}
