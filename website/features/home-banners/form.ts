import type {
  HomeBannerAudience,
  HomeBannerDraft,
  HomeBannerPayload,
  HomeBannerRow,
  HomeBannerService,
  HomeBannerState,
} from "@/features/home-banners/types";

export const HOME_BANNER_AUDIENCES: ReadonlyArray<{
  value: HomeBannerAudience;
  label: string;
}> = [
  { value: "CUSTOMER", label: "Khách hàng" },
  { value: "DRIVER", label: "Tài xế" },
  { value: "MERCHANT", label: "Cửa hàng" },
];

export const HOME_BANNER_SERVICES: ReadonlyArray<{
  value: HomeBannerService;
  label: string;
}> = [
  { value: "ALL", label: "Mọi dịch vụ" },
  { value: "RIDE", label: "Đặt xe" },
  { value: "FOOD", label: "Đồ ăn" },
];

export const HOME_BANNER_STATE_LABEL: Record<HomeBannerState, string> = {
  LIVE: "Đang chạy",
  SCHEDULED: "Đã lên lịch",
  EXPIRED: "Hết hạn",
  INACTIVE: "Đang tắt",
  NO_IMAGE: "Thiếu ảnh",
};

/** Recommended upload size; the app renders banners at 2:1. */
export const HOME_BANNER_IMAGE_HINT =
  "Ảnh 2:1, khuyến nghị 1200×600, JPEG/PNG/WebP tối đa 2 MB.";
export const HOME_BANNER_IMAGE_MAX_BYTES = 2 * 1024 * 1024;

/** Mirrors the Nest allowlist so the form can warn before saving (Nest decides). */
const APP_PATHS: Record<HomeBannerAudience, readonly RegExp[]> = {
  CUSTOMER: [
    /^\/customer$/,
    /^\/customer\/(book|shop|trips)$/,
    /^\/customer\/food\/stores\/[A-Za-z0-9_-]{1,64}$/,
    /^\/customer\/account\/(vouchers|notifications|help)$/,
  ],
  DRIVER: [
    /^\/driver$/,
    /^\/driver\/(jobs|earnings)$/,
    /^\/driver\/account\/(notifications|help)$/,
  ],
  MERCHANT: [
    /^\/merchant$/,
    /^\/merchant\/(orders|products)$/,
    /^\/merchant\/account\/(notifications|help)$/,
  ],
};

export const HOME_BANNER_CTA_EXAMPLES: Record<HomeBannerAudience, string[]> = {
  CUSTOMER: ["/customer/book", "/customer/shop", "/customer/account/vouchers"],
  DRIVER: ["/driver/jobs", "/driver/earnings"],
  MERCHANT: ["/merchant/orders", "/merchant/products"],
};

/** Returns a Vietnamese problem description, or null when the CTA looks valid. */
export function homeBannerCtaProblem(
  raw: string,
  audiences: readonly HomeBannerAudience[],
): string | null {
  const value = raw.trim();
  if (!value) {
    return null;
  }
  if (/^https:\/\//i.test(value)) {
    try {
      const url = new URL(value);
      if (!url.hostname.includes(".") || url.username || url.password) {
        return "Liên kết https không hợp lệ.";
      }
      return null;
    } catch {
      return "Liên kết https không hợp lệ.";
    }
  }
  let location = value;
  if (/^dealgo:\/\//i.test(value)) {
    const rest = value.slice("dealgo://".length);
    location = `/${rest.startsWith("app/") ? rest.slice(4) : rest}`;
  }
  if (!location.startsWith("/")) {
    return "Dùng đường dẫn trong app (/customer/...), dealgo:// hoặc https://.";
  }
  const q = location.indexOf("?");
  const path =
    (q < 0 ? location : location.slice(0, q))
      .replace(/\/+/g, "/")
      .replace(/\/$/, "") || "/";
  const query = q < 0 ? "" : location.slice(q + 1);
  if (!/^[A-Za-z0-9_=&.-]{0,200}$/.test(query)) {
    return "Tham số truy vấn chứa ký tự không cho phép.";
  }
  if (audiences.length === 0) {
    return "Chọn ít nhất một nhóm người dùng.";
  }
  const blocked = audiences.filter(
    (a) => !APP_PATHS[a].some((re) => re.test(path)),
  );
  if (blocked.length > 0) {
    const names = HOME_BANNER_AUDIENCES.filter((a) => blocked.includes(a.value))
      .map((a) => a.label)
      .join(", ");
    return `Đường dẫn ${path} không mở được cho: ${names}.`;
  }
  return null;
}

const ICT_OFFSET_MS = 7 * 60 * 60 * 1000;

/** ISO → `YYYY-MM-DDTHH:mm` shown in ICT (UTC+7). */
export function isoToIctInput(iso: string | null): string {
  if (!iso) {
    return "";
  }
  const ms = Date.parse(iso);
  if (!Number.isFinite(ms)) {
    return "";
  }
  return new Date(ms + ICT_OFFSET_MS).toISOString().slice(0, 16);
}

