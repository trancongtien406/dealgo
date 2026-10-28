import { afterEach, describe, expect, it, vi } from 'vitest';
import { MapboxMapsPort, cleanMapboxVnLabel } from './maps-port.js';

describe('Mapbox VN geocoding', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('strips the Malay "Jalan" prefix Mapbox puts on some VN streets', () => {
    expect(cleanMapboxVnLabel('Jalan Nguyen Hue, Bến Nghé, Thành phố Hồ Chí Minh')).toBe(
      'Nguyen Hue, Bến Nghé, Thành phố Hồ Chí Minh',
    );
    expect(cleanMapboxVnLabel('Nguyễn Huệ, Bến Nghé')).toBe('Nguyễn Huệ, Bến Nghé');
  });

  it('drops postal codes and the country, and restores VN diacritics on known areas', () => {
    expect(
      cleanMapboxVnLabel('3 Nguyễn Văn Linh, Hai Chau, Đà Nẵng 550000, Việt Nam'),
    ).toBe('3 Nguyễn Văn Linh, Hải Châu, Đà Nẵng');
    expect(cleanMapboxVnLabel('Trưng Nữ Vương, 550000, Da Nang')).toBe('Trưng Nữ Vương, Đà Nẵng');
  });

  it('forward search sends language=vi, country=vn and proximity=caller location', async () => {
    const calls: URL[] = [];
    vi.stubGlobal('fetch', async (url: URL) => {
      calls.push(new URL(url));
      return new Response(
        JSON.stringify({
          features: [{ text: 'Jalan Nguyen Hue', place_name: 'Jalan Nguyen Hue, Bến Nghé', center: [106.703, 10.774] }],
        }),
      );
    });
    const port = new MapboxMapsPort('pk.test');
    const out = await port.searchPlaces('Nguyen Hue', 3, { lat: 10.7745, lng: 106.703 });
    const p = calls[0]!.searchParams;
    expect(p.get('language')).toBe('vi');
    expect(p.get('country')).toBe('vn');
    expect(p.get('proximity')).toBe('106.703,10.7745');
    expect(out[0]!.name).toBe('Nguyen Hue');
    await port.searchPlaces('Nguyen Hue', 3);
    expect(calls[1]!.searchParams.get('proximity')).toBe('ip');
    await port.reverseGeocode({ lat: 10.77, lng: 106.7 });
    expect(calls[2]!.searchParams.get('country')).toBe('vn');
  });
  it('drops a leading postal code and restores accents (QA smoke)', () => {
    expect(
      cleanMapboxVnLabel('Đường Nguyễn Văn Linh, Bình Hiên, 50200 Hai Chau, Đà Nẵng, Việt Nam'),
    ).toBe('Đường Nguyễn Văn Linh, Bình Hiên, Hải Châu, Đà Nẵng');
  });
});
