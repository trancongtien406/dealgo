import { Logger } from '@nestjs/common';
import { connect as tlsConnect } from 'node:tls';
import { connect as netConnect, type Socket } from 'node:net';
import { redactEmail, TemplatedMailSender, type RenderedMail } from './mail-templates.js';

/**
 * Minimal SMTP client for sign-up codes, email verification and password reset (AUTH LOGIN + STARTTLS).
 * Prefer SMTP_URL; discrete SMTP_* vars are folded into SMTP_URL in env aliases.
 */
export class SmtpMailSender extends TemplatedMailSender {
  private readonly logger = new Logger(SmtpMailSender.name);

  constructor(
    private readonly smtpUrl: string,
    private readonly fromAddress: string,
  ) {
    super();
  }

  protected async transport(to: string, mail: RenderedMail, kind: string): Promise<void> {
    await sendSmtpMail({ smtpUrl: this.smtpUrl, from: this.fromAddress, to, subject: mail.subject, text: mail.text });
    this.logger.log(`SMTP ${kind} mail sent to ${redactEmail(to)}`);
  }
}

type SmtpTarget = {
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
}): Promise<void> {
  const target = parseSmtpUrl(input.smtpUrl);
  const socket = await openSmtpSocket(target);
  try {
    await expectCode(socket, 220);
    await writeLine(socket, `EHLO dealgo`);
    const ehlo = await readMultiline(socket);
    if (!ehlo.startsWith('250')) {
      throw new Error(`SMTP EHLO failed: ${ehlo}`);
    }
    if (!target.secure && ehlo.toLowerCase().includes('starttls')) {
      await writeLine(socket, 'STARTTLS');
      await expectCode(socket, 220);
      const upgraded = await upgradeToTls(socket, target.host);
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

function parseSmtpUrl(raw: string): SmtpTarget {
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

function openSmtpSocket(target: SmtpTarget): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const socket = target.secure
      ? tlsConnect({ host: target.host, port: target.port, servername: target.host }, () =>
          resolve(socket),
        )
      : netConnect({ host: target.host, port: target.port }, () => resolve(socket));
    socket.setEncoding('utf8');
    socket.once('error', reject);
  });
}

function upgradeToTls(socket: Socket, host: string): Promise<Socket> {
  return new Promise((resolve, reject) => {
    const tlsSocket = tlsConnect({ socket, servername: host }, () => resolve(tlsSocket));
    tlsSocket.setEncoding('utf8');
    tlsSocket.once('error', reject);
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
  input: { from: string; to: string; subject: string; text: string },
): Promise<void> {
  const fromAddr = extractEmail(input.from);
  await writeLine(socket, `MAIL FROM:<${fromAddr}>`);
  await expectCode(socket, 250);
  await writeLine(socket, `RCPT TO:<${input.to}>`);
  await expectCode(socket, 250);
  await writeLine(socket, 'DATA');
  await expectCode(socket, 354);
  const payload = [
    `From: ${input.from}`,
    `To: ${input.to}`,
    `Subject: ${encodeHeader(input.subject)}`,
    `Date: ${new Date().toUTCString()}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: 8bit',
    '',
    input.text.replace(/^\./gm, '..'),
    '.',
  ].join('\r\n');
  socket.write(`${payload}\r\n`);
  await expectCode(socket, 250);
  await writeLine(socket, 'QUIT');
}

/** RFC 2047 encoded-word for non-ASCII headers (Vietnamese subjects). */
export function encodeHeader(value: string): string {
  return /^[\x20-\x7e]*$/.test(value) ? value : `=?UTF-8?B?${Buffer.from(value, 'utf8').toString('base64')}?=`;
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
      throw new Error(`SMTP expected ${code}, got: ${text}`);
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
