import { Logger } from '@nestjs/common';
import { connect as tlsConnect } from 'node:tls';
import { connect as netConnect, type Socket } from 'node:net';
import { randomUUID } from 'node:crypto';
import { MailDeliveryError } from './mail-sender.js';
import { redactEmail, TemplatedMailSender, type RenderedMail } from './mail-templates.js';

const DEFAULT_SMTP_TIMEOUT_MS = 10_000;
const RETRY_DELAY_MS = 500;

/**
 * Minimal SMTP client for sign-up codes, email verification and password reset (AUTH LOGIN + STARTTLS).
 * Works with Gmail (smtp.gmail.com:587 + App Password), SES SMTP, Brevo, … Failures are classified
 * (auth_failed / rejected / provider_unavailable); transient ones are retried once.
 */
export class SmtpMailSender extends TemplatedMailSender {
  private readonly logger = new Logger(SmtpMailSender.name);

  constructor(
    private readonly smtpUrl: string,
    private readonly fromAddress: string,
    private readonly timeoutMs: number = DEFAULT_SMTP_TIMEOUT_MS,
    private readonly maxAttempts = 2,
  ) {
    super();
  }

  protected async transport(to: string, mail: RenderedMail, kind: string): Promise<void> {
    for (let attempt = 1; ; attempt += 1) {
      try {
        await sendSmtpMail({
          smtpUrl: this.smtpUrl,
          from: this.fromAddress,
          to,
          subject: mail.subject,
          text: mail.text,
          html: mail.html,
          timeoutMs: this.timeoutMs,
        });
        this.logger.log(`SMTP ${kind} mail sent to ${redactEmail(to)}`);
        return;
      } catch (error) {
        const failure = classifySmtpError(error);
        this.logger.warn({
          msg: 'email.smtp.failed',
          kind,
          to: redactEmail(to),
          reason: failure.reason,
          code: failure.providerCode,
          attempt,
        });
        if (failure.reason !== 'provider_unavailable' || attempt >= this.maxAttempts) {
          throw failure;
        }
        await new Promise((resolve) => setTimeout(resolve, RETRY_DELAY_MS * attempt));
      }
    }
  }
}

export class SmtpReplyError extends Error {
  constructor(
    readonly code: number,
    reply: string,
  ) {
    super(`SMTP ${code}: ${reply.slice(0, 200)}`);
    this.name = 'SmtpReplyError';
  }
}

/** 535/534/530 → bad credentials; other 5xx → permanent reject; 4xx/socket/timeout → transient. */
export function classifySmtpError(error: unknown): MailDeliveryError {
  if (error instanceof MailDeliveryError) return error;
  if (error instanceof SmtpReplyError) {
    const code = String(error.code);
    if (error.code === 535 || error.code === 534 || error.code === 530) {
      return new MailDeliveryError('auth_failed', 'smtp', code);
    }
    if (error.code === 421 || error.code === 450 || error.code === 451 || error.code === 452) {
      return new MailDeliveryError(error.code === 452 ? 'rate_limited' : 'provider_unavailable', 'smtp', code);
    }
    if (error.code >= 500) return new MailDeliveryError('rejected', 'smtp', code);
    return new MailDeliveryError('provider_unavailable', 'smtp', code);
  }
  const code = (error as NodeJS.ErrnoException | undefined)?.code;
  return new MailDeliveryError('provider_unavailable', 'smtp', typeof code === 'string' ? code : undefined);
}

export type SmtpTarget = {
  host: string;
  port: number;
  secure: boolean;
  user?: string;
  password?: string;
};

export async function sendSmtpMail(input: {
  smtpUrl: string;
  from: string;
  to: string;
  subject: string;
  text: string;
  html?: string;
  timeoutMs?: number;
}): Promise<void> {
  const target = parseSmtpUrl(input.smtpUrl);
  const socket = await openSmtpSocket(target, input.timeoutMs ?? DEFAULT_SMTP_TIMEOUT_MS);
  try {
    await expectCode(socket, 220);
    await writeLine(socket, `EHLO dealgo`);
    const ehlo = await readMultiline(socket);
    if (!ehlo.startsWith('250')) {
      throw new SmtpReplyError(Number(ehlo.slice(0, 3)) || 500, ehlo);
    }
    if (!target.secure && ehlo.toLowerCase().includes('starttls')) {
      await writeLine(socket, 'STARTTLS');
      await expectCode(socket, 220);
      const upgraded = await upgradeToTls(socket, target.host, input.timeoutMs ?? DEFAULT_SMTP_TIMEOUT_MS);
      await writeLine(upgraded, `EHLO dealgo`);
      await expectCode(upgraded, 250);
      await authenticate(upgraded, target);
      await deliver(upgraded, input);
      upgraded.end();
      return;
    }
    await authenticate(socket, target);
    await deliver(socket, input);
    socket.end();
  } finally {
    socket.destroy();
  }
}

export function parseSmtpUrl(raw: string): SmtpTarget {
  const url = new URL(raw);
  const secure = url.protocol === 'smtps:';
  const port = url.port ? Number(url.port) : secure ? 465 : 587;
  return {
    host: url.hostname,
    port,
    secure,
    user: url.username ? decodeURIComponent(url.username) : undefined,
    password: url.password ? decodeURIComponent(url.password) : undefined,
  };
}

function openSmtpSocket(target: SmtpTarget, timeoutMs: number): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const socket = target.secure
      ? tlsConnect({ host: target.host, port: target.port, servername: target.host }, () =>
          resolve(socket),
        )
      : netConnect({ host: target.host, port: target.port }, () => resolve(socket));
    socket.setEncoding('utf8');
    armTimeout(socket, timeoutMs);
    socket.once('error', reject);
  });
}

