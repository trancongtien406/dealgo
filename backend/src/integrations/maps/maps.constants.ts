export const MAPS_PORT = Symbol('MAPS_PORT');

/** Deterministic Da Nang city-center coords for MAPS_PROVIDER=mock. */
export const MOCK_DANANG_CENTER = { lat: 16.0544, lng: 108.2022 } as const;

export const MOCK_DANANG_LANDMARKS: ReadonlyArray<{
  keywords: readonly string[];
  lat: number;
  lng: number;
  label: string;
}> = [
  {
    keywords: ['airport', 'dad', 'sân bay'],
    lat: 16.0439,
    lng: 108.1994,
    label: 'Da Nang International Airport',
  },
  {
    keywords: ['dragon', 'cầu rồng', 'rong'],
    lat: 16.061,
    lng: 108.2275,
    label: 'Dragon Bridge',
  },
  {
    keywords: ['han market', 'chợ hàn', 'cho han'],
    lat: 16.068,
    lng: 108.2235,
    label: 'Han Market',
  },
];
