import { describe, expect, it, vi, beforeEach } from "vitest";
import { POST, DELETE } from "./route";
import { OPS_ACCESS_COOKIE, OPS_REFRESH_COOKIE } from "@/lib/ops-session";

const mockCookieStore = {
  get: vi.fn(),
  set: vi.fn(),
};

vi.mock("next/headers", () => ({
  cookies: vi.fn(async () => mockCookieStore),
}));

describe("Ops Session Route /api/ops/session", () => {
  beforeEach(() => {
    vi.restoreAllMocks();
    mockCookieStore.get.mockReset();
    mockCookieStore.set.mockReset();
  });

  it("rejects POST with 403 on cross-origin CSRF attempt", async () => {
    const req = new Request("http://localhost:3000/api/ops/session", {
      method: "POST",
      headers: {
        Origin: "https://evil-attacker.com",
        Host: "localhost:3000",
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: "ops@dealgo.vn",
        password: "Password123!",
      }),
    });

    const res = await POST(req);
    expect(res.status).toBe(403);
    const json = await res.json();
    expect(json.message).toContain("Yêu cầu không hợp lệ.");
  });

  it("rejects DELETE with 403 on cross-origin CSRF attempt", async () => {
    const req = new Request("http://localhost:3000/api/ops/session", {
      method: "DELETE",
      headers: {
        Origin: "https://evil-attacker.com",
        Host: "localhost:3000",
      },
    });

    const res = await DELETE(req);
    expect(res.status).toBe(403);
    const json = await res.json();
    expect(json.message).toContain("Yêu cầu không hợp lệ.");
  });

  it("calls backend revocation on DELETE and clears cookies", async () => {
    mockCookieStore.get.mockImplementation((name: string) => {
      if (name === OPS_REFRESH_COOKIE)
        return { value: "test-refresh-token-xyz" };
      if (name === OPS_ACCESS_COOKIE) return { value: "test-access-token-abc" };
      return undefined;
    });

    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ success: true, revoked: true }),
    });
    vi.stubGlobal("fetch", fetchMock);

    const req = new Request("http://localhost:3000/api/ops/session", {
      method: "DELETE",
      headers: {
        Origin: "http://localhost:3000",
        Host: "localhost:3000",
      },
    });

    const res = await DELETE(req);
    expect(res.status).toBe(200);

    // Verify backend revocation was called with Authorization header and refreshToken body
    expect(fetchMock).toHaveBeenCalledWith(
      expect.stringContaining("/v1/ops/sessions"),
      expect.objectContaining({
        method: "DELETE",
        headers: expect.objectContaining({
          Authorization: "Bearer test-access-token-abc",
        }),
        body: JSON.stringify({ refreshToken: "test-refresh-token-xyz" }),
      }),
    );

    // Verify response cookies are cleared
    const setCookie = res.headers.get("set-cookie") || "";
    expect(setCookie).toContain(`${OPS_ACCESS_COOKIE}=;`);
    expect(setCookie).toContain(`${OPS_REFRESH_COOKIE}=;`);
  });
});
