export const LOCAL_DEV_ORIGINS = ['http://localhost:3000', 'http://localhost:3001'] as const;

export function resolveAllowedOrigins(config?: {
  CORS_ALLOWED_ORIGINS?: string;
  NODE_ENV?: string;
}): string[] {
  const configured = config?.CORS_ALLOWED_ORIGINS;
  if (configured) {
    const list = configured
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);
    if (list.length > 0) {
      return config?.NODE_ENV === 'production'
        ? list
        : Array.from(new Set([...LOCAL_DEV_ORIGINS, ...list]));
    }
  }
  return [...LOCAL_DEV_ORIGINS];
}

export function localDevCors(config?: {
  CORS_ALLOWED_ORIGINS?: string;
  NODE_ENV?: string;
}): {
  origin: string[];
  methods: string[];
  allowedHeaders: string[];
} {
  return {
    origin: resolveAllowedOrigins(config),
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key'],
  };
}
