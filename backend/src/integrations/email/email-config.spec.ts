import { createServer, type Server, type Socket } from 'node:net';
import { afterEach, describe, expect, it } from 'vitest';
import { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import { MemoryIntegrationSettingsRepository } from '../../platform/integration-settings/integration-settings.repository.js';
import { DynamicMailSender, mailSenderStatus } from './dynamic-mail-sender.js';
import {
  buildSmtpUrl,
  effectiveEmailConfig,
  emailConfigured,
  GMAIL_SMTP_HOST,
  parseFromHeader,
  type MailEnv,
} from './email-config.js';
import { MemoryEmailSuppressionRepository } from './email-suppression.repository.js';
import { MailDeliveryError, MockMailSender, UnavailableMailSender } from './mail-sender.js';
import { classifySmtpError, SmtpMailSender, SmtpReplyError } from './smtp-mail-sender.js';

const KEY = Buffer.alloc(32, 7).toString('base64');
const actor = '11111111-1111-1111-1111-111111111111';
const env = (patch: Partial<MailEnv> = {}): MailEnv =>
  ({ NODE_ENV: 'production', EMAIL_HTTP_TIMEOUT_MS: 2000, ...patch }) as MailEnv;
const settingsService = (key: string | undefined = KEY) =>
  new IntegrationSettingsService(new MemoryIntegrationSettingsRepository(), {
    get: (name: string) => (name === 'SECRETS_ENCRYPTION_KEY' ? key : undefined),
  } as never);

describe('effectiveEmailConfig', () => {
  it('defaults to Gmail SMTP fields and disabled provider in production', () => {
    const cfg = effectiveEmailConfig(env(), { config: {}, secrets: {} });
    expect(cfg.provider).toBe('disabled');
    expect(cfg.smtp).toMatchObject({ host: GMAIL_SMTP_HOST, port: 587, secure: false });
    expect(cfg.sources.smtpHost).toBe('default');
    expect(emailConfigured(cfg)).toBe(false);
  });

  it('reads env as bootstrap and lets Admin values override field by field', () => {
    const e = env({ EMAIL_PROVIDER: 'smtp', SMTP_URL: 'smtp://u%40x.vn:p@mail.x.vn:2525', SMTP_FROM: 'Shop <no@x.vn>' });
    const fromEnv = effectiveEmailConfig(e, { config: {}, secrets: {} });
    expect(fromEnv).toMatchObject({ provider: 'smtp', fromName: 'Shop', fromAddress: 'no@x.vn' });
    expect(fromEnv.smtp).toMatchObject({ host: 'mail.x.vn', port: 2525, user: 'u@x.vn', password: 'p' });
    expect(emailConfigured(fromEnv)).toBe(true);

    const admin = effectiveEmailConfig(e, { config: { provider: 'ses', fromAddress: 'hi@x.vn' }, secrets: { sesAccessKeyId: 'AK' } });
    expect(admin.provider).toBe('ses');
    expect(admin.sources).toMatchObject({ provider: 'admin', fromAddress: 'admin', fromName: 'env', sesAccessKeyId: 'admin' });
    expect(emailConfigured(admin)).toBe(false); // secret key missing
  });

  it('never allows mock in production and builds encoded SMTP URLs', () => {
    expect(effectiveEmailConfig(env({ EMAIL_PROVIDER: 'mock' }), { config: {}, secrets: {} }).provider).toBe('disabled');
    expect(parseFromHeader('"DealGo" <a@b.vn>')).toEqual({ name: 'DealGo', address: 'a@b.vn' });
    expect(buildSmtpUrl({ host: 'h', port: 587, user: 'a@b.vn', password: 'p w', secure: false })).toBe(
      'smtp://a%40b.vn:p%20w@h:587',
    );
  });
});

describe('IntegrationSettingsService', () => {
  it('encrypts secrets, audits names only, and clears back to env', async () => {
    const repo = new MemoryIntegrationSettingsRepository();
    const service = new IntegrationSettingsService(repo, { get: () => KEY } as never);
    await service.update('EMAIL', { config: { provider: 'smtp' }, secrets: { smtpPassword: 'app-pass-123' } }, actor, 'setup');
    const row = await repo.find('EMAIL');
    expect(row?.secretsCiphertext).toBeTruthy();
    expect(row?.secretsCiphertext).not.toContain('app-pass-123');
    expect(JSON.stringify(repo.audits)).not.toContain('app-pass-123');
    expect(repo.audits[0]?.metadata).toMatchObject({ secrets: { smtpPassword: 'set' } });
    expect((await service.values('EMAIL')).secrets.smtpPassword).toBe('app-pass-123');

    await service.update('EMAIL', { secrets: { smtpPassword: null } }, actor, 'clear');
    expect((await service.values('EMAIL')).secrets).toEqual({});
    expect(row && (await repo.find('EMAIL'))?.secretsCiphertext).toBeNull();
  });

  it('refuses storing secrets without SECRETS_ENCRYPTION_KEY and rejects unknown fields', async () => {
    const service = settingsService('');
    expect(service.canStoreSecrets()).toBe(false);
    await expect(service.update('EMAIL', { secrets: { smtpPassword: 'x' } }, actor, 'r')).rejects.toMatchObject({
      errorCode: 'SECRETS_ENCRYPTION_KEY_MISSING',
    });
    await service.update('EMAIL', { config: { provider: 'disabled' } }, actor, 'non-secret ok');
    await expect(service.update('EMAIL', { config: { nope: 'x' } }, actor, 'r')).rejects.toMatchObject({
      errorCode: 'VALIDATION_ERROR',
    });
  });
});

describe('DynamicMailSender', () => {
  it('is verified only after a passing test for the exact current config', async () => {
    const settings = settingsService();
    const mail = new DynamicMailSender(
      env({ EMAIL_PROVIDER: 'smtp', SMTP_URL: 'smtp://127.0.0.1:1', SMTP_FROM: 'a@b.vn' }),
      settings,
      new MemoryEmailSuppressionRepository(),
    );
    const before = await mail.status();
    expect(before).toMatchObject({ provider: 'smtp', configured: true, verified: false });
    await settings.recordTest('EMAIL', { ok: true, fingerprint: before.fingerprint, detail: 'ok' }, actor, 'test');
    expect((await mail.status()).verified).toBe(true);
    await settings.update('EMAIL', { config: { smtpHost: 'other.host' } }, actor, 'change');
    expect((await mail.status()).verified).toBe(false);
  });

  it('refuses suppressed recipients', async () => {
    const suppressions = new MemoryEmailSuppressionRepository();
    await suppressions.suppress({ email: 'Bad@X.vn', reason: 'BOUNCE' });
    const mail = new DynamicMailSender(env({ NODE_ENV: 'development' }), settingsService(), suppressions);
    await expect(mail.sendTestEmail({ email: 'bad@x.vn' })).rejects.toMatchObject({ reason: 'suppressed' });
    await expect(mail.sendTestEmail({ email: 'ok@x.vn' })).resolves.toBeUndefined();
  });

  it('reports plain senders by type', async () => {
    expect(await mailSenderStatus(new MockMailSender('test'))).toEqual({ configured: true, verified: true });
    expect(await mailSenderStatus(new UnavailableMailSender())).toEqual({ configured: false, verified: false });
  });
});

describe('SmtpMailSender', () => {
  let server: Server | null = null;
  afterEach(() => server?.close());

  /** Tiny SMTP server: `authReply` decides the AUTH outcome. */
  const startServer = (authReply: string, sink: string[]) =>
    new Promise<number>((resolve) => {
      server = createServer((socket: Socket) => {
        socket.setEncoding('utf8');
        socket.on('error', () => undefined); // the client may reset after a failed AUTH
        socket.write('220 test\r\n');
        let step = '';
        let inData = false;
        socket.on('data', (chunk: string) => {
          for (const line of chunk.split('\r\n').filter((l, i, all) => l || i < all.length - 1)) {
            if (inData) {
              if (line === '.') {
                inData = false;
                socket.write('250 queued\r\n');
              } else sink.push(line);
              continue;
            }
            if (line.startsWith('EHLO')) socket.write('250-test\r\n250 AUTH LOGIN\r\n');
            else if (line === 'AUTH LOGIN') {
              step = 'user';
              socket.write('334 VXNlcm5hbWU6\r\n');
            } else if (step === 'user') {
              step = 'pass';
              socket.write('334 UGFzc3dvcmQ6\r\n');
            } else if (step === 'pass') {
              step = '';
              socket.write(`${authReply}\r\n`);
            } else if (line.startsWith('MAIL FROM') || line.startsWith('RCPT TO')) socket.write('250 ok\r\n');
            else if (line === 'DATA') {
              inData = true;
              socket.write('354 go\r\n');
            } else if (line === 'QUIT') socket.end('221 bye\r\n');
          }
        });
      }).listen(0, '127.0.0.1', () => resolve((server!.address() as { port: number }).port));
    });

  it('delivers a test email over AUTH LOGIN', async () => {
    const sink: string[] = [];
    const port = await startServer('235 ok', sink);
    await new SmtpMailSender(`smtp://u:p@127.0.0.1:${port}`, 'DealGo <a@b.vn>', 2000).sendTestEmail({ email: 'to@x.vn' });
    expect(sink.join('\n')).toContain('To: to@x.vn');
  });

  it('classifies bad credentials without retrying', async () => {
    const port = await startServer('535 5.7.8 BadCredentials', []);
    const error = await new SmtpMailSender(`smtp://u:p@127.0.0.1:${port}`, 'a@b.vn', 2000)
      .sendTestEmail({ email: 'to@x.vn' })
      .catch((e: unknown) => e);
    expect(error).toBeInstanceOf(MailDeliveryError);
    expect(error).toMatchObject({ reason: 'auth_failed', providerCode: '535' });
  });

  it('maps reply codes and socket errors', () => {
    expect(classifySmtpError(new SmtpReplyError(550, 'no'))).toMatchObject({ reason: 'rejected' });
    expect(classifySmtpError(new SmtpReplyError(421, 'busy'))).toMatchObject({ reason: 'provider_unavailable' });
    expect(classifySmtpError(Object.assign(new Error('x'), { code: 'ECONNREFUSED' }))).toMatchObject({
      reason: 'provider_unavailable',
      providerCode: 'ECONNREFUSED',
    });
  });
});
