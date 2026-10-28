import { Logger } from '@nestjs/common';
import { ProviderHttpError, providerHttp, safeJson, type FetchLike } from '../http/provider-http.js';
import { signSigV4 } from './aws-sigv4.js';
import { MailDeliveryError } from './mail-sender.js';
import { redactEmail, TemplatedMailSender, type RenderedMail } from './mail-templates.js';

export type SesConfig = {
  region: string;
  accessKeyId: string;
  secretAccessKey: string;
  from: string;
  configurationSet?: string;
  timeoutMs: number;
  maxAttempts?: number;
  /** Override for tests / VPC endpoints. */
  endpoint?: string;
};

/**
 * Amazon SES v2 HTTPS API adapter (DEC-PROD-051). POST /v2/email/outbound-emails, SigV4 "ses".
 * Recommended region for VN users: ap-southeast-1 (Singapore).
 */
export class SesMailSender extends TemplatedMailSender {
  private readonly logger = new Logger(SesMailSender.name);

  constructor(
    private readonly config: SesConfig,
    private readonly fetchImpl: FetchLike = fetch,
  ) {
    super();
  }

  protected async transport(to: string, mail: RenderedMail, kind: string): Promise<void> {
    const endpoint = new URL(this.config.endpoint ?? `https://email.${this.config.region}.amazonaws.com`);
    const path = '/v2/email/outbound-emails';
    const body = JSON.stringify({
      FromEmailAddress: this.config.from,
      Destination: { ToAddresses: [to] },
      Content: {
        Simple: {
          Subject: { Data: mail.subject, Charset: 'UTF-8' },
          Body: {
            Text: { Data: mail.text, Charset: 'UTF-8' },
            ...(mail.html ? { Html: { Data: mail.html, Charset: 'UTF-8' } } : {}),
          },
        },
      },
      ...(this.config.configurationSet ? { ConfigurationSetName: this.config.configurationSet } : {}),
      EmailTags: [{ Name: 'kind', Value: kind }],
    });
    const headers = signSigV4({
      method: 'POST',
      host: endpoint.host,
      path,
      region: this.config.region,
      service: 'ses',
      accessKeyId: this.config.accessKeyId,
      secretAccessKey: this.config.secretAccessKey,
      headers: { 'content-type': 'application/json' },
      body,
    });
    delete headers.host;
    let response;
    try {
      response = await providerHttp(
        {
          url: `${endpoint.origin}${path}`,
          method: 'POST',
          headers,
          body,
          timeoutMs: this.config.timeoutMs,
          maxAttempts: this.config.maxAttempts ?? 3,
        },
        this.fetchImpl,
      );
    } catch (error) {
      this.logger.warn({ msg: 'email.ses.transport_failed', to: redactEmail(to), error: (error as Error).message });
      throw new MailDeliveryError(
        error instanceof ProviderHttpError && error.status === 429 ? 'rate_limited' : 'provider_unavailable',
        'ses',
      );
    }
    if (response.status >= 200 && response.status < 300) {
      this.logger.log({ msg: 'email.ses.sent', kind, to: redactEmail(to), messageId: safeJson(response.text)?.MessageId });
      return;
    }
    const json = safeJson(response.text);
    const code = scalarText(json?.__type ?? json?.code, `http_${response.status}`).split('#').pop() ?? '';
    this.logger.warn({ msg: 'email.ses.rejected', kind, to: redactEmail(to), status: response.status, code });
    throw new MailDeliveryError(
      response.status === 403 || /Signature|AccessDenied|InvalidClientToken|UnrecognizedClient/i.test(code)
        ? 'auth_failed'
        : /TooManyRequests|LimitExceeded|Throttl/i.test(code)
          ? 'rate_limited'
          : 'rejected',
      'ses',
      code,
    );
  }
}

/** Provider codes are strings or numbers; anything else falls back. */
function scalarText(value: unknown, fallback: string): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : fallback;
}
