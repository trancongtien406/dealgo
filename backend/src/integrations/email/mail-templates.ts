import type {
  EmailVerificationCodeMail,
  MailSender,
  PasswordResetCodeMail,
  PolicyUpdateMail,
  SignupCodeMail,
} from './mail-sender.js';

/**
 * Rendered transactional email: Vietnamese copy, one branded table layout (Gmail, Apple Mail,
 * Outlook), with a plain-text alternative. `html` is optional so a transport may send text only.
 */
export type RenderedMail = { subject: string; text: string; html?: string; preheader?: string };

/** Public brand assets served by the admin web (PNG: Gmail and Outlook drop SVG). */
export const MAIL_BRAND = {
  name: 'DealGo',
  tagline: 'Đi xe & giao đồ ăn',
  logoUrl: 'https://dealgo.laptrinhapp.com/apple-icon.png',
  siteUrl: 'https://dealgo.laptrinhapp.com',
  supportUrl: 'https://dealgo.laptrinhapp.com/support',
  termsUrl: 'https://dealgo.laptrinhapp.com/terms',
  privacyUrl: 'https://dealgo.laptrinhapp.com/privacy',
  purple: '#6D28D9',
  purpleDark: '#4C1D95',
  green: '#10B956',
} as const;

function minutesUntil(expiresAt: Date): number {
  return Math.max(1, Math.round((expiresAt.getTime() - Date.now()) / 60_000));
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** One paragraph of body copy (plain text in, escaped HTML out; **x** marks bold). */
type Block =
  | { kind: 'p'; text: string }
  | { kind: 'code'; code: string; caption: string }
  | { kind: 'note'; text: string }
  | { kind: 'button'; label: string; url: string };

type Layout = {
  subject: string;
  preheader: string;
  heading: string;
  blocks: Block[];
  /** Small grey line under the card (why the user got this email). */
  reason: string;
};

function inline(text: string): string {
  return escapeHtml(text).replace(/\*\*(.+?)\*\*/g, '<strong style="color:#0F172A;">$1</strong>');
}

function plain(text: string): string {
  return text.replace(/\*\*(.+?)\*\*/g, '$1');
}

const FONT = "'Be Vietnam Pro',-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif";
const MONO = "'SF Mono',SFMono-Regular,Menlo,Consolas,'Liberation Mono','Courier New',monospace";

function blockHtml(block: Block): string {
  switch (block.kind) {
    case 'p':
      return `<tr><td style="padding:0 0 16px 0;font-family:${FONT};font-size:15px;line-height:24px;color:#334155;">${inline(block.text)}</td></tr>`;
    case 'code': {
      // Digits in one text node (no per-digit cells) so copy, Apple Mail and iOS code
      // suggestions read the exact code; letter-spacing only spaces it visually.
      const code = escapeHtml(block.code);
      // Anything longer than a short code gets a small, wrapping style; 6-digit codes the big one.
      const long = block.code.length > 8;
      const codeStyle = long
        ? `font-family:${MONO};font-size:15px;line-height:22px;font-weight:600;letter-spacing:0;word-break:break-all;color:${MAIL_BRAND.purpleDark};`
        : `font-family:${MONO};font-size:36px;line-height:44px;font-weight:700;letter-spacing:10px;padding-left:10px;color:${MAIL_BRAND.purpleDark};mso-line-height-rule:exactly;`;
      return `<tr><td style="padding:4px 0 20px 0;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-collapse:separate;">
<tr><td align="center" bgcolor="#F5F3FF" style="background-color:#F5F3FF;border:1px solid #DDD6FE;border-radius:14px;padding:22px 12px 18px 12px;">
<div class="${long ? '' : 'dg-code'}" style="${codeStyle}"><span style="color:${MAIL_BRAND.purpleDark};text-decoration:none;">${code}</span></div>
<div style="padding-top:8px;font-family:${FONT};font-size:13px;line-height:20px;color:#6B7280;">${inline(block.caption)}</div>
</td></tr></table></td></tr>`;
    }
    case 'note':
      return `<tr><td style="padding:0 0 16px 0;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td bgcolor="#FFF7ED" style="background-color:#FFF7ED;border-left:3px solid #F59E0B;border-radius:8px;padding:12px 14px;font-family:${FONT};font-size:13px;line-height:20px;color:#7C2D12;">${inline(block.text)}</td></tr>
</table></td></tr>`;
    case 'button':
      return `<tr><td style="padding:4px 0 20px 0;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
<td align="center" bgcolor="${MAIL_BRAND.purple}" style="border-radius:12px;background-color:${MAIL_BRAND.purple};">
<a href="${escapeHtml(block.url)}" target="_blank" style="display:inline-block;padding:13px 24px;font-family:${FONT};font-size:15px;font-weight:700;line-height:20px;color:#FFFFFF;text-decoration:none;border-radius:12px;">${escapeHtml(block.label)}</a>
</td></tr></table></td></tr>`;
  }
}

function blockText(block: Block): string {
  switch (block.kind) {
    case 'p':
      return plain(block.text);
    case 'code':
      return `    ${block.code}\n\n${plain(block.caption)}`;
    case 'note':
      return plain(block.text);
    case 'button':
      return `${block.label}: ${block.url}`;
  }
}

function renderHtml(layout: Layout): string {
  const b = MAIL_BRAND;
  const year = new Date().getFullYear();
  // Preheader: inbox preview text, then filler so clients do not pull body copy into it.
  const filler = '&#847;&zwnj;&nbsp;'.repeat(60);
  return `<!DOCTYPE html>
<html lang="vi" xmlns="http://www.w3.org/1999/xhtml" xmlns:v="urn:schemas-microsoft-com:vml" xmlns:o="urn:schemas-microsoft-com:office:office">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta http-equiv="X-UA-Compatible" content="IE=edge">
<meta name="x-apple-disable-message-reformatting">
<meta name="format-detection" content="telephone=no,date=no,address=no,email=no">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(layout.subject)}</title>
<!--[if mso]><noscript><xml><o:OfficeDocumentSettings><o:PixelsPerInch>96</o:PixelsPerInch></o:OfficeDocumentSettings></xml></noscript><![endif]-->
<style>
  body,table,td,a{-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;}
  table,td{mso-table-lspace:0pt;mso-table-rspace:0pt;}
  img{-ms-interpolation-mode:bicubic;border:0;outline:none;text-decoration:none;}
  a[x-apple-data-detectors]{color:inherit!important;text-decoration:none!important;}
  u + #body a{color:inherit;text-decoration:none;}
  @media only screen and (max-width:620px){
    .dg-container{width:100%!important;}
    .dg-pad{padding-left:20px!important;padding-right:20px!important;}
    .dg-outer{padding:12px 8px!important;}
    .dg-code{font-size:30px!important;letter-spacing:7px!important;padding-left:7px!important;}
    .dg-h1{font-size:21px!important;line-height:28px!important;}
  }
</style>
</head>
<body id="body" style="margin:0;padding:0;width:100%;background-color:#F4F1FA;">
<div style="display:none;max-height:0;max-width:0;overflow:hidden;opacity:0;mso-hide:all;font-size:1px;line-height:1px;color:#F4F1FA;">${escapeHtml(layout.preheader)}${filler}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#F4F1FA" style="background-color:#F4F1FA;">
<tr><td align="center" class="dg-outer" style="padding:32px 16px;">
<!--[if mso]><table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0"><tr><td><![endif]-->
<table role="presentation" class="dg-container" width="560" cellpadding="0" cellspacing="0" border="0" style="width:560px;max-width:560px;">
<tr><td style="padding:0 4px 18px 4px;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr>
<td style="vertical-align:middle;"><a href="${b.siteUrl}" target="_blank" style="text-decoration:none;"><img src="${b.logoUrl}" width="40" height="40" alt="DealGo" style="display:block;width:40px;height:40px;border-radius:10px;"></a></td>
<td style="vertical-align:middle;padding-left:10px;font-family:${FONT};font-size:22px;line-height:28px;font-weight:800;letter-spacing:-0.5px;"><span style="color:${b.purple};">Deal</span><span style="color:${b.green};">Go</span></td>
</tr></table>
</td></tr>
<tr><td bgcolor="#FFFFFF" class="dg-pad" style="background-color:#FFFFFF;border-radius:20px;border:1px solid #ECE7F6;padding:32px 36px 16px 36px;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
<tr><td class="dg-h1" style="padding:0 0 12px 0;font-family:${FONT};font-size:23px;line-height:30px;font-weight:800;color:#0F172A;">${escapeHtml(layout.heading)}</td></tr>
${layout.blocks.map(blockHtml).join('\n')}
<tr><td style="padding:4px 0 16px 0;font-family:${FONT};font-size:14px;line-height:22px;color:#334155;">Trân trọng,<br><strong style="color:#0F172A;">Đội ngũ DealGo</strong></td></tr>
</table>
</td></tr>
<tr><td class="dg-pad" style="padding:20px 24px 8px 24px;font-family:${FONT};font-size:12px;line-height:19px;color:#6B7280;text-align:center;">
${escapeHtml(layout.reason)}<br>
Cần hỗ trợ? <a href="${b.supportUrl}" target="_blank" style="color:${b.purple};text-decoration:underline;">Trung tâm hỗ trợ DealGo</a>
</td></tr>
<tr><td style="padding:4px 24px 0 24px;font-family:${FONT};font-size:12px;line-height:19px;color:#9CA3AF;text-align:center;">
<a href="${b.termsUrl}" target="_blank" style="color:#6B7280;text-decoration:none;">Điều khoản</a>&nbsp;&nbsp;·&nbsp;&nbsp;<a href="${b.privacyUrl}" target="_blank" style="color:#6B7280;text-decoration:none;">Quyền riêng tư</a><br>
© ${year} DealGo · ${escapeHtml(b.tagline)} · Email tự động, vui lòng không trả lời.
</td></tr>
</table>
<!--[if mso]></td></tr></table><![endif]-->
</td></tr>
</table>
</body>
</html>`;
}

function renderText(layout: Layout): string {
  const b = MAIL_BRAND;
  return [
    layout.heading,
    '',
    ...layout.blocks.flatMap((block) => [blockText(block), '']),
    'Trân trọng,',
    'Đội ngũ DealGo',
    '',
    '—',
    layout.reason,
    `Hỗ trợ: ${b.supportUrl}`,
    `© ${new Date().getFullYear()} DealGo · ${b.tagline}. Email tự động, vui lòng không trả lời.`,
  ].join('\n');
}

function render(layout: Layout): RenderedMail {
  return { subject: layout.subject, preheader: layout.preheader, text: renderText(layout), html: renderHtml(layout) };
}

const NO_SHARE = '**Không chia sẻ mã này** với bất kỳ ai, kể cả người tự xưng là nhân viên DealGo. DealGo không bao giờ hỏi mã qua điện thoại hay tin nhắn.';

export function emailVerificationMail(input: Omit<EmailVerificationCodeMail, 'email'>): RenderedMail {
  const minutes = minutesUntil(input.expiresAt);
  return render({
    subject: `Mã xác minh email DealGo: ${input.code}`,
    preheader: `${input.code} là mã xác minh email của bạn. Mã hết hạn sau ${minutes} phút.`,
    heading: 'Xác minh email của bạn',
    blocks: [
      { kind: 'p', text: 'Nhập mã sau trong ứng dụng DealGo để xác minh địa chỉ email cho tài khoản của bạn:' },
      { kind: 'code', code: input.code, caption: `Mã có hiệu lực trong **${minutes} phút**.` },
      { kind: 'note', text: NO_SHARE },
      { kind: 'p', text: 'Nếu bạn không thêm email này vào tài khoản DealGo, hãy bỏ qua email này.' },
    ],
    reason: 'Bạn nhận được email này vì địa chỉ này vừa được thêm vào một tài khoản DealGo.',
  });
}

export function passwordResetMail(input: PasswordResetCodeMail): RenderedMail {
  const minutes = minutesUntil(input.expiresAt);
  return render({
    subject: `Mã đặt lại mật khẩu DealGo: ${input.code}`,
    preheader: `${input.code} là mã đặt lại mật khẩu của bạn. Mã hết hạn sau ${minutes} phút.`,
    heading: 'Đặt lại mật khẩu',
    blocks: [
      { kind: 'p', text: 'Chúng tôi nhận được yêu cầu đặt lại mật khẩu cho tài khoản DealGo của bạn. Nhập mã sau trong ứng dụng:' },
      { kind: 'code', code: input.code, caption: `Mã có hiệu lực trong **${minutes} phút**.` },
      { kind: 'note', text: NO_SHARE },
      { kind: 'p', text: 'Nếu bạn không yêu cầu, hãy bỏ qua email này. Mật khẩu của bạn sẽ không thay đổi.' },
    ],
    reason: 'Bạn nhận được email này vì có yêu cầu đặt lại mật khẩu cho tài khoản DealGo dùng địa chỉ này.',
  });
}

export function signupCodeMail(input: SignupCodeMail): RenderedMail {
  const activation = input.purpose === 'activation';
  const minutes = minutesUntil(input.expiresAt);
  return render({
    subject: `Mã xác thực DealGo: ${input.code}`,
    preheader: `${input.code} là mã xác thực email của bạn. Mã hết hạn sau ${minutes} phút.`,
    heading: activation ? 'Xác minh email của bạn' : 'Chào mừng bạn đến với DealGo',
    blocks: [
      {
        kind: 'p',
        text: activation
          ? 'Nhập mã sau trong ứng dụng DealGo để xác minh địa chỉ email và tiếp tục đăng nhập:'
          : 'Nhập mã sau trong ứng dụng DealGo để hoàn tất tạo tài khoản:',
      },
      { kind: 'code', code: input.code, caption: `Mã có hiệu lực trong **${minutes} phút**.` },
      { kind: 'note', text: NO_SHARE },
      {
        kind: 'p',
        text: activation
          ? 'Nếu bạn không vừa đăng nhập DealGo, hãy đổi mật khẩu ngay trong ứng dụng.'
          : 'Nếu bạn không tạo tài khoản DealGo, hãy bỏ qua email này. Sẽ không có tài khoản nào được tạo.',
      },
    ],
    reason: activation
      ? 'Bạn nhận được email này vì có người vừa đăng nhập DealGo bằng địa chỉ này.'
      : 'Bạn nhận được email này vì có người vừa đăng ký DealGo bằng địa chỉ này.',
  });
}

export function signupAccountExistsMail(): RenderedMail {
  return render({
    subject: 'Có người vừa thử đăng ký DealGo bằng email của bạn',
    preheader: 'Email này đã có tài khoản DealGo nên không có tài khoản mới nào được tạo.',
    heading: 'Email này đã có tài khoản',
    blocks: [
      { kind: 'p', text: 'Có người vừa thử tạo tài khoản DealGo mới bằng địa chỉ email này. Vì email đã có tài khoản, **không có tài khoản mới nào được tạo**.' },
      { kind: 'p', text: 'Nếu đó là bạn, hãy mở ứng dụng DealGo để đăng nhập, hoặc chọn “Quên mật khẩu” để đặt lại.' },
      { kind: 'note', text: 'Nếu không phải bạn, bạn không cần làm gì. Tài khoản của bạn vẫn an toàn.' },
    ],
    reason: 'Bạn nhận được email này vì địa chỉ này đã gắn với một tài khoản DealGo.',
  });
}

export function testMail(): RenderedMail {
  return render({
    subject: 'DealGo: email thử nghiệm',
    preheader: 'Cấu hình gửi email của DealGo đang hoạt động.',
    heading: 'Gửi email thành công',
    blocks: [
      { kind: 'p', text: 'Đây là email thử từ trang quản trị DealGo. Bạn nhận được email này nghĩa là **cấu hình gửi email đang hoạt động**.' },
      { kind: 'button', label: 'Mở trang quản trị', url: MAIL_BRAND.siteUrl },
    ],
    reason: 'Email được gửi từ nút “Gửi email thử” trong trang quản trị DealGo.',
  });
}

export function policyUpdateMail(input: Omit<PolicyUpdateMail, 'email'>): RenderedMail {
  const when = input.effectiveAt
    ? input.effectiveAt.toLocaleDateString('vi-VN', { timeZone: 'Asia/Ho_Chi_Minh' })
    : null;
  const blocks: Block[] = [
    {
      kind: 'p',
      text: `DealGo đã cập nhật **${input.documentTitle}** (phiên bản ${input.version})${when ? `, có hiệu lực từ **${when}**` : ''}.`,
    },
  ];
  if (input.changelog.trim()) {
    blocks.push({ kind: 'note', text: `Điểm thay đổi chính: ${input.changelog.trim()}` });
  }
  blocks.push(
    { kind: 'p', text: 'Lần tới mở ứng dụng, bạn sẽ được yêu cầu xem và đồng ý với nội dung mới để tiếp tục sử dụng dịch vụ.' },
    { kind: 'button', label: 'Xem nội dung đầy đủ', url: input.url },
  );
  return render({
    subject: `DealGo cập nhật ${input.documentTitle}`,
    preheader: `${input.documentTitle} phiên bản ${input.version}${when ? ` có hiệu lực từ ${when}` : ''}.`,
    heading: `Cập nhật ${input.documentTitle}`,
    blocks,
    reason: 'Bạn nhận được email này vì bạn có tài khoản DealGo và điều khoản áp dụng cho bạn đã thay đổi.',
  });
}

/** Shared MailSender implementation: subclasses only provide transport (SMTP, SES API, …). */
export abstract class TemplatedMailSender implements MailSender {
  protected abstract transport(to: string, mail: RenderedMail, kind: string): Promise<void>;

  async sendEmailVerification(input: EmailVerificationCodeMail): Promise<void> {
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

  async sendTestEmail(input: { email: string }): Promise<void> {
    await this.transport(input.email, testMail(), 'test');
  }

  async sendPolicyUpdate(input: PolicyUpdateMail): Promise<void> {
    await this.transport(input.email, policyUpdateMail(input), 'policy_update');
  }
}

/** Mask the local part for logs: "an***@example.com". */
export function redactEmail(email: string): string {
  const [local, domain] = email.split('@');
  if (!domain) return '***';
  return `${local.slice(0, 2)}***@${domain}`;
}
