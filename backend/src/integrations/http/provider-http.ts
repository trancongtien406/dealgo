/**
 * Small fetch wrapper for outbound provider APIs (SMS, email): per-attempt timeout, bounded
 * retries on transport errors / 5xx / 429 only, and no secret material in thrown messages.
 */
export type ProviderHttpRequest = {
  url: string;
  method?: 'GET' | 'POST';
  headers?: Record<string, string>;
  body?: string;
  timeoutMs: number;
  maxAttempts: number;
  /** Base backoff between attempts (ms); doubled each retry. Tests pass 0. */
  backoffMs?: number;
};

export type ProviderHttpResponse = {
  status: number;
  text: string;
  /** 1-based attempt that produced this response. */
  attempt: number;
};

export class ProviderHttpError extends Error {
  constructor(
    message: string,
    readonly kind: 'timeout' | 'network' | 'http',
    readonly status?: number,
  ) {
    super(message);
    this.name = 'ProviderHttpError';
  }
}

export type FetchLike = (input: string, init: RequestInit) => Promise<Response>;

export async function providerHttp(
  request: ProviderHttpRequest,
  fetchImpl: FetchLike = fetch,
): Promise<ProviderHttpResponse> {
  const attempts = Math.max(1, request.maxAttempts);
  let lastError: ProviderHttpError | null = null;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    if (attempt > 1) {
      const delay = (request.backoffMs ?? 250) * 2 ** (attempt - 2);
      if (delay > 0) {
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), request.timeoutMs);
    try {
      const response = await fetchImpl(request.url, {
        method: request.method ?? 'POST',
        headers: request.headers,
        body: request.body,
        signal: controller.signal,
      });
      const text = await response.text();
      if (response.status >= 500 || response.status === 429) {
        lastError = new ProviderHttpError(`provider HTTP ${response.status}`, 'http', response.status);
        continue;
      }
      return { status: response.status, text, attempt };
    } catch (error) {
      const aborted = controller.signal.aborted;
      lastError = new ProviderHttpError(
        aborted ? `provider timeout after ${request.timeoutMs}ms` : `provider network error: ${errorName(error)}`,
        aborted ? 'timeout' : 'network',
      );
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastError ?? new ProviderHttpError('provider request failed', 'network');
}

function errorName(error: unknown): string {
  if (error instanceof Error) {
    const cause = (error as { cause?: { code?: string } }).cause;
    return cause?.code ?? error.name;
  }
  return 'unknown';
}

export function safeJson(text: string): Record<string, unknown> | null {
  try {
    const parsed: unknown = JSON.parse(text);
    return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : null;
  } catch {
    return null;
  }
}
