import { createHash, createHmac } from 'node:crypto';
import type { KycStorage, StoredDocumentRef } from './mock-kyc-storage.js';

export type S3KycConfig = {
  endpoint: string;
  region: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
};

/**
 * S3-compatible KYC object store (AWS S3 / R2 / MinIO).
 * Uploads document bytes with SigV4 when contentBase64 is provided.
 * Fail-closed: construct only when all required fields are present.
 */
export class S3KycStorage implements KycStorage {
  constructor(private readonly config: S3KycConfig) {}

  static tryFromEnv(env: {
    S3_ENDPOINT?: string;
    S3_REGION?: string;
    S3_BUCKET?: string;
    S3_ACCESS_KEY_ID?: string;
    S3_SECRET_ACCESS_KEY?: string;
  }): S3KycStorage | null {
    const endpoint = env.S3_ENDPOINT?.trim();
    const region = env.S3_REGION?.trim();
    const bucket = env.S3_BUCKET?.trim();
    const accessKeyId = env.S3_ACCESS_KEY_ID?.trim();
    const secretAccessKey = env.S3_SECRET_ACCESS_KEY?.trim();
    if (!endpoint || !region || !bucket || !accessKeyId || !secretAccessKey) {
      return null;
    }
    return new S3KycStorage({ endpoint, region, bucket, accessKeyId, secretAccessKey });
  }

  async storeDocuments(
    applicationId: string,
    files: Array<{ label: string; contentType?: string; contentBase64?: string }>,
  ): Promise<StoredDocumentRef[]> {
    const uploadedAt = new Date().toISOString();
    const refs: StoredDocumentRef[] = [];

    for (let index = 0; index < files.length; index += 1) {
      const file = files[index]!;
      const safeLabel = file.label.replace(/[^a-zA-Z0-9._-]+/g, '_').slice(0, 80) || `doc-${index}`;
      const objectKey = `partner-applications/${applicationId}/${index}-${safeLabel}`;
      const contentType = file.contentType?.slice(0, 120) || 'application/octet-stream';
      let sizeBytes = 0;

      if (typeof file.contentBase64 === 'string' && file.contentBase64.length > 0) {
        const body = Buffer.from(file.contentBase64, 'base64');
        sizeBytes = body.byteLength;
        await this.putObject(objectKey, body, contentType);
      }

      refs.push({
        key: `s3://${this.config.bucket}/${objectKey}`,
        label: file.label.slice(0, 160),
        contentType,
        sizeBytes,
        uploadedAt,
      });
    }

    return refs;
  }

  /** Presigned GET URL for ops review downloads (SigV4 query auth). */
  createPresignedGetUrl(objectKey: string, expiresSeconds = 900): string {
    return signS3Request(this.config, {
      method: 'GET',
      objectKey: stripBucketPrefix(objectKey, this.config.bucket),
      expiresSeconds,
      signQuery: true,
    }).url;
  }

  private async putObject(objectKey: string, body: Buffer, contentType: string): Promise<void> {
    const signed = signS3Request(this.config, {
      method: 'PUT',
      objectKey,
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
}

function stripBucketPrefix(keyOrUri: string, bucket: string): string {
  const s3Prefix = `s3://${bucket}/`;
  if (keyOrUri.startsWith(s3Prefix)) {
    return keyOrUri.slice(s3Prefix.length);
  }
  return keyOrUri.replace(/^\/+/, '');
}

type SignInput = {
  method: 'GET' | 'PUT';
  objectKey: string;
  payloadHash?: string;
  contentType?: string;
  expiresSeconds?: number;
  signQuery: boolean;
};

function signS3Request(
  config: S3KycConfig,
  input: SignInput,
): { url: string; headers: Record<string, string> } {
  const endpoint = new URL(config.endpoint);
  const host = endpoint.host;
  const canonicalUri = `/${config.bucket}/${input.objectKey
    .split('/')
    .map(encodeURIComponent)
    .join('/')}`;
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
  const canonicalRequest = [
    input.method,
    canonicalUri,
    '',
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

  return { url: `${endpoint.origin}${canonicalUri}`, headers };
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
