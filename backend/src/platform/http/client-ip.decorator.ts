import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export type RequestWithIp = {
  headers?: Record<string, string | string[] | undefined>;
  ip?: string;
  socket?: { remoteAddress?: string };
};

/**
 * Extracts the real client IP address considering Cloudflare, reverse proxies (Nginx),
 * standard X-Forwarded-For headers, Express req.ip, and raw socket remoteAddress.
 */
export function extractClientIp(req: RequestWithIp | undefined | null): string | null {
  if (!req) return null;

  const getHeader = (name: string): string | undefined => {
    const val = req.headers?.[name.toLowerCase()];
    if (Array.isArray(val)) return val[0];
    return val;
  };

  // 1. Cloudflare header (highest priority behind Cloudflare)
  const cfIp = getHeader('cf-connecting-ip');
  if (cfIp && typeof cfIp === 'string' && cfIp.trim()) {
    return cleanIp(cfIp.trim());
  }

  // 2. Nginx / Ingress X-Real-IP
  const xRealIp = getHeader('x-real-ip');
  if (xRealIp && typeof xRealIp === 'string' && xRealIp.trim()) {
    return cleanIp(xRealIp.trim());
  }

  // 3. X-Forwarded-For (the first IP is the original client)
  const xff = getHeader('x-forwarded-for');
  if (xff && typeof xff === 'string' && xff.trim()) {
    const first = xff.split(',')[0]?.trim();
    if (first) return cleanIp(first);
  }

  // 4. Express req.ip (populated when trust proxy is active)
  if (typeof req.ip === 'string' && req.ip.trim()) {
    return cleanIp(req.ip.trim());
  }

  // 5. TCP socket remote address fallback
  if (typeof req.socket?.remoteAddress === 'string' && req.socket.remoteAddress.trim()) {
    return cleanIp(req.socket.remoteAddress.trim());
  }

  return null;
}

function cleanIp(ip: string): string {
  // Strip IPv4-mapped IPv6 prefix e.g. ::ffff:192.168.1.1 -> 192.168.1.1
  if (ip.startsWith('::ffff:')) {
    return ip.slice(7);
  }
  return ip;
}

/**
 * Parameter decorator that injects the real client IP into route handlers.
 */
export const ClientIp = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): string | null => {
    const req = ctx.switchToHttp().getRequest<RequestWithIp>();
    return extractClientIp(req);
  },
);
