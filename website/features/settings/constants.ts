export const SETTINGS_TABS = [
  "Cấu hình chung",
  "Bảo mật",
  "Tích hợp",
  "Feature flags",
] as const;

export const SETTINGS_SECURITY_TOGGLES = [
  { id: "setting-mfa-admin", label: "Bắt buộc MFA cho Admin", defaultOn: true },
  {
    id: "setting-hide-pii",
    label: "Ẩn PII trên bảng vận hành",
    defaultOn: true,
  },
  {
    id: "setting-dual-approval",
    label: "Phê duyệt kép thay đổi cấu hình",
    defaultOn: true,
  },
] as const;
