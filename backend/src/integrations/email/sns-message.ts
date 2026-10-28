import { createVerify } from 'node:crypto';

/** Amazon SNS HTTP(S) delivery envelope (SES bounce/complaint notifications arrive this way). */
export type SnsMessage = {
  Type: 'Notification' | 'SubscriptionConfirmation' | 'UnsubscribeConfirmation';
  MessageId: string;
  TopicArn: string;
  Subject?: string;
  Message: string;
  Timestamp: string;
  SignatureVersion: string;
  Signature: string;
  SigningCertURL: string;
  SubscribeURL?: string;
  Token?: string;
};

const SNS_HOST_RE = /^sns\.[a-z0-9-]+\.amazonaws\.com(\.cn)?$/;
/** SNS retries for up to an hour; anything older is treated as a replay. */
const MAX_AGE_MS = 60 * 60 * 1000;

export function parseSnsMessage(body: unknown): SnsMessage | null {
  const value = typeof body === 'string' ? safeParse(body) : body;
  if (!value || typeof value !== 'object') return null;
  const msg = value as Record<string, unknown>;
  const required = ['Type', 'MessageId', 'TopicArn', 'Message', 'Timestamp', 'SignatureVersion', 'Signature', 'SigningCertURL'];
  if (!required.every((key) => typeof msg[key] === 'string')) return null;
  if (!['Notification', 'SubscriptionConfirmation', 'UnsubscribeConfirmation'].includes(msg.Type as string)) return null;
  return msg as unknown as SnsMessage;
}

/** Only HTTPS URLs on sns.<region>.amazonaws.com are fetched (signing cert, subscribe URL). */
export function isSnsUrl(raw: string | undefined): boolean {
  if (!raw) return false;
  try {
    const url = new URL(raw);
    return url.protocol === 'https:' && SNS_HOST_RE.test(url.hostname) && !url.port;
  } catch {
    return false;
  }
}

export function snsStringToSign(msg: SnsMessage): string {
  const keys =
    msg.Type === 'Notification'
      ? ['Message', 'MessageId', ...(msg.Subject !== undefined ? ['Subject'] : []), 'Timestamp', 'TopicArn', 'Type']
      : ['Message', 'MessageId', 'SubscribeURL', 'Timestamp', 'Token', 'TopicArn', 'Type'];
  return keys.map((key) => `${key}\n${str((msg as Record<string, unknown>)[key])}\n`).join('');
}

export type CertFetcher = (url: string) => Promise<string>;

export class SnsSignatureVerifier {
  private readonly certs = new Map<string, string>();

  constructor(private readonly fetchCert: CertFetcher = defaultFetchCert) {}

  async verify(msg: SnsMessage, now = Date.now()): Promise<boolean> {
    if (msg.SignatureVersion !== '1' && msg.SignatureVersion !== '2') return false;
    if (!isSnsUrl(msg.SigningCertURL)) return false;
    const sentAt = Date.parse(msg.Timestamp);
    if (!Number.isFinite(sentAt) || Math.abs(now - sentAt) > MAX_AGE_MS) return false;
    let pem = this.certs.get(msg.SigningCertURL);
    if (!pem) {
      pem = await this.fetchCert(msg.SigningCertURL);
      if (!pem.includes('-----BEGIN ')) return false;
      this.certs.set(msg.SigningCertURL, pem);
    }
    try {
      return createVerify(msg.SignatureVersion === '2' ? 'RSA-SHA256' : 'RSA-SHA1')
        .update(snsStringToSign(msg), 'utf8')
        .verify(pem, msg.Signature, 'base64');
    } catch {
      return false;
    }
  }
}

async function defaultFetchCert(url: string): Promise<string> {
  const response = await fetch(url, { signal: AbortSignal.timeout(5_000) });
  if (!response.ok) throw new Error(`SNS cert HTTP ${response.status}`);
  return response.text();
}

/** SES event → addresses to suppress (permanent bounces and complaints only). */
export function sesSuppressions(
  message: string,
): Array<{ email: string; reason: 'BOUNCE' | 'COMPLAINT'; detail: string }> {
  const event = safeParse(message) as Record<string, any> | null;
  if (!event) return [];
  const type = event.notificationType ?? event.eventType;
  if (type === 'Bounce' && event.bounce?.bounceType === 'Permanent') {
    return list(event.bounce.bouncedRecipients).map((recipient) => ({
      email: str(recipient.emailAddress),
      reason: 'BOUNCE' as const,
      detail: [event.bounce.bounceSubType, recipient.diagnosticCode].filter(Boolean).join(': '),
    }));
  }
  if (type === 'Complaint') {
    return list(event.complaint?.complainedRecipients).map((recipient) => ({
      email: str(recipient.emailAddress),
      reason: 'COMPLAINT' as const,
      detail: str(event.complaint?.complaintFeedbackType) || 'complaint',
    }));
  }
  return [];
}

function list(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value.filter((item) => item && typeof item === 'object') : [];
}

function safeParse(text: string): unknown {
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/** Strings and numbers as-is; anything else (absent, objects) as ''. */
function str(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}
