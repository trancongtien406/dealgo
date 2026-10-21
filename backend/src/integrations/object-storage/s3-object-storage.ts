import { createHash, createHmac } from 'node:crypto';
import type { ListedObject, ObjectStorage, StoredObject } from './object-storage.port.js';
import { assertSafeObjectKey } from './object-storage.port.js';

export type S3ObjectStorageConfig = {
  endpoint: string;
  region: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
};

/**
 * S3-compatible object store (AWS S3 / Cloudflare R2 / MinIO), signed with SigV4.
 * Fail-closed: construct only when every required field is present.
 */
export class S3ObjectStorage implements ObjectStorage {
  readonly provider = 's3' as const;

  constructor(private readonly config: S3ObjectStorageConfig) {}

  static tryFromEnv(env: {
    S3_ENDPOINT?: string;
    S3_REGION?: string;
    S3_BUCKET?: string;
    S3_ACCESS_KEY_ID?: string;
    S3_SECRET_ACCESS_KEY?: string;
  }): S3ObjectStorage | null {
    const endpoint = env.S3_ENDPOINT?.trim();
    const region = env.S3_REGION?.trim();
    const bucket = env.S3_BUCKET?.trim();
    const accessKeyId = env.S3_ACCESS_KEY_ID?.trim();
    const secretAccessKey = env.S3_SECRET_ACCESS_KEY?.trim();
    if (!endpoint || !region || !bucket || !accessKeyId || !secretAccessKey) {
      return null;
    }
    return new S3ObjectStorage({ endpoint, region, bucket, accessKeyId, secretAccessKey });
  }

