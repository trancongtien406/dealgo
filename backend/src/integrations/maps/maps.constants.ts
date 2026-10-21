export const MAPS_PORT = Symbol('MAPS_PORT');

/** Deterministic Da Nang city-center coords for MAPS_PROVIDER=mock. */
export const MOCK_DANANG_CENTER = { lat: 16.0544, lng: 108.2022 } as const;

/**
 * Real Da Nang places (public coordinates) used by MAPS_PROVIDER=mock for geocoding and place
 * search in dev/test. `label` stays the geocode label used by fare quotes; `name`/`address` are
 * what the place search shows.
 */
export const MOCK_DANANG_LANDMARKS: ReadonlyArray<{
  keywords: readonly string[];
  lat: number;
  lng: number;
  label: string;
  name?: string;
  address?: string;
}> = [
  {
    keywords: ['airport', 'dad', 'sân bay'],
    lat: 16.0439,
    lng: 108.1994,
    label: 'Da Nang International Airport',
    name: 'Sân bay Quốc tế Đà Nẵng',
    address: 'Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
  },
  {
    keywords: ['dragon', 'cầu rồng', 'rong'],
    lat: 16.061,
    lng: 108.2275,
    label: 'Dragon Bridge',
    name: 'Cầu Rồng',
    address: 'Nguyễn Văn Linh, An Hải Tây, Sơn Trà, Đà Nẵng',
  },
  {
    keywords: ['han market', 'chợ hàn', 'cho han'],
    lat: 16.068,
    lng: 108.2235,
    label: 'Han Market',
    name: 'Chợ Hàn',
    address: '119 Trần Phú, Hải Châu, Đà Nẵng',
  },
  {
    keywords: ['my khe', 'mỹ khê', 'beach', 'bãi biển'],
    lat: 16.0617,
    lng: 108.2476,
    label: 'My Khe Beach',
    name: 'Biển Mỹ Khê',
    address: 'Võ Nguyên Giáp, Phước Mỹ, Sơn Trà, Đà Nẵng',
  },
  {
    keywords: ['con market', 'chợ cồn', 'cho con'],
    lat: 16.0679,
    lng: 108.2141,
    label: 'Con Market',
    name: 'Chợ Cồn',
    address: '290 Hùng Vương, Hải Châu, Đà Nẵng',
  },
  {
    keywords: ['vincom', 'ngô quyền'],
    lat: 16.0717,
    lng: 108.2303,
    label: 'Vincom Plaza Da Nang',
    name: 'Vincom Plaza Đà Nẵng',
    address: '910A Ngô Quyền, An Hải Bắc, Sơn Trà, Đà Nẵng',
  },
  {
    keywords: ['bệnh viện đà nẵng', 'benh vien da nang', 'hospital'],
    lat: 16.0756,
    lng: 108.2149,
    label: 'Da Nang Hospital',
    name: 'Bệnh viện Đà Nẵng',
    address: '124 Hải Phòng, Thạch Thang, Hải Châu, Đà Nẵng',
  },
  {
    keywords: ['ga đà nẵng', 'ga da nang', 'railway', 'station', 'nhà ga'],
    lat: 16.0717,
    lng: 108.2097,
    label: 'Da Nang Railway Station',
    name: 'Ga Đà Nẵng',
    address: '791 Hải Phòng, Tam Thuận, Thanh Khê, Đà Nẵng',
  },
  {
    keywords: ['sơn trà', 'son tra', 'linh ứng', 'linh ung', 'chùa'],
    lat: 16.1003,
    lng: 108.2778,
    label: 'Linh Ung Pagoda',
    name: 'Chùa Linh Ứng Sơn Trà',
    address: 'Hoàng Sa, Thọ Quang, Sơn Trà, Đà Nẵng',
  },
  {
    keywords: ['ngũ hành sơn', 'ngu hanh son', 'marble'],
    lat: 16.0035,
    lng: 108.2635,
    label: 'Marble Mountains',
    name: 'Danh thắng Ngũ Hành Sơn',
    address: '52 Huyền Trân Công Chúa, Hòa Hải, Ngũ Hành Sơn, Đà Nẵng',
  },
];
