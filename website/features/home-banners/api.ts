import type {
  HomeBannerPayload,
  HomeBannerRow,
} from "@/features/home-banners/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export async function fetchHomeBanners(): Promise<HomeBannerRow[]> {
  const envelope = await apiFetch<Envelope<HomeBannerRow[]>>(
    apiPaths.opsHomeBanners(),
  );
  return envelope.data;
}

export async function createHomeBanner(
  input: HomeBannerPayload,
): Promise<HomeBannerRow> {
  const envelope = await apiFetch<Envelope<HomeBannerRow>>(
    apiPaths.opsHomeBanners(),
    { method: "POST", body: input },
  );
  return envelope.data;
}

export async function patchHomeBanner(
  id: string,
  input: Partial<HomeBannerPayload> & { active?: boolean },
): Promise<HomeBannerRow> {
  const envelope = await apiFetch<Envelope<HomeBannerRow>>(
    apiPaths.opsHomeBanner(id),
    { method: "PATCH", body: input },
  );
  return envelope.data;
}

export async function deleteHomeBanner(id: string): Promise<void> {
  await apiFetch(apiPaths.opsHomeBanner(id), { method: "DELETE" });
}

export async function uploadHomeBannerImage(
  id: string,
  dataUrl: string,
): Promise<HomeBannerRow> {
  const envelope = await apiFetch<Envelope<HomeBannerRow>>(
    apiPaths.opsHomeBannerImage(id),
    { method: "POST", body: { dataUrl } },
  );
  return envelope.data;
}

export async function reorderHomeBanners(ids: string[]): Promise<void> {
  await apiFetch(apiPaths.opsHomeBannersReorder(), {
    method: "POST",
    body: { ids },
  });
}