/** `YYYY-MM-DDTHH:mm` in ICT → ISO UTC; empty → null. */
export function ictInputToIso(value: string): string | null {
  const v = value.trim();
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/.test(v)) {
    return null;
  }
  const ms = Date.parse(`${v}:00+07:00`);
  return Number.isFinite(ms) ? new Date(ms).toISOString() : null;
}

export function formatIct(iso: string | null): string {
  const v = isoToIctInput(iso);
  if (!v) {
    return "—";
  }
  const [d, t] = v.split("T");
  const [y, m, day] = d!.split("-");
  return `${day}/${m}/${y} ${t} ICT`;
}

export function emptyHomeBannerDraft(): HomeBannerDraft {
  return {
    title: "",
    subtitle: "",
    ctaUrl: "",
    audiences: ["CUSTOMER"],
    service: "ALL",
    regionCode: "",
    startsAt: "",
    endsAt: "",
  };
}

export function draftFromHomeBanner(row: HomeBannerRow): HomeBannerDraft {
  return {
    title: row.title,
    subtitle: row.subtitle ?? "",
    ctaUrl: row.ctaUrl ?? "",
    audiences: [...row.audiences],
    service: row.service,
    regionCode: row.regionCode ?? "",
    startsAt: isoToIctInput(row.startsAt),
    endsAt: isoToIctInput(row.endsAt),
  };
}

export type DraftCheck =
  { ok: true; payload: HomeBannerPayload } | { ok: false; message: string };

export function checkHomeBannerDraft(draft: HomeBannerDraft): DraftCheck {
  const title = draft.title.trim();
  if (title.length < 2 || title.length > 80) {
    return { ok: false, message: "Tiêu đề cần 2–80 ký tự." };
  }
  const subtitle = draft.subtitle.trim();
  if (subtitle.length > 160) {
    return { ok: false, message: "Mô tả tối đa 160 ký tự." };
  }
  if (draft.audiences.length === 0) {
    return { ok: false, message: "Chọn ít nhất một nhóm người dùng." };
  }
  const ctaProblem = homeBannerCtaProblem(draft.ctaUrl, draft.audiences);
  if (ctaProblem) {
    return { ok: false, message: ctaProblem };
  }
  const startsAt = ictInputToIso(draft.startsAt);
  const endsAt = ictInputToIso(draft.endsAt);
  if (draft.startsAt.trim() && !startsAt) {
    return { ok: false, message: "Thời gian bắt đầu không hợp lệ." };
  }
  if (draft.endsAt.trim() && !endsAt) {
    return { ok: false, message: "Thời gian kết thúc không hợp lệ." };
  }
  if (startsAt && endsAt && Date.parse(endsAt) <= Date.parse(startsAt)) {
    return {
      ok: false,
      message: "Thời gian kết thúc phải sau thời gian bắt đầu.",
    };
  }
  return {
    ok: true,
    payload: {
      title,
      subtitle: subtitle || null,
      ctaUrl: draft.ctaUrl.trim() || null,
      audiences: [...draft.audiences],
      service: draft.service,
      regionCode: draft.regionCode.trim() || null,
      startsAt,
      endsAt,
    },
  };
}

/** Moves one id up (-1) or down (+1); returns null when it cannot move. */
export function moveHomeBannerId(
  ids: readonly string[],
  id: string,
  delta: -1 | 1,
): string[] | null {
  const from = ids.indexOf(id);
  const to = from + delta;
  if (from < 0 || to < 0 || to >= ids.length) {
    return null;
  }
  const next = [...ids];
  next.splice(from, 1);
  next.splice(to, 0, id);
  return next;
}

export function formatCtr(ctr: number): string {
  return `${(ctr * 100).toFixed(ctr > 0 && ctr < 0.001 ? 2 : 1)}%`;
}

/** Admin preview URL: Nest public image path → same-origin proxy. */
export function homeBannerImageSrc(imageUrl: string | null): string | null {
  const prefix = "/v1/public/home-banners/images/";
  if (!imageUrl?.startsWith(prefix)) {
    return null;
  }
  return `/api/public/home-banners/images/${imageUrl.slice(prefix.length)}`;
}

/** Only the fields that differ from the saved row (Nest rejects an empty patch). */
export function diffHomeBannerPayload(
  row: HomeBannerRow,
  payload: HomeBannerPayload,
): Partial<HomeBannerPayload> {
  const patch: Partial<HomeBannerPayload> = {};
  const same = (a: string | null, b: string | null) =>
    a === b || (a !== null && b !== null && Date.parse(a) === Date.parse(b));
  if (row.title !== payload.title) patch.title = payload.title;
  if (row.subtitle !== payload.subtitle) patch.subtitle = payload.subtitle;
  if ((row.ctaUrl ?? null) !== payload.ctaUrl) patch.ctaUrl = payload.ctaUrl;
  if (
    [...row.audiences].sort().join() !== [...payload.audiences].sort().join()
  ) {
    patch.audiences = payload.audiences;
  }
  if (row.service !== payload.service) patch.service = payload.service;
  if (row.regionCode !== payload.regionCode) {
    patch.regionCode = payload.regionCode;
  }
  if (!same(row.startsAt, payload.startsAt)) patch.startsAt = payload.startsAt;
  if (!same(row.endsAt, payload.endsAt)) patch.endsAt = payload.endsAt;
  return patch;
}
