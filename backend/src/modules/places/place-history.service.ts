import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { foldVietnamese } from '../../integrations/maps/maps-port.js';
import {
  PLACE_HISTORY_REPOSITORY,
  type PlaceHistoryRecord,
  type PlaceHistoryRepository,
} from './place-history.repository.js';

/** Rows kept per user (older picks drop off). */
export const PLACE_HISTORY_MAX = 20;

export type PlaceHistoryView = {
  id: string;
  name: string;
  address: string;
  lat: number;
  lng: number;
  lastUsedAt: string;
};

/** Same place = same folded name in the same ~110 m cell. */
export function placeHistoryKey(name: string, lat: number, lng: number): string {
  return `${foldVietnamese(name).slice(0, 160)}@${lat.toFixed(3)},${lng.toFixed(3)}`;
}

@Injectable()
export class PlaceHistoryService {
  constructor(@Inject(PLACE_HISTORY_REPOSITORY) private readonly repo: PlaceHistoryRepository) {}

  now: () => Date = () => new Date();

  async list(userId: string): Promise<{ items: PlaceHistoryView[] }> {
    return { items: (await this.repo.list(userId, PLACE_HISTORY_MAX)).map(toView) };
  }

  async record(
    userId: string,
    input: { name: string; address?: string; lat: number; lng: number },
  ): Promise<PlaceHistoryView> {
    const name = input.name.trim().slice(0, 160);
    const address = (input.address?.trim() || name).slice(0, 300);
    const row = await this.repo.upsert(
      { userId, placeKey: placeHistoryKey(name, input.lat, input.lng), name, address, lat: input.lat, lng: input.lng },
      PLACE_HISTORY_MAX,
      this.now(),
    );
    return toView(row);
  }

  async remove(userId: string, id: string): Promise<{ deleted: true }> {
    if (!(await this.repo.remove(userId, id))) {
      throw new NotFoundException({ errorCode: 'PLACE_HISTORY_NOT_FOUND', message: 'History entry not found' });
    }
    return { deleted: true };
  }

  async clear(userId: string): Promise<{ deleted: number }> {
    return { deleted: await this.repo.clear(userId) };
  }
}

function toView(row: PlaceHistoryRecord): PlaceHistoryView {
  return {
    id: row.id,
    name: row.name,
    address: row.address,
    lat: row.lat,
    lng: row.lng,
    lastUsedAt: row.lastUsedAt.toISOString(),
  };
}
