import { describe, expect, it, vi } from 'vitest';
import { signSigV4 } from './aws-sigv4.js';
import { effectiveEmailConfig, senderForConfig, type MailEnv } from './email-config.js';
import { isMailSenderAvailable } from './mail-factory.js';
import { MailDeliveryError, MockMailSender } from './mail-sender.js';
import { SesMailSender } from './ses-mail-sender.js';
import { passwordResetMail, signupAccountExistsMail, signupCodeMail, testMail } from './mail-templates.js';
import { buildMimeMessage, encodeHeader, SmtpMailSender } from './smtp-mail-sender.js';

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
    expect(body.Content.Simple.Body.Html.Data).toContain('123456');
    expect(body.Content.Simple.Subject.Data).toBe('Mã đặt lại mật khẩu DealGo: 123456');
  });

  it('classifies SES errors', async () => {
    const reject = (status: number, type: string) =>
      new SesMailSender(config, vi.fn(async () => new Response(JSON.stringify({ __type: type }), { status }))).sendSignupCode(mail);
    await expect(reject(403, 'SignatureDoesNotMatch')).rejects.toMatchObject({ reason: 'auth_failed' });
    await expect(reject(400, 'MessageRejected')).rejects.toMatchObject({ reason: 'rejected' });
    await expect(reject(400, 'LimitExceededException')).rejects.toBeInstanceOf(MailDeliveryError);
  });
});

describe('senderForConfig (env only)', () => {
  const env = (patch: Partial<MailEnv>): MailEnv => ({ NODE_ENV: 'development', EMAIL_HTTP_TIMEOUT_MS: 1000, ...patch }) as MailEnv;
  const sender = (patch: Partial<MailEnv>) => {
    const e = env(patch);
    return senderForConfig(effectiveEmailConfig(e, { config: {}, secrets: {} }), e);
  };

  it('picks smtp, ses, mock, or unavailable', () => {
    expect(sender({})).toBeInstanceOf(MockMailSender);
    expect(sender({ EMAIL_PROVIDER: 'smtp', SMTP_URL: 'smtp://localhost:1025', SMTP_FROM: 'DealGo <a@b.vn>' })).toBeInstanceOf(
      SmtpMailSender,
    );
    expect(
      sender({
        EMAIL_PROVIDER: 'ses',
        SES_REGION: 'ap-southeast-1',
        SES_ACCESS_KEY_ID: 'a',
        SES_SECRET_ACCESS_KEY: 'b',
        EMAIL_FROM: 'a@b.vn',
      }),
    ).toBeInstanceOf(SesMailSender);
    expect(isMailSenderAvailable(sender({ NODE_ENV: 'production' }))).toBe(false);
    expect(isMailSenderAvailable(sender({ EMAIL_PROVIDER: 'ses' }))).toBe(false);
    expect(isMailSenderAvailable(sender({ EMAIL_PROVIDER: 'smtp', SMTP_URL: 'smtp://localhost:1025' }))).toBe(false);
  });
});

describe('mail templates', () => {
  const expiresAt = new Date(Date.now() + 10 * 60_000);

  it('puts the code in the subject, preheader, HTML and text', () => {
    const mail = signupCodeMail({ email: 'a@b.vn', code: '482913', expiresAt });
    expect(mail.subject).toBe('Mã xác thực DealGo: 482913');
    expect(mail.preheader).toContain('482913');
    expect(mail.text).toContain('482913');
    expect(mail.text).toContain('10 phút');
    expect(mail.html).toContain('>482913</span>');
    expect(mail.html).toContain('https://dealgo.laptrinhapp.com/apple-icon.png');
    expect(mail.html).toContain('lang="vi"');
    expect(mail.text).not.toMatch(/<[a-z]/i);
  });

  it('renders every template with a text alternative', () => {
    for (const mail of [
      signupCodeMail({ email: 'a@b.vn', code: '111111', expiresAt, purpose: 'activation' }),
      passwordResetMail({ email: 'a@b.vn', code: '222222', expiresAt }),
      signupAccountExistsMail(),
      testMail(),
    ]) {
      expect(mail.subject.length).toBeGreaterThan(5);
      expect(mail.html).toMatch(/^<!DOCTYPE html>/);
      expect(mail.text).toContain('Đội ngũ DealGo');
    }
  });
});

describe('SMTP MIME', () => {
  it('sends multipart/alternative with base64 parts and folded encoded-word subject', () => {
    const lines = buildMimeMessage({
      from: 'DealGo <no-reply@dealgo.vn>',
      to: 'u@example.com',
      subject: 'Mã xác thực DealGo: 482913 — một tiêu đề khá dài để kiểm tra',
      text: 'Mã: 482913',
      html: '<p>482913</p>',
    });
    const raw = lines.join('\r\n');
    expect(raw).toMatch(/Content-Type: multipart\/alternative; boundary="dealgo-/);
    expect(raw).toContain('Content-Type: text/plain; charset=utf-8');
    expect(raw).toContain('Content-Type: text/html; charset=utf-8');
    expect(raw).toContain(Buffer.from('<p>482913</p>').toString('base64'));
    expect(raw).toMatch(/Message-ID: <[0-9a-f-]+@dealgo\.vn>/);
    expect(lines.every((line) => line.length <= 998 && !line.startsWith('.'))).toBe(true);
    const subject = encodeHeader('Mã xác thực DealGo: 482913 — một tiêu đề khá dài để kiểm tra');
    for (const word of subject.split('\r\n ')) {
      expect(word.length).toBeLessThanOrEqual(75);
    }
    const decoded = subject
      .split('\r\n ')
      .map((w) => Buffer.from(w.slice(10, -2), 'base64').toString('utf8'))
      .join('');
    expect(decoded).toBe('Mã xác thực DealGo: 482913 — một tiêu đề khá dài để kiểm tra');
  });

  it('keeps text-only mail when there is no HTML', () => {
    const raw = buildMimeMessage({ from: 'a@b.vn', to: 'c@d.vn', subject: 'Test', text: 'hello' }).join('\r\n');
    expect(raw).not.toContain('multipart');
    expect(raw).toContain(Buffer.from('hello').toString('base64'));
  });
});
