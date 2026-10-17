/**
 * Resolves the Nest API origin for server-only BFF calls.
 * Prefers DEALGO_API_BASE_URL, then API_BASE_URL, then localhost:3001.
 */
export function nestApiBaseUrl(): string | null {
  const configured =
    process.env.DEALGO_API_BASE_URL?.trim() ||
    process.env.API_BASE_URL?.trim() ||
    "";
  const base = configured.length > 0 ? configured : "http://localhost:3001";
  try {
    const url = new URL(base);
    if (url.protocol !== "http:" && url.protocol !== "https:") {
      return null;
    }
    return url.origin;
  } catch {
    return null;
  }
}