function upgradeToTls(socket: Socket, host: string, timeoutMs: number): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const tlsSocket = tlsConnect({ socket, servername: host }, () => resolve(tlsSocket));
    tlsSocket.setEncoding('utf8');
    armTimeout(tlsSocket, timeoutMs);
    tlsSocket.once('error', reject);
  });
}

/** Idle timeout: a silent server becomes an ETIMEDOUT error instead of a hung request. */
function armTimeout(socket: Socket, timeoutMs: number): void {
  socket.setTimeout(timeoutMs, () => {
    const error = new Error(`SMTP timed out after ${timeoutMs}ms`) as NodeJS.ErrnoException;
    error.code = 'ETIMEDOUT';
    socket.destroy(error);
  });
}

async function authenticate(socket: Socket, target: SmtpTarget): Promise<void> {
  if (!target.user || !target.password) {
    return;
  }
  await writeLine(socket, 'AUTH LOGIN');
  await expectCode(socket, 334);
  await writeLine(socket, Buffer.from(target.user, 'utf8').toString('base64'));
  await expectCode(socket, 334);
  await writeLine(socket, Buffer.from(target.password, 'utf8').toString('base64'));
  await expectCode(socket, 235);
}

async function deliver(
  socket: Socket,
  input: { from: string; to: string; subject: string; text: string; html?: string },
): Promise<void> {
  const fromAddr = extractEmail(input.from);
  await writeLine(socket, `MAIL FROM:<${fromAddr}>`);
  await expectCode(socket, 250);
  await writeLine(socket, `RCPT TO:<${input.to}>`);
  await expectCode(socket, 250);
  await writeLine(socket, 'DATA');
  await expectCode(socket, 354);
  const payload = [...buildMimeMessage(input), '.'].join('\r\n');
  socket.write(`${payload}\r\n`);
  await expectCode(socket, 250);
  await writeLine(socket, 'QUIT');
}

/**
 * RFC 5322 message lines (headers + body, without the SMTP terminating dot). With `html` it is
 * multipart/alternative (text first, HTML preferred); parts are base64 so long HTML lines stay
 * within the 998-octet limit and no body line can start with a dot.
 */
export function buildMimeMessage(input: { from: string; to: string; subject: string; text: string; html?: string }): string[] {
  const headers = [
    `From: ${input.from}`,
    `To: ${input.to}`,
    `Subject: ${encodeHeader(input.subject)}`,
    `Date: ${new Date().toUTCString()}`,
    `Message-ID: <${randomUUID()}@${messageIdDomain(input.from)}>`,
    'MIME-Version: 1.0',
  ];
  if (!input.html) {
    return [
      ...headers,
      'Content-Type: text/plain; charset=utf-8',
      'Content-Transfer-Encoding: base64',
      '',
      ...base64Lines(input.text),
    ];
  }
  const boundary = `dealgo-${randomUUID()}`;
  return [
    ...headers,
    `Content-Type: multipart/alternative; boundary="${boundary}"`,
    '',
    `--${boundary}`,
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    '',
    ...base64Lines(input.text),
    `--${boundary}`,
    'Content-Type: text/html; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    '',
    ...base64Lines(input.html),
    `--${boundary}--`,
  ];
}

function base64Lines(value: string): string[] {
  return Buffer.from(value, 'utf8').toString('base64').match(/.{1,76}/g) ?? [''];
}

function messageIdDomain(from: string): string {
  return extractEmail(from).split('@')[1]?.trim() || 'dealgo.local';
}

/** RFC 2047 encoded-word for non-ASCII headers (Vietnamese subjects). */
export function encodeHeader(value: string): string {
  if (/^[\x20-\x7e]*$/.test(value)) {
    return value;
  }
  // Encoded words stay under 75 chars (RFC 2047 §2): split on code points, fold with CRLF+space.
  const words: string[] = [];
  let chunk = '';
  for (const char of value) {
    if (Buffer.byteLength(chunk + char, 'utf8') > 42) {
      words.push(chunk);
      chunk = '';
    }
    chunk += char;
  }
  if (chunk) words.push(chunk);
  return words.map((word) => `=?UTF-8?B?${Buffer.from(word, 'utf8').toString('base64')}?=`).join('\r\n ');
}

function extractEmail(from: string): string {
  const match = from.match(/<([^>]+)>/);
  return match?.[1]?.trim() || from.trim();
}

function writeLine(socket: Socket, line: string): Promise<void> {
  return new Promise((resolve, reject) => {
    socket.write(`${line}\r\n`, (error) => (error ? reject(error) : resolve()));
  });
}

function expectCode(socket: Socket, code: number): Promise<string> {
  return readMultiline(socket).then((text) => {
    if (!text.startsWith(String(code))) {
      throw new SmtpReplyError(Number(text.slice(0, 3)) || 500, text);
    }
    return text;
  });
}

function readMultiline(socket: Socket): Promise<string> {
  return new Promise((resolve, reject) => {
    let buffer = '';
    const onData = (chunk: string) => {
      buffer += chunk;
      const lines = buffer.split(/\r?\n/).filter((line) => line.length > 0);
      if (lines.length === 0) {
        return;
      }
      const last = lines[lines.length - 1]!;
      if (/^\d{3}-/.test(last)) {
        return;
      }
      if (/^\d{3}[\s]/.test(last) || /^\d{3}$/.test(last)) {
        cleanup();
        resolve(buffer.trim());
      }
    };
    const onError = (error: Error) => {
      cleanup();
      reject(error);
    };
    const cleanup = () => {
      socket.off('data', onData);
      socket.off('error', onError);
    };
    socket.on('data', onData);
    socket.once('error', onError);
  });
}