  async put(key: string, body: Buffer, contentType: string): Promise<void> {
    assertSafeObjectKey(key);
    const signed = signS3Request(this.config, {
      method: 'PUT',
      objectKey: key,
      payloadHash: sha256Hex(body),
      contentType,
      signQuery: false,
    });
    const response = await fetch(signed.url, {
      method: 'PUT',
      headers: {
        ...signed.headers,
        'content-type': contentType,
        'content-length': String(body.byteLength),
      },
      body: new Uint8Array(body),
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) {
      throw new Error(`S3 PUT failed with HTTP ${response.status}`);
    }
  }

  async get(key: string): Promise<StoredObject | null> {
    assertSafeObjectKey(key);
    const response = await fetch(this.createPresignedGetUrl(key, 60), {
      signal: AbortSignal.timeout(30_000),
    });
    if (response.status === 404) {
      return null;
    }
    if (!response.ok) {
      throw new Error(`S3 GET failed with HTTP ${response.status}`);
    }
    return {
      body: Buffer.from(await response.arrayBuffer()),
      contentType: response.headers.get('content-type') ?? 'application/octet-stream',
    };
  }

  async delete(key: string): Promise<void> {
    assertSafeObjectKey(key);
    const signed = signS3Request(this.config, { method: 'DELETE', objectKey: key, signQuery: false });
    const response = await fetch(signed.url, {
      method: 'DELETE',
      headers: signed.headers,
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok && response.status !== 404) {
      throw new Error(`S3 DELETE failed with HTTP ${response.status}`);
    }
  }

  /** ListObjectsV2 under `prefix/`, following continuation tokens. */
  async *list(prefix: string): AsyncIterable<ListedObject> {
    assertSafeObjectKey(prefix);
    let continuation: string | undefined;
    do {
      const query: Record<string, string> = { 'list-type': '2', prefix: `${prefix}/`, 'max-keys': '1000' };
      if (continuation) {
        query['continuation-token'] = continuation;
      }
      const signed = signS3Request(this.config, { method: 'GET', objectKey: '', query, signQuery: false });
      const response = await fetch(signed.url, {
        headers: signed.headers,
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) {
        throw new Error(`S3 LIST failed with HTTP ${response.status}`);
      }
      const page = parseListObjectsV2(await response.text());
      for (const item of page.items) {
        yield item;
      }
      continuation = page.nextToken;
    } while (continuation);
  }

  /** Presigned GET URL (SigV4 query auth). */
  createPresignedGetUrl(objectKey: string, expiresSeconds = 900): string {
    return signS3Request(this.config, {
      method: 'GET',
      objectKey: stripBucketPrefix(objectKey, this.config.bucket),
      expiresSeconds,
      signQuery: true,
    }).url;
  }
}

function stripBucketPrefix(keyOrUri: string, bucket: string): string {
  const s3Prefix = `s3://${bucket}/`;
  if (keyOrUri.startsWith(s3Prefix)) {
    return keyOrUri.slice(s3Prefix.length);
  }
  return keyOrUri.replace(/^\/+/, '');
}

/** Parses a ListObjectsV2 XML page (keys are restricted to safe characters by assertSafeObjectKey). */
export function parseListObjectsV2(xml: string): { items: ListedObject[]; nextToken?: string } {
  const items: ListedObject[] = [];
  for (const match of xml.matchAll(/<Contents>([\s\S]*?)<\/Contents>/g)) {
    const body = match[1]!;
    const key = /<Key>([\s\S]*?)<\/Key>/.exec(body)?.[1];
    const modified = /<LastModified>([\s\S]*?)<\/LastModified>/.exec(body)?.[1];
    const at = modified ? new Date(modified) : null;
    if (key && at && !Number.isNaN(at.getTime())) {
      items.push({ key: decodeXml(key), lastModified: at });
    }
  }
  const truncated = /<IsTruncated>\s*true\s*<\/IsTruncated>/.test(xml);
  const token = /<NextContinuationToken>([\s\S]*?)<\/NextContinuationToken>/.exec(xml)?.[1];
  return truncated && token ? { items, nextToken: decodeXml(token) } : { items };
}

function decodeXml(value: string): string {
  return value
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&amp;/g, '&');
}

/** RFC 3986 encoding as SigV4 requires (encodeURIComponent leaves !'()* alone). */
function encodeRfc3986(value: string): string {
  return encodeURIComponent(value).replace(/[!'()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
}

type SignInput = {
  method: 'GET' | 'PUT' | 'DELETE';
  objectKey: string;
  /** Extra query parameters signed with header auth (e.g. ListObjectsV2). */
  query?: Record<string, string>;
  payloadHash?: string;
  contentType?: string;
  expiresSeconds?: number;
  signQuery: boolean;
};

function signS3Request(
  config: S3ObjectStorageConfig,
  input: SignInput,
): { url: string; headers: Record<string, string> } {
  const endpoint = new URL(config.endpoint);
  const host = endpoint.host;
  const canonicalUri = input.objectKey
    ? `/${config.bucket}/${input.objectKey.split('/').map(encodeURIComponent).join('/')}`
    : `/${config.bucket}`;
  const now = new Date();
  const amzDate = toAmzDate(now);
  const dateStamp = amzDate.slice(0, 8);
  const service = 's3';
  const algorithm = 'AWS4-HMAC-SHA256';
  const credentialScope = `${dateStamp}/${config.region}/${service}/aws4_request`;
  const payloadHash =
    input.payloadHash ?? (input.method === 'GET' ? 'UNSIGNED-PAYLOAD' : sha256Hex(Buffer.alloc(0)));

  if (input.signQuery) {
    const expires = String(input.expiresSeconds ?? 900);
    const query = new URLSearchParams({
      'X-Amz-Algorithm': algorithm,
      'X-Amz-Credential': `${config.accessKeyId}/${credentialScope}`,
      'X-Amz-Date': amzDate,
      'X-Amz-Expires': expires,
      'X-Amz-SignedHeaders': 'host',
    });
    const canonicalQuery = [...query.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
      .join('&');
    const canonicalHeaders = `host:${host}\n`;
    const signedHeaders = 'host';
    const canonicalRequest = [
      input.method,
      canonicalUri,
      canonicalQuery,
      canonicalHeaders,
      signedHeaders,
      payloadHash,
    ].join('\n');
    const stringToSign = [
      algorithm,
      amzDate,
      credentialScope,
      sha256Hex(Buffer.from(canonicalRequest, 'utf8')),
    ].join('\n');
    const signature = hmacHex(
      signingKey(config.secretAccessKey, dateStamp, config.region, service),
      stringToSign,
    );
    query.set('X-Amz-Signature', signature);
    const url = `${endpoint.origin}${canonicalUri}?${query.toString()}`;
    return { url, headers: {} };
  }

  const headers: Record<string, string> = {
    host,
    'x-amz-content-sha256': payloadHash,
    'x-amz-date': amzDate,
  };
  if (input.contentType) {
    headers['content-type'] = input.contentType;
  }
  const signedHeaderNames = Object.keys(headers)
    .map((h) => h.toLowerCase())
    .sort();
  const canonicalHeaders = signedHeaderNames
    .map((name) => `${name}:${headers[name]!.trim()}\n`)
    .join('');
  const signedHeaders = signedHeaderNames.join(';');
  const headerQuery = Object.entries(input.query ?? {})
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${encodeRfc3986(k)}=${encodeRfc3986(v)}`)
    .join('&');
  const canonicalRequest = [
    input.method,
    canonicalUri,
    headerQuery,
    canonicalHeaders,
    signedHeaders,
    payloadHash,
  ].join('\n');
  const stringToSign = [
    algorithm,
    amzDate,
    credentialScope,
    sha256Hex(Buffer.from(canonicalRequest, 'utf8')),
  ].join('\n');
  const signature = hmacHex(
    signingKey(config.secretAccessKey, dateStamp, config.region, service),
    stringToSign,
  );
  headers.authorization = `${algorithm} Credential=${config.accessKeyId}/${credentialScope}, SignedHeaders=${signedHeaders}, Signature=${signature}`;

  return { url: `${endpoint.origin}${canonicalUri}${headerQuery ? `?${headerQuery}` : ''}`, headers };
}

function signingKey(secret: string, dateStamp: string, region: string, service: string): Buffer {
  const kDate = hmac(`AWS4${secret}`, dateStamp);
  const kRegion = hmac(kDate, region);
  const kService = hmac(kRegion, service);
  return hmac(kService, 'aws4_request');
}

function hmac(key: string | Buffer, data: string): Buffer {
  return createHmac('sha256', key).update(data, 'utf8').digest();
}

function hmacHex(key: Buffer, data: string): string {
  return createHmac('sha256', key).update(data, 'utf8').digest('hex');
}

function sha256Hex(data: Buffer | string): string {
  return createHash('sha256').update(data).digest('hex');
}

function toAmzDate(date: Date): string {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}
