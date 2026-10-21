export type PlatformSettingValueType = "string" | "number" | "json";

export type CategoryKey = "ALL" | "FARE" | "DISPATCH" | "ZONE_PAYMENT" | "SUPPORT";

export type PlatformSettingSourceFilter = "ALL" | "db" | "env";

export type Draft = {
  key: string;
  label: string;
};

export type PlatformSettingsFilterParams = {
  q?: string;
  category?: CategoryKey;
  source?: PlatformSettingSourceFilter;
};

export type PlatformSettingRow = {
  key: string;
  value: string;
  valueType: PlatformSettingValueType;
  source: "db" | "env";
  openIds: string[];
  updatedAt: string | null;
  updatedByUserId: string | null;
  label: string;
  hint: string;
};
