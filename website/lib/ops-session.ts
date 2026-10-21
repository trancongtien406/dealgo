import { cookies, headers } from "next/headers";
import { redirect } from "next/navigation";
import { verifyOpsAccessToken } from "@/lib/api/ops-upstream";
import { OPS_ACCESS_COOKIE, OPS_REFRESH_COOKIE } from "@/lib/ops-cookies";

export {
  OPS_ACCESS_COOKIE,
  OPS_REFRESH_COOKIE,
  opsSessionCookieOptions,
} from "@/lib/ops-cookies";

export type RequireOpsSessionResult =
  | { ok: true }
  | { ok: false; unavailable: true; message: string };

/**
 * Requires a valid ops access cookie (RSC-safe).
 * Probes Nest with the access token only — never rotates refresh here (cookies
 * are read-only in Server Components). When access is missing/invalid but a
 * refresh cookie remains, redirects to `/api/ops/session/refresh` which can
 * Set-Cookie, then returns to the admin path.
 */
export async function requireOpsSession(): Promise<RequireOpsSessionResult> {
  const jar = await cookies();
  const accessToken = jar.get(OPS_ACCESS_COOKIE)?.value;
  const refreshToken = jar.get(OPS_REFRESH_COOKIE)?.value;
  const hasRefresh =
    typeof refreshToken === "string" && refreshToken.length > 0;
  const currentPath = await resolveAdminPath();

  if (typeof accessToken !== "string" || accessToken.length === 0) {
    if (hasRefresh) {
      redirect(refreshRedirectUrl(currentPath));
    }
    redirect("/login");
  }

  const verified = await verifyOpsAccessToken(accessToken);
  if (verified.valid) {
    return { ok: true };
  }

  if (verified.status >= 500) {
    return {
      ok: false,
      unavailable: true,
      message:
        "Dịch vụ máy chủ DealGo Ops tạm thời không khả dụng (502/503). Kết nối tới NestJS API backend bị gián đoạn. Phiên làm việc của bạn vẫn được bảo lưu an toàn.",
    };
  }

  if (hasRefresh) {
    redirect(refreshRedirectUrl(currentPath));
  }
  redirect("/login");
}

function refreshRedirectUrl(currentPath: string): string {
  return `/api/ops/session/refresh?next=${encodeURIComponent(currentPath)}`;
}

async function resolveAdminPath(): Promise<string> {
  const headerStore = await headers();
  const raw = headerStore.get("x-dealgo-pathname");
  if (typeof raw === "string" && raw.startsWith("/") && !raw.startsWith("//")) {
    return raw.length > 2_048 ? "/" : raw;
  }
  return "/";
}
