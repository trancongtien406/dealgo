import {
  EMAIL_CONFIG_FIELDS,
  EMAIL_SECRET_FIELDS,
  type EmailConfigField,
  type EmailDraft,
  type EmailProviderChoice,
  type EmailSecretEdits,
  type EmailSettingsView,
  type FieldSource,
  type MapKeyField,
} from "@/features/integrations/types";

export const EMAIL_PROVIDER_LABELS: Record<EmailProviderChoice | "mock", string> = {
  smtp: "Gmail SMTP",
  ses: "Amazon SES",
  disabled: "Tắt",
  mock: "Mock (dev)",
};

export const SOURCE_LABELS: Record<FieldSource, string> = {
  admin: "Admin",
  env: "env",
  default: "mặc định",
  unset: "trống",
};

export const MAP_KEY_LABELS: Record<MapKeyField, string> = {
  mapboxPublicToken: "Mapbox public token (pk.)",
  mapboxServerToken: "Mapbox server token",
  googleMapsApiKey: "Google Maps API key",
};

const emailErrors: Record<string, string> = {
  not_configured: "Chưa đủ cấu hình để gửi",
  auth_failed: "Sai tài khoản hoặc mật khẩu ứng dụng",
  rate_limited: "Nhà cung cấp đang giới hạn tốc độ",
  rejected: "Địa chỉ nhận bị từ chối",
  suppressed: "Địa chỉ nhận đang bị chặn (bounce/complaint)",
  provider_unavailable: "Không kết nối được nhà cung cấp",
};

export function emailTestErrorLabel(code: string | null): string {
  return code ? (emailErrors[code] ?? code) : "";
}

const mapErrors: Record<string, string> = {
  unset: "Chưa có key",
  timeout: "Hết thời gian chờ",
  network_error: "Lỗi mạng",
  TokenInvalid: "Token không hợp lệ",
  TokenExpired: "Token đã hết hạn",
  TokenRevoked: "Token đã bị thu hồi",
  REQUEST_DENIED: "Key bị từ chối hoặc chưa bật Geocoding API",
  OVER_QUERY_LIMIT: "Hết hạn mức",
};

export function mapKeyTestLabel(ok: boolean, detail: string): string {
  if (ok) return "Hoạt động";
  return mapErrors[detail] ?? detail;
}

export function emailDraftFromView(view: EmailSettingsView): EmailDraft {
  return {
    provider: view.provider === "mock" ? "" : view.provider,
    fromName: view.fromName,
    fromAddress: view.fromAddress,
    smtpHost: view.smtp.host,
    smtpPort: String(view.smtp.port),
    smtpUser: view.smtp.user,
    smtpSecure: view.smtp.secure ? "true" : "false",
    sesRegion: view.ses.region,
    sesConfigurationSet: view.ses.configurationSet,
    sesSnsTopicArn: view.ses.snsTopicArn,
    smtpPassword: "",
    sesAccessKeyId: "",
    sesSecretAccessKey: "",
  };
}

/** Only changed config fields and typed/cleared secrets go to the API. */
export function emailPatch(
  view: EmailSettingsView,
  draft: EmailDraft,
  secrets: EmailSecretEdits,
): Record<string, string | null> {
  const base = emailDraftFromView(view);
  const patch: Record<string, string | null> = {};
  for (const field of EMAIL_CONFIG_FIELDS) {
    const next = draft[field].trim();
    if (next !== base[field].trim()) {
      patch[field] = next === "" ? null : next;
    }
  }
  for (const field of EMAIL_SECRET_FIELDS) {
    const edit = secrets[field];
    if (edit === null) {
      patch[field] = null;
    } else if (typeof edit === "string" && edit.trim() !== "") {
      patch[field] = edit.trim();
    }
  }
  return patch;
}

export function secretIsSet(view: EmailSettingsView, field: (typeof EMAIL_SECRET_FIELDS)[number]): boolean {
  if (field === "smtpPassword") return view.smtp.passwordSet;
  if (field === "sesAccessKeyId") return view.ses.accessKeyIdSet;
  return view.ses.secretAccessKeySet;
}

export function isConfigField(field: string): field is EmailConfigField {
  return (EMAIL_CONFIG_FIELDS as readonly string[]).includes(field);
}
