import { Logger } from '@nestjs/common';
import { connect as tlsConnect } from 'node:tls';
import { connect as netConnect, type Socket } from 'node:net';
import type { MailSender, PasswordResetCodeMail, SignupCodeMail } from './mail-sender.js';

/**
 * Minimal SMTP client for sign-up codes, email verification and password reset (AUTH LOGIN + STARTTLS).
 * Prefer SMTP_URL; discrete SMTP_* vars are folded into SMTP_URL in env aliases.
 */
export class SmtpMailSender implements MailSender {
  private readonly logger = new Logger(SmtpMailSender.name);

  constructor(
    private readonly smtpUrl: string,
    private readonly fromAddress: string,
  ) {}

  async sendEmailVerification(input: {
    email: string;
    verificationId: string;
    token: string;
  }): Promise<void> {
    const subject = 'DealGo email verification';
    const body = [
      'Verify your DealGo email with this one-time code:',
      '',
      input.token,
      '',
      `verificationId=${input.verificationId}`,
    ].join('\n');
    await sendSmtpMail({
      smtpUrl: this.smtpUrl,
      from: this.fromAddress,
      to: input.email,
      subject,
      text: body,
    });
    this.logger.log(`SMTP verification sent to ${input.email}`);
  }

  async sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void> {
    const minutes = Math.max(1, Math.round((input.expiresAt.getTime() - Date.now()) / 60_000));
    const body = [
      'Your DealGo password reset code is:',
      '',
      input.code,
      '',
      `Enter it in the DealGo app within ${minutes} minutes. Do not share it with anyone.`,
      'If you did not ask to reset your password, ignore this email; your password is unchanged.',
    ].join('\n');
    await sendSmtpMail({
      smtpUrl: this.smtpUrl,
      from: this.fromAddress,
      to: input.email,
      subject: 'DealGo password reset code',
      text: body,
    });
    this.logger.log(`SMTP password reset code sent to ${input.email}`);
  }

  async sendSignupCode(input: SignupCodeMail): Promise<void> {
    const activation = input.purpose === 'activation';
    const minutes = Math.max(1, Math.round((input.expiresAt.getTime() - Date.now()) / 60_000));
    const body = [
      activation ? 'Your DealGo email verification code is:' : 'Your DealGo sign-up code is:',
      '',
      input.code,
      '',
      `It expires in ${minutes} minutes. Do not share it with anyone.`,
      activation
        ? 'If you did not just sign in to DealGo, change your password.'
        : 'If you did not try to create a DealGo account, ignore this email.',
    ].join('\n');
    await sendSmtpMail({
      smtpUrl: this.smtpUrl,
      from: this.fromAddress,
      to: input.email,
      subject: activation ? 'DealGo email verification code' : 'DealGo sign-up code',
      text: body,
    });
    this.logger.log(`SMTP ${activation ? 'activation' : 'signup'} code sent to ${input.email}`);
  }

  async sendSignupAccountExists(input: { email: string }): Promise<void> {
    const body = [
      'Someone tried to create a DealGo account with this email address.',
      'An account already exists for it, so no new account was created.',
      '',
      'If this was you, sign in or reset your password from the app.',
      'If not, you can ignore this email.',
    ].join('\n');
    await sendSmtpMail({
      smtpUrl: this.smtpUrl,
      from: this.fromAddress,
      to: input.email,
      subject: 'DealGo sign-up attempt',
      text: body,
    });
    this.logger.log(`SMTP signup account-exists notice sent to ${input.email}`);
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
    `Subject: ${input.subject}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    '',
    input.text.replace(/^\./gm, '..'),
    '.',
  ].join('\r\n');
  socket.write(`${payload}\r\n`);
  await expectCode(socket, 250);
  await writeLine(socket, 'QUIT');
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
