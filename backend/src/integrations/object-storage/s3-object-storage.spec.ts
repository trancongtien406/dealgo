import { parseListObjectsV2, S3ObjectStorage } from './s3-object-storage.js';

describe('S3ObjectStorage', () => {
  it('returns null when S3 config is incomplete (fail-closed)', () => {
    expect(
      S3ObjectStorage.tryFromEnv({
        S3_ENDPOINT: 'https://s3.example.com',
        S3_REGION: 'auto',
        S3_BUCKET: 'dealgo',
        S3_ACCESS_KEY_ID: 'key',
      }),
    ).toBeNull();
  });

  it('constructs when all required fields are set', () => {
    const storage = S3ObjectStorage.tryFromEnv({
      S3_ENDPOINT: 'https://s3.example.com',
      S3_REGION: 'auto',
      S3_BUCKET: 'dealgo',
      S3_ACCESS_KEY_ID: 'key',
      S3_SECRET_ACCESS_KEY: 'secret',
    });
    expect(storage).toBeInstanceOf(S3ObjectStorage);
  });

  it('builds a SigV4 presigned GET URL', () => {
    const storage = new S3ObjectStorage({
      endpoint: 'https://s3.example.com',
      region: 'us-east-1',
      bucket: 'dealgo',
      accessKeyId: 'AKIAEXAMPLE',
      secretAccessKey: 'secret',
    });
    const url = storage.createPresignedGetUrl('partner-applications/app-1/0-id.jpg');
    expect(url).toContain('https://s3.example.com/dealgo/partner-applications/');
    expect(url).toContain('X-Amz-Algorithm=AWS4-HMAC-SHA256');
    expect(url).toContain('X-Amz-Signature=');
  });
});

describe('S3ObjectStorage list', () => {
  const page = (keys: string[], next?: string) =>
    `<?xml version="1.0"?><ListBucketResult><IsTruncated>${next ? 'true' : 'false'}</IsTruncated>${keys
      .map((k) => `<Contents><Key>${k}</Key><LastModified>2026-10-01T00:00:00.000Z</LastModified></Contents>`)
      .join('')}${next ? `<NextContinuationToken>${next}</NextContinuationToken>` : ''}</ListBucketResult>`;

  it('parses keys, dates and the continuation token', () => {
    expect(parseListObjectsV2(page(['avatars/u/a.jpg'], 'tok+/='))).toEqual({
      items: [{ key: 'avatars/u/a.jpg', lastModified: new Date('2026-10-01T00:00:00.000Z') }],
      nextToken: 'tok+/=',
    });
    expect(parseListObjectsV2(page([])).nextToken).toBeUndefined();
  });

  it('signs ListObjectsV2 and follows continuation tokens', async () => {
    const storage = new S3ObjectStorage({
      endpoint: 'https://s3.example.com',
      region: 'us-east-1',
      bucket: 'dealgo',
      accessKeyId: 'AKIAEXAMPLE',
      secretAccessKey: 'secret',
    });
    const calls: { url: string; auth: string | undefined }[] = [];
    const original = globalThis.fetch;
    globalThis.fetch = (async (url: string, init?: { headers?: Record<string, string> }) => {
      calls.push({ url, auth: init?.headers?.authorization });
      return new Response(calls.length === 1 ? page(['avatars/u/1.jpg'], 'next+1') : page(['avatars/u/2.jpg']));
    }) as unknown as typeof fetch;
    try {
      const keys = [];
      for await (const item of storage.list('avatars')) keys.push(item.key);
      expect(keys).toEqual(['avatars/u/1.jpg', 'avatars/u/2.jpg']);
    } finally {
      globalThis.fetch = original;
    }
    expect(calls[0]!.url).toBe('https://s3.example.com/dealgo?list-type=2&max-keys=1000&prefix=avatars%2F');
    expect(calls[1]!.url).toContain('continuation-token=next%2B1');
    expect(calls[0]!.auth).toMatch(/^AWS4-HMAC-SHA256 Credential=AKIAEXAMPLE\//);
  });
});
