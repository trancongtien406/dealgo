import { describe, expect, it } from 'vitest';
import {
  keyFromMenuItemImageUrl,
  menuItemImagePath,
} from './menu-item-image.service.js';

describe('menu item image paths', () => {
  it('round-trips public url to storage key', () => {
    const itemId = '11111111-1111-1111-1111-111111111111';
    const key = `menu-items/${itemId}/22222222-2222-2222-2222-222222222222.jpg`;
    const url = menuItemImagePath(itemId, key);
    expect(url).toBe(
      `/v1/public/menu-items/${itemId}/22222222-2222-2222-2222-222222222222.jpg`,
    );
    expect(keyFromMenuItemImageUrl(url)).toBe(key);
  });

  it('rejects non-public urls', () => {
    expect(keyFromMenuItemImageUrl('https://cdn.example/x.jpg')).toBeNull();
    expect(keyFromMenuItemImageUrl('/v1/public/avatars/u/a.jpg')).toBeNull();
  });
});
