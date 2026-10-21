import { Inject, Injectable } from '@nestjs/common';
import { MAPS_PORT } from '../../integrations/maps/maps.constants.js';
import {
  UnavailableMapsError,
  type MapsPort,
  type PlaceSuggestion,
} from '../../integrations/maps/maps-port.js';

export type PlaceSearchResult = {
  items: PlaceSuggestion[];
  /** False when no maps provider is configured or it failed; the app then shows saved/recent only. */
  available: boolean;
};

const DEFAULT_LIMIT = 8;

/** Free-text place search on the configured maps provider (Goong / Google / mock in dev). */
@Injectable()
export class PlacesService {
  constructor(@Inject(MAPS_PORT) private readonly maps: MapsPort) {}

  /** Nearest address for a GPS fix ({ place: null } when unknown or no provider). */
  async reverse(
    lat: number,
    lng: number,
  ): Promise<{ place: PlaceSuggestion | null; available: boolean }> {
    try {
      return {
        place: await this.maps.reverseGeocode({ lat, lng }),
        available: true,
      };
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        return { place: null, available: false };
      }
      throw error;
    }
  }

  async search(
    query: string,
    limit = DEFAULT_LIMIT,
  ): Promise<PlaceSearchResult> {
    const trimmed = query.trim();
    if (trimmed.length < 2) {
      return { items: [], available: true };
    }
    try {
      return {
        items: await this.maps.searchPlaces(trimmed, limit),
        available: true,
      };
    } catch (error) {
      if (error instanceof UnavailableMapsError) {
        return { items: [], available: false };
      }
      throw error;
    }
  }
}
