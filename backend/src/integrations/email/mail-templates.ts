import type { MailSender, PasswordResetCodeMail, SignupCodeMail } from './mail-sender.js';

/** Rendered transactional email. Vietnamese first, English below (users may have either locale). */
export type RenderedMail = { subject: string; text: string };

function minutesUntil(expiresAt: Date): number {
  return Math.max(1, Math.round((expiresAt.getTime() - Date.now()) / 60_000));
}

export function emailVerificationMail(input: { verificationId: string; token: string }): RenderedMail {
  return {
    subject: 'DealGo: mã xác minh email / email verification',
    text: [
      'Mã xác minh email DealGo của bạn:',
      '',
      input.token,
      '',
      '— Verify your DealGo email with this one-time code (above).',
      '',
      `verificationId=${input.verificationId}`,
    ].join('\n'),
  };
}

export function passwordResetMail(input: PasswordResetCodeMail): RenderedMail {
  const minutes = minutesUntil(input.expiresAt);
  return {
    subject: 'DealGo: mã đặt lại mật khẩu / password reset code',
    text: [
      'Mã đặt lại mật khẩu DealGo của bạn:',
      '',
      input.code,
      '',
      `Nhập mã trong ứng dụng DealGo trong ${minutes} phút. Không chia sẻ mã cho bất kỳ ai.`,
      'Nếu bạn không yêu cầu đặt lại mật khẩu, hãy bỏ qua email này; mật khẩu của bạn không thay đổi.',
      '',
      `— Your DealGo password reset code is above. Enter it in the app within ${minutes} minutes. Do not share it with anyone.`,
      'If you did not ask to reset your password, ignore this email; your password is unchanged.',
    ].join('\n'),
  };
}

export function signupCodeMail(input: SignupCodeMail): RenderedMail {
  const activation = input.purpose === 'activation';
  const minutes = minutesUntil(input.expiresAt);
  return {
    subject: activation
      ? 'DealGo: mã xác minh email / email verification code'
      : 'DealGo: mã đăng ký / sign-up code',
    text: [
      activation ? 'Mã xác minh email DealGo của bạn:' : 'Mã đăng ký DealGo của bạn:',
      '',
      input.code,
      '',
      `Mã hết hạn sau ${minutes} phút. Không chia sẻ mã cho bất kỳ ai.`,
      activation
        ? 'Nếu bạn vừa không đăng nhập DealGo, hãy đổi mật khẩu.'
        : 'Nếu bạn không tạo tài khoản DealGo, hãy bỏ qua email này.',
      '',
      `— Your DealGo ${activation ? 'email verification' : 'sign-up'} code is above. It expires in ${minutes} minutes. Do not share it with anyone.`,
      activation
        ? 'If you did not just sign in to DealGo, change your password.'
        : 'If you did not try to create a DealGo account, ignore this email.',
    ].join('\n'),
  };
}

export function signupAccountExistsMail(): RenderedMail {
  return {
    subject: 'DealGo: có người thử đăng ký bằng email này / sign-up attempt',
    text: [
      'Có người vừa thử tạo tài khoản DealGo bằng địa chỉ email này.',
      'Email này đã có tài khoản nên không có tài khoản mới nào được tạo.',
      'Nếu đó là bạn, hãy đăng nhập hoặc đặt lại mật khẩu trong ứng dụng. Nếu không, hãy bỏ qua email này.',
      '',
      '— Someone tried to create a DealGo account with this email. An account already exists, so none was created.',
      'If this was you, sign in or reset your password from the app. If not, ignore this email.',
    ].join('\n'),
  };
}

/** Shared MailSender implementation: subclasses only provide transport (SMTP, SES API, …). */
export abstract class TemplatedMailSender implements MailSender {
  protected abstract transport(to: string, mail: RenderedMail, kind: string): Promise<void>;

  async sendEmailVerification(input: { email: string; verificationId: string; token: string }): Promise<void> {
    await this.transport(input.email, emailVerificationMail(input), 'verification');
  }

  async sendPasswordResetCode(input: PasswordResetCodeMail): Promise<void> {
    await this.transport(input.email, passwordResetMail(input), 'password_reset');
  }

  async sendSignupCode(input: SignupCodeMail): Promise<void> {
    await this.transport(input.email, signupCodeMail(input), input.purpose === 'activation' ? 'activation' : 'signup');
  }

  async sendSignupAccountExists(input: { email: string }): Promise<void> {
    await this.transport(input.email, signupAccountExistsMail(), 'signup_account_exists');
  }
}

/** Mask the local part for logs: "an***@example.com". */
export function redactEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!domain) return '***';
  return `${local.slice(0, 2)}***@${domain}`;
}
