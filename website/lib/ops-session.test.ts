import { describe, it, expect, vi, beforeEach } from "vitest";

// Mock next/navigation
const redirectMock = vi.fn();
vi.mock("next/navigation", () => ({
  redirect: (url: string) => {
    redirectMock(url);
    throw new Error(`REDIRECT:${url}`);
  },
}));

// Mock next/headers
let mockCookieStore: Record<string, string | undefined> = {};
let mockHeaderStore: Record<string, string | undefined> = {};

vi.mock("next/headers", () => ({
  cookies: async () => ({
    get: (name: string) => {
      const val = mockCookieStore[name];
      return val !== undefined ? { name, value: val } : undefined;
    },
  }),
  headers: async () => ({
    get: (name: string) => mockHeaderStore[name],
  }),
}));

// Mock ops-upstream
const verifyOpsAccessTokenMock = vi.fn();
vi.mock("@/lib/api/ops-upstream", () => ({
  verifyOpsAccessToken: (...args: unknown[]) => verifyOpsAccessTokenMock(...args),
}));

import { requireOpsSession } from "./ops-session";
import { OPS_ACCESS_COOKIE, OPS_REFRESH_COOKIE } from "./ops-cookies";

describe("requireOpsSession", () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockCookieStore = {};
    mockHeaderStore = {};
  });

  it("redirects to /login when no cookies are present", async () => {
    await expect(requireOpsSession()).rejects.toThrow("REDIRECT:/login");
    expect(redirectMock).toHaveBeenCalledWith("/login");
  });

  it("redirects to refresh route when access token is missing but refresh token exists", async () => {
    mockCookieStore[OPS_REFRESH_COOKIE] = "refresh-token-xyz";
    mockHeaderStore["x-dealgo-pathname"] = "/rides";

    await expect(requireOpsSession()).rejects.toThrow(
      "REDIRECT:/api/ops/session/refresh?next=%2Frides",
    );
    expect(redirectMock).toHaveBeenCalledWith(
      "/api/ops/session/refresh?next=%2Frides",
    );
  });

  it("returns ok: true when access token is valid", async () => {
    mockCookieStore[OPS_ACCESS_COOKIE] = "valid-access-token";
    verifyOpsAccessTokenMock.mockResolvedValueOnce({ valid: true });

    const result = await requireOpsSession();
    expect(result).toEqual({ ok: true });
    expect(redirectMock).not.toHaveBeenCalled();
  });

  it("returns unavailable when backend returns status >= 500 (offline / ECONNREFUSED)", async () => {
    mockCookieStore[OPS_ACCESS_COOKIE] = "valid-access-token";
    verifyOpsAccessTokenMock.mockResolvedValueOnce({
      valid: false,
      status: 502,
      message: "Không thể kết nối máy chủ. Thử lại.",
    });

    const result = await requireOpsSession();
    expect(result).toEqual({
      ok: false,
      unavailable: true,
      message: expect.stringContaining("502/503"),
    });
    expect(redirectMock).not.toHaveBeenCalled();
  });

  it("redirects to refresh route when access token is invalid (401) and refresh token is present", async () => {
    mockCookieStore[OPS_ACCESS_COOKIE] = "expired-access-token";
    mockCookieStore[OPS_REFRESH_COOKIE] = "refresh-token-xyz";
    mockHeaderStore["x-dealgo-pathname"] = "/overview";
    verifyOpsAccessTokenMock.mockResolvedValueOnce({
      valid: false,
      status: 401,
      message: "Phiên đăng nhập hết hạn.",
    });

    await expect(requireOpsSession()).rejects.toThrow(
      "REDIRECT:/api/ops/session/refresh?next=%2Foverview",
    );
  });

  it("redirects to /login when access token is invalid (401) and no refresh token", async () => {
    mockCookieStore[OPS_ACCESS_COOKIE] = "expired-access-token";
    verifyOpsAccessTokenMock.mockResolvedValueOnce({
      valid: false,
      status: 401,
      message: "Phiên đăng nhập hết hạn.",
    });

    await expect(requireOpsSession()).rejects.toThrow("REDIRECT:/login");
  });
});
