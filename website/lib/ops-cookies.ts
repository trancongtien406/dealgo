export const OPS_ACCESS_COOKIE = "dealgo_ops_access";
export const OPS_REFRESH_COOKIE = "dealgo_ops_refresh";

export function opsSessionCookieOptions(maxAge: number) {
  return {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax" as const,
    path: "/",
    maxAge,
  };
}
