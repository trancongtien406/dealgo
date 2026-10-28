"use client";

import { useEffect, useState } from "react";
import { apiPaths } from "@/lib/api/paths";

/** Build-time fallback (`NEXT_PUBLIC_MAPBOX_TOKEN`). */
export const BUILD_MAPBOX_TOKEN = process.env.NEXT_PUBLIC_MAPBOX_TOKEN?.trim() || "";

let runtimeToken: Promise<string> | null = null;

/** Mapbox public token set in Admin › Bản đồ, fetched once per page load. "" when none. */
export function loadRuntimeMapboxToken(fetcher: typeof fetch = fetch): Promise<string> {
  runtimeToken ??= fetcher(apiPaths.publicClientConfig(), { credentials: "omit" })
    .then((res) => (res.ok ? (res.json() as Promise<{ mapboxPublicToken?: unknown }>) : {}))
    .then((json) => {
      const token = "mapboxPublicToken" in json ? json.mapboxPublicToken : null;
      return typeof token === "string" && token.startsWith("pk.") ? token : "";
    })
    .catch(() => "");
  return runtimeToken;
}

export function resetRuntimeMapboxTokenForTests() {
  runtimeToken = null;
}

/** Admin token first, build-time token until it loads or when Admin has none. */
export function useMapboxToken(): string {
  const [token, setToken] = useState(BUILD_MAPBOX_TOKEN);
  useEffect(() => {
    let alive = true;
    void loadRuntimeMapboxToken().then((runtime) => {
      if (alive && runtime) setToken(runtime);
    });
    return () => {
      alive = false;
    };
  }, []);
  return token;
}
