import { createHash, createHmac } from 'node:crypto';

/** Minimal AWS Signature V4 for JSON APIs (no query string). Avoids pulling the AWS SDK for one call. */
export type SigV4Input = {
  method: string;
  host: string;
  path: string;
  region: string;
  service: string;
  accessKeyId: string;
  secretAccessKey: string;
  sessionToken?: string;
  /** Lower-case header names; host and x-amz-date are added automatically. */
  headers: Record<string, string>;
  body: string;
  now?: Date;
};

const sha256Hex = (value: string) => createHash('sha256').update(value, 'utf8').digest('hex');
const hmac = (key: Buffer | string, value: string) => createHmac('sha256', key).update(value, 'utf8').digest();

export function amzDate(now: Date): string {
  return now.toISOString().replace(/[:-]|\.\d{3}/g, '');
}

/** Returns the headers to send (including Authorization). */
export function signSigV4(input: SigV4Input): Record<string, string> {
  const date = amzDate(input.now ?? new Date());
  const day = date.slice(0, 8);
  const headers: Record<string, string> = {
    ...Object.fromEntries(Object.entries(input.headers).map(([k, v]) => [k.toLowerCase(), v])),
    host: input.host,
    'x-amz-date': date,
  };
  if (input.sessionToken) {
    headers['x-amz-security-token'] = input.sessionToken;
  }
  const names = Object.keys(headers).sort();
  const canonicalHeaders = names.map((name) => `${name}:${headers[name].trim().replace(/\s+/g, ' ')}\n`).join('');
  const signedHeaders = names.join(';');
  const canonicalRequest = [
    input.method.toUpperCase(),
    input.path,
    '',
    canonicalHeaders,
    signedHeaders,
    sha256Hex(input.body),
  ].join('\n');
  const scope = `${day}/${input.region}/${input.service}/aws4_request`;
  const stringToSign = ['AWS4-HMAC-SHA256', date, scope, sha256Hex(canonicalRequest)].join('\n');
  const kDate = hmac(`AWS4${input.secretAccessKey}`, day);
  const kRegion = hmac(kDate, input.region);
  const kService = hmac(kRegion, input.service);
  const kSigning = hmac(kService, 'aws4_request');
  const signature = createHmac('sha256', kSigning).update(stringToSign, 'utf8').digest('hex');
  return {
    ...headers,
    authorization: `AWS4-HMAC-SHA256 Credential=${input.accessKeyId}/${scope}, SignedHeaders=${signedHeaders}, Signature=${signature}`,
  };
}
