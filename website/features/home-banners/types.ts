export type HomeBannerAudience = "CUSTOMER" | "DRIVER" | "MERCHANT";
export type HomeBannerService = "ALL" | "RIDE" | "FOOD";
export type HomeBannerState =
  "LIVE" | "SCHEDULED" | "EXPIRED" | "INACTIVE" | "NO_IMAGE";

export type HomeBannerCounts = { impressions: number; clicks: number };

/** Row from Nest `GET /v1/ops/home-banners`. */
export type HomeBannerRow = {
  id: string;
  title: string;
  subtitle: string | null;
  imageUrl: string | null;
  ctaUrl: string | null;
  audiences: HomeBannerAudience[];
  service: HomeBannerService;
  regionCode: string | null;
  startsAt: string | null;
  endsAt: string | null;
  sortOrder: number;
  active: boolean;
  state: HomeBannerState;
  stats: HomeBannerCounts & { ctr: number; last7d: HomeBannerCounts };
  createdAt: string;
  updatedAt: string;
};

/** Editable form state; dates are `datetime-local` strings in ICT. */
export type HomeBannerDraft = {
  title: string;
  subtitle: string;
  ctaUrl: string;
  audiences: HomeBannerAudience[];
  service: HomeBannerService;
  regionCode: string;
  startsAt: string;
  endsAt: string;
};

export type HomeBannerPayload = {
  title: string;
  subtitle: string | null;
  ctaUrl: string | null;
  audiences: HomeBannerAudience[];
  service: HomeBannerService;
  regionCode: string | null;
  startsAt: string | null;
  endsAt: string | null;
};
