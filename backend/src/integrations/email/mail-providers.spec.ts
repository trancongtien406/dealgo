import { describe, expect, it, vi } from 'vitest';
import { signSigV4 } from './aws-sigv4.js';
import { createMailSender, isMailSenderAvailable, type MailEnv } from './mail-factory.js';
import { MockMailSender } from './mail-sender.js';
import { MailDeliveryError, SesMailSender } from './ses-mail-sender.js';
import { SmtpMailSender } from './smtp-mail-sender.js';

describe('signSigV4', () => {
  it('matches the AWS SigV4 test-suite "get-vanilla" vector', () => {
    const headers = signSigV4({
      method: 'GET',
      host: 'example.amazonaws.com',
      path: '/',
      region: 'us-east-1',
      service: 'service',
      accessKeyId: 'AKIDEXAMPLE',
      secretAccessKey: 'wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY',
      headers: {},
      body: '',
      now: new Date('2015-08-30T12:36:00Z'),
    });
    expect(headers.authorization).toBe(
      'AWS4-HMAC-SHA256 Credential=AKIDEXAMPLE/20150830/us-east-1/service/aws4_request, SignedHeaders=host;x-amz-date, Signature=5fa00fa31553b73ebf1942676e86291e8372ff2a2260956d9b8aae1d763fbf31',
    );
  });
});

describe('SesMailSender', () => {
  const config = { region: 'ap-southeast-1', accessKeyId: 'AKIA', secretAccessKey: 's', from: 'DealGo <a@b.vn>', timeoutMs: 1000, maxAttempts: 1 };
  const mail = { email: 'user@example.com', code: '123456', expiresAt: new Date(Date.now() + 600_000) };

  it('posts a signed SES v2 SendEmail request', async () => {
    const fetchImpl = vi.fn(async (_url: string, _init: RequestInit) => new Response('{"MessageId":"m"}', { status: 200 }));
    await new SesMailSender(config, fetchImpl).sendPasswordResetCode(mail);
    const [url, init] = fetchImpl.mock.calls[0]!;
    expect(url).toBe('https://email.ap-southeast-1.amazonaws.com/v2/email/outbound-emails');
    const headers = init.headers as Record<string, string>;
    expect(headers.authorization).toMatch(/^AWS4-HMAC-SHA256 Credential=AKIA\/\d{8}\/ap-southeast-1\/ses\/aws4_request/);
    const body = JSON.parse(init.body as string);
    expect(body.Destination.ToAddresses).toEqual(['user@example.com']);
    expect(body.Content.Simple.Body.Text.Data).toContain('123456');
  });

  it('classifies SES errors', async () => {
    const reject = (status: number, type: string) =>
      new SesMailSender(config, vi.fn(async () => new Response(JSON.stringify({ __type: type }), { status }))).sendSignupCode(mail);
    await expect(reject(403, 'SignatureDoesNotMatch')).rejects.toMatchObject({ reason: 'auth_failed' });
    await expect(reject(400, 'MessageRejected')).rejects.toMatchObject({ reason: 'rejected' });
    await expect(reject(400, 'LimitExceededException')).rejects.toBeInstanceOf(MailDeliveryError);
  });
});

describe('createMailSender', () => {
  const env = (patch: Partial<MailEnv>): MailEnv => ({ NODE_ENV: 'development', EMAIL_HTTP_TIMEOUT_MS: 1000, ...patch }) as MailEnv;

  it('picks smtp, ses, mock, or unavailable', () => {
    expect(createMailSender(env({}))).toBeInstanceOf(MockMailSender);
    expect(createMailSender(env({ EMAIL_PROVIDER: 'smtp', SMTP_URL: 'smtp://localhost:1025' }))).toBeInstanceOf(SmtpMailSender);
    expect(
      createMailSender(env({ EMAIL_PROVIDER: 'ses', SES_REGION: 'ap-southeast-1', SES_ACCESS_KEY_ID: 'a', SES_SECRET_ACCESS_KEY: 'b' })),
    ).toBeInstanceOf(SesMailSender);
    expect(isMailSenderAvailable(createMailSender(env({ NODE_ENV: 'production' })))).toBe(false);
    expect(isMailSenderAvailable(createMailSender(env({ EMAIL_PROVIDER: 'ses' })))).toBe(false);
  });
});
