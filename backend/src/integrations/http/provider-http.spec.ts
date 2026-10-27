import { describe, expect, it, vi } from 'vitest';
import { ProviderHttpError, providerHttp, safeJson } from './provider-http.js';

const base = { url: 'https://provider.test/send', timeoutMs: 1_000, maxAttempts: 3, backoffMs: 0 };

describe('providerHttp', () => {
  it('returns the first non-retryable response with its attempt number', async () => {
    const fetchImpl = vi.fn(async () => new Response('{"ok":1}', { status: 200 }));
    await expect(providerHttp(base, fetchImpl)).resolves.toEqual({ status: 200, text: '{"ok":1}', attempt: 1 });
  });

  it('retries 5xx/429 and network errors, then succeeds', async () => {
    const fetchImpl = vi
      .fn()
      .mockResolvedValueOnce(new Response('busy', { status: 503 }))
      .mockRejectedValueOnce(new TypeError('fetch failed'))
      .mockResolvedValueOnce(new Response('ok', { status: 200 }));
    const result = await providerHttp(base, fetchImpl);
    expect(result.attempt).toBe(3);
    expect(fetchImpl).toHaveBeenCalledTimes(3);
  });

  it('does not retry 4xx responses', async () => {
    const fetchImpl = vi.fn(async () => new Response('bad', { status: 400 }));
    await expect(providerHttp(base, fetchImpl)).resolves.toMatchObject({ status: 400, attempt: 1 });
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('throws ProviderHttpError with the last status after exhausting attempts', async () => {
    const fetchImpl = vi.fn(async () => new Response('slow down', { status: 429 }));
    await expect(providerHttp({ ...base, maxAttempts: 2 }, fetchImpl)).rejects.toMatchObject({
      name: expect.any(String),
      status: 429,
    });
    await expect(providerHttp({ ...base, maxAttempts: 1 }, fetchImpl)).rejects.toBeInstanceOf(ProviderHttpError);
  });

  it('aborts on timeout', async () => {
    const fetchImpl = vi.fn(
      (_url: string, init: RequestInit) =>
        new Promise<Response>((_resolve, reject) => {
          init.signal?.addEventListener('abort', () => reject(new Error('aborted')));
        }),
    );
    await expect(providerHttp({ ...base, timeoutMs: 10, maxAttempts: 1 }, fetchImpl)).rejects.toThrow(/timeout/);
  });

  it('safeJson tolerates non-JSON bodies', () => {
    expect(safeJson('{"a":1}')).toEqual({ a: 1 });
    expect(safeJson('<html>')).toBeNull();
  });
});
