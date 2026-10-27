/**
 * Public origin of a request as the browser sees it.
 *
 * Behind a reverse proxy the Next standalone server builds `request.url` from its own
 * bind address (e.g. `https://0.0.0.0:3000`), not from the Host the browser used. Same-origin
 * checks and absolute redirects must use the forwarded Host instead. Browsers cannot forge
 * Host or Origin on a cross-site request, so this keeps the CSRF checks meaningful.
 */
export function publicRequestOrigin(request: Request): string {
  const url = new URL(request.url);
  const host =
    firstValue(request.headers.get("x-forwarded-host")) ??
    firstValue(request.headers.get("host"));
  if (!host) {
    return url.origin;
  }
  const proto =
    firstValue(request.headers.get("x-forwarded-proto")) ??
    url.protocol.replace(/:$/, "");
  if (proto !== "http" && proto !== "https") {
    return url.origin;
  }
  try {
    return new URL(`${proto}://${host}`).origin;
  } catch {
    return url.origin;
  }
}

function firstValue(value: string | null): string | null {
  const first = value?.split(",")[0]?.trim();
  return first ? first : null;
}
