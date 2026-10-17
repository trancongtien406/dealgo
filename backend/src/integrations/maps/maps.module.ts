import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { AppEnv } from '../../platform/config/env.js';
import {
  GoongMapsPort,
  GoogleMapsPort,
  MockMapsPort,
  UnavailableMapsPort,
  type MapsPort,
} from './maps-port.js';
import { MAPS_PORT } from './maps.constants.js';

@Module({
  providers: [
    {
      provide: MAPS_PORT,
      inject: [ConfigService],
      useFactory: (config: ConfigService<AppEnv, true>): MapsPort => {
        const provider = config.get('MAPS_PROVIDER', { infer: true });
        const nodeEnv = config.get('NODE_ENV', { infer: true });
        if ((provider === 'mock' || provider === undefined) && nodeEnv !== 'production') {
          return new MockMapsPort();
        }
        if (provider === 'goong') {
          const key = config.get('GOONG_API_KEY', { infer: true });
          if (!key) {
            return new UnavailableMapsPort();
          }
          return new GoongMapsPort(key);
        }
        if (provider === 'google') {
          const key = config.get('GOOGLE_MAPS_API_KEY', { infer: true });
          if (!key) {
            return new UnavailableMapsPort();
          }
          return new GoogleMapsPort(key);
        }
        // Production without an explicit mock/provider, or unknown provider → unavailable.
        return new UnavailableMapsPort();
      },
    },
  ],
  exports: [MAPS_PORT],
})
export class MapsModule {}
