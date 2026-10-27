import 'reflect-metadata';
import { describe, expect, it } from 'vitest';
import { MockMapsPort } from '../../integrations/maps/maps-port.js';
import { OPS_PERMISSION_KEY } from '../identity/ops-rbac/ops-permission.decorator.js';
import { OpsPlacesController } from './ops-places.controller.js';
import { PlacesService } from './places.service.js';

describe('OpsPlacesController', () => {
  it('requires zones.write for the zone-form place search', () => {
    const permission: unknown = Reflect.getMetadata(
      OPS_PERMISSION_KEY,
      Object.getOwnPropertyDescriptor(OpsPlacesController.prototype, 'search')?.value as object,
    );
    expect(permission).toBe('zones.write');
  });

  it('delegates to the shared place search with proximity bias', async () => {
    const controller = new OpsPlacesController(new PlacesService(new MockMapsPort()));
    const result = await controller.search({ q: 'Chợ Hàn', lat: 16.06, lng: 108.2 });
    expect(result.available).toBe(true);
    expect(result.items[0]?.name).toBe('Chợ Hàn');
  });
});
