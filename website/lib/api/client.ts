import { ApiError, apiErrorFromStatus } from "@/lib/api/errors";

type ApiJson = {
  success?: boolean;
  message?: string;
  data?: unknown;
};

export type ApiRequestInit = Omit<RequestInit, "body"> & {
  body?: unknown;
  signal?: AbortSignal;
  redirectOn401?: boolean;
};

async function readMessage(response: Response): Promise<string> {
  try {
    const json = (await response.clone().json()) as ApiJson;
    if (typeof json.message === "string" && json.message.trim()) {
      return json.message.trim();
    }
  } catch {
    // fall through
  }
  return `Yêu cầu thất bại (${response.status}).`;
}

/**
 * Browser/BFF fetch wrapper. Sends credentials for cookie session routes.
 * Domain list adapters may bypass this while Nest ops APIs are not wired.
 */
export async function apiFetch<T = unknown>(
  path: string,
  init: ApiRequestInit = {},
): Promise<T> {
  const headers = new Headers(init.headers);
  if (init.body !== undefined && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (!headers.has("Accept")) {
    headers.set("Accept", "application/json");
  }

  let response: Response;
  try {
    response = await fetch(path, {
      ...init,
      headers,
      credentials: init.credentials ?? "same-origin",
      body:
        init.body === undefined
          ? undefined
          : typeof init.body === "string"
            ? init.body
            : JSON.stringify(init.body),
    });
  } catch {
    throw new ApiError("Không thể kết nối máy chủ. Thử lại.", {
      code: "NETWORK",
      status: 0,
    });
  }

  if (!response.ok) {
    const shouldRedirect =
      init.redirectOn401 !== false &&
      response.status === 401 &&
      typeof window !== "undefined" &&
      !window.location.pathname.startsWith("/login") &&
      !window.location.pathname.startsWith("/terms") &&
      !window.location.pathname.startsWith("/privacy") &&
      !window.location.pathname.startsWith("/support");

    if (shouldRedirect) {
      // eslint-disable-next-line @next/next/no-location-assign-relative-destination -- Full page redirect to reset auth state
      window.location.assign("/login");
    }
    throw apiErrorFromStatus(response.status, await readMessage(response));
  }

  if (response.status === 204) {
    return undefined as T;
  }

  return (await response.json()) as T;
}
