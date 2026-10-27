export const MAPS_CAPABILITIES = ["search", "reverse", "route"] as const;
export type MapsCapability = (typeof MAPS_CAPABILITIES)[number];

export const MAPS_PROVIDER_CHOICES = ["mapbox", "google"] as const;
export type MapsProviderChoice = (typeof MAPS_PROVIDER_CHOICES)[number];

/** Nest GET /v1/ops/maps-providers payload. */
export type NestMapsProviders = {
  googleConfigured: boolean;
  primary: { maps: string; routing: string };
  tiles: "mapbox";
  capabilities: Array<{
    capability: MapsCapability;
    key: string;
    chosen: MapsProviderChoice;
    effective: MapsProviderChoice;
    updatedAt: string | null;
    updatedByUserId: string | null;
  }>;
};

export type MapsCapabilityRow = NestMapsProviders["capabilities"][number] & {
  label: string;
  hint: string;
  updatedAtLabel: string;
  /** Admin picked Google but the server has no key, so Mapbox is serving. */
  degraded: boolean;
};

export type MapsProvidersView = {
  googleConfigured: boolean;
  primary: NestMapsProviders["primary"];
  rows: MapsCapabilityRow[];
};

export type PendingMapsChoice = {
  key: string;
  label: string;
  value: MapsProviderChoice;
};
