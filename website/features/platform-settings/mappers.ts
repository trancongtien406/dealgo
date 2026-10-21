import type { OpsIconName } from "@/components/ui/ops-icons";
import type {
  CategoryKey,
  PlatformSettingRow,
} from "@/features/platform-settings/types";

const LABELS: Record<string, { label: string; hint: string }> = {
  PAYMENT_METHODS_ENABLED: {
    label: "Kênh thanh toán bật (JSON)",
    hint: 'OPEN-002 — ví dụ ["COD","SANDBOX"]; không chứa secret PSP',
  },
  RIDE_MIN_FARE_VND: {
    label: "Giá Ride tối thiểu (VND)",
    hint: "OPEN-003/019 — TEST_ONLY bound",
  },
  RIDE_MAX_FARE_VND: {
    label: "Giá Ride tối đa (VND)",
    hint: "OPEN-003/019 — TEST_ONLY bound",
  },
  RIDE_REFERENCE_VND_PER_KM: {
    label: "Giá tham chiếu Ride / km (VND)",
    hint: "OPEN-003/019 — không phải phí chính thức",
  },
  FOOD_MIN_DELIVERY_VND: {
    label: "Phí giao Food tối thiểu (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  FOOD_MAX_DELIVERY_VND: {
    label: "Phí giao Food tối đa (VND)",
    hint: "OPEN-003 — TEST_ONLY",
  },
  DRIVER_SEARCH_RADIUS_KM: {
    label: "Bán kính tìm tài xế (km)",
    hint: "OPEN-004 — TEST_ONLY dispatch",
  },
  RIDE_OFFER_TTL_SECONDS: {
    label: "TTL đề nghị giá Ride (giây)",
    hint: "OPEN-004/019",
  },
  RIDE_NEGOTIATION_MAX_ROUNDS: {
    label: "Số vòng thương lượng tối đa",
    hint: "OPEN-019 — để trống nếu không giới hạn",
  },
  MAX_CONCURRENT_JOBS_PER_DRIVER: {
    label: "Job đồng thời / tài xế",
    hint: "OPEN-005 — lưu cấu hình; enforce dần",
  },
  PLATFORM_FEE_RIDE_PERCENT: {
    label: "Phí nền tảng chuyến xe (%)",
    hint: "DEC-PROD-014 — trừ trên cước tài xế; chốt % lúc hoàn thành chuyến (0–100, tối đa 2 số lẻ)",
  },
  PLATFORM_FEE_FOOD_PERCENT: {
    label: "Phí nền tảng giao đồ ăn (%)",
    hint: "DEC-PROD-014 — trừ trên phí giao của tài xế; chốt % lúc giao xong (0–100, tối đa 2 số lẻ)",
  },
  VOUCHER_SHARED_PLATFORM_PERCENT: {
    label: "Phần DealGo chịu với voucher đồng tài trợ (%)",
    hint: "DEC-PROD-015 — áp cho chiến dịch nhà tài trợ SHARED; phần còn lại trừ vào tiền trả quán (0–100)",
  },
  RATING_WINDOW_DAYS: {
    label: "Thời hạn đánh giá (ngày)",
    hint: "DEC-PROD-013 — khách đánh giá được trong số ngày này sau khi hoàn thành (1–365)",
  },
  RIDE_PICKUP_CODE_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã đón tối đa",
    hint: "DEC-PROD-017 — quá số lần này mã đón của chuyến bị khóa, ops huỷ/điều phối lại (1–20)",
  },
  FOOD_DELIVERY_CODE_REQUIRED: {
    label: "Bắt buộc mã giao hàng (Food)",
    hint: "DEC-PROD-036 — true: tài xế phải nhập mã 4 số khách đọc trên app mới hoàn tất giao; false: giao không cần mã",
  },
  FOOD_DELIVERY_CODE_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã giao / mã bàn giao tối đa",
    hint: "DEC-PROD-036 — quá số lần này mã của đơn bị khóa, ops xử lý (1–20)",
  },
  FOOD_HANDOVER_CODE_REQUIRED: {
    label: "Bắt buộc mã bàn giao quán ↔ tài xế",
    hint: "DEC-PROD-036 — true: tài xế phải nhập mã quán hiển thị khi lấy món (mặc định false)",
  },
  RATING_STORE_MIN_COUNT: {
    label: "Số đánh giá tối thiểu để hiện điểm quán",
    hint: "DEC-PROD-019 — dưới số này app chỉ hiện \"Quán mới\"/số lượt, không lộ số sao của từng khách (1–50)",
  },
  SUPPORT_TICKET_MAX_OPEN_PER_USER: {
    label: "Yêu cầu hỗ trợ đang mở tối đa / người dùng",
    hint: "DEC-PROD-018 — quá số này app báo chờ phản hồi hoặc bổ sung vào yêu cầu cũ (1–50)",
  },
  SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY: {
    label: "Yêu cầu từ website / SĐT hoặc email / 24 giờ",
    hint: "DEC-PROD-018 — chống spam form hỗ trợ công khai (1–50)",
  },
  SUPPORT_TICKET_TEXT_MAX_CHARS: {
    label: "Độ dài tối đa nội dung hỗ trợ (ký tự)",
    hint: "DEC-PROD-018 — áp cho mô tả và mỗi tin trao đổi (200–5000)",
  },
  UPLOAD_MAX_FILE_KB: {
    label: "Dung lượng tối đa mỗi tệp tải lên (KB)",
    hint: "DEC-PROD-020 — áp cho giấy tờ KYC/KYB và tệp đính kèm hỗ trợ (100–5120)",
  },
  UPLOAD_ORPHAN_MAX_AGE_HOURS: {
    label: "Xoá tệp tải lên không dùng sau (giờ)",
    hint: "DEC-PROD-022 — tệp không còn gắn với hồ sơ, ticket hay ảnh đại diện nào sẽ bị worker xoá khi cũ hơn số giờ này (24–2160)",
  },
  ACCOUNT_DELETION_GRACE_DAYS: {
    label: "Thời gian chờ trước khi xoá vĩnh viễn tài khoản (ngày)",
    hint: "DEC-PROD-037 — sau khi người dùng xác nhận xoá (S027), tài khoản bị khoá ngay; hết số ngày này worker ẩn danh hoá dữ liệu cá nhân. Trong thời gian chờ Admin khôi phục được (0–90; 0 = xoá ở lượt worker kế tiếp)",
  },
  UPLOAD_ALLOWED_TYPES: {
    label: "Định dạng tệp được phép tải lên",
    hint: "DEC-PROD-020 — mảng JSON, chọn trong image/jpeg, image/png, image/webp, application/pdf",
  },
  AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: {
    label: "Hiệu lực mã quên mật khẩu (phút)",
    hint: "DEC-PROD-045 — mã 6 số gửi qua email để đặt lại mật khẩu khách hàng (5–60)",
  },
  AUTH_PASSWORD_RESET_MAX_ATTEMPTS: {
    label: "Số lần nhập sai mã quên mật khẩu",
    hint: "DEC-PROD-045 — vượt quá thì mã bị khoá, phải gửi lại mã mới (3–10)",
  },
  AUTH_PASSWORD_RESET_MAX_PER_HOUR: {
    label: "Số yêu cầu quên mật khẩu mỗi email / giờ",
    hint: "DEC-PROD-045 — giới hạn theo địa chỉ email, ngoài giới hạn theo IP (1–20)",
  },
  CONTACT_WINDOW_MINUTES: {
    label: "Cửa sổ chat/voice (phút)",
    hint: "OPEN-014/021 — heuristic TEST_ONLY, chưa retention policy",
  },
};

const PERCENT_KEYS = new Set([
  "PLATFORM_FEE_RIDE_PERCENT",
  "PLATFORM_FEE_FOOD_PERCENT",
  "VOUCHER_SHARED_PLATFORM_PERCENT",
]);

/** Integer settings: [min, max, Vietnamese error]. Mirrors the backend catalog. */
const INTEGER_RANGES: Record<string, [number, number, string]> = {
  RATING_WINDOW_DAYS: [1, 365, "Thời hạn đánh giá phải là số nguyên từ 1 đến 365 ngày."],
  RIDE_PICKUP_CODE_MAX_ATTEMPTS: [1, 20, "Số lần nhập sai phải là số nguyên từ 1 đến 20."],
  FOOD_DELIVERY_CODE_MAX_ATTEMPTS: [1, 20, "Số lần nhập sai phải là số nguyên từ 1 đến 20."],
  RATING_STORE_MIN_COUNT: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_TICKET_MAX_OPEN_PER_USER: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_PUBLIC_TICKETS_PER_CONTACT_PER_DAY: [1, 50, "Giá trị phải là số nguyên từ 1 đến 50."],
  SUPPORT_TICKET_TEXT_MAX_CHARS: [200, 5000, "Giá trị phải là số nguyên từ 200 đến 5000."],
  UPLOAD_MAX_FILE_KB: [100, 5120, "Giá trị phải là số nguyên từ 100 đến 5120 KB."],
  UPLOAD_ORPHAN_MAX_AGE_HOURS: [24, 2160, "Giá trị phải là số nguyên từ 24 đến 2160 giờ (90 ngày)."],
  ACCOUNT_DELETION_GRACE_DAYS: [0, 90, "Giá trị phải là số nguyên từ 0 đến 90 ngày."],
  AUTH_PASSWORD_RESET_CODE_TTL_MINUTES: [5, 60, "Giá trị phải là số nguyên từ 5 đến 60 phút."],
  AUTH_PASSWORD_RESET_MAX_ATTEMPTS: [3, 10, "Giá trị phải là số nguyên từ 3 đến 10."],
  AUTH_PASSWORD_RESET_MAX_PER_HOUR: [1, 20, "Giá trị phải là số nguyên từ 1 đến 20."],
};

/** JSON boolean settings (backend spec.boolean): the editor offers Bật / Tắt. */
export const BOOLEAN_SETTING_KEYS: ReadonlySet<string> = new Set([
  "FOOD_DELIVERY_CODE_REQUIRED",
  "FOOD_HANDOVER_CODE_REQUIRED",
]);

export const UPLOAD_SNIFFABLE_TYPES = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
] as const;

function validateUploadTypes(value: string): string | null {
  const message =
    "Nhập mảng JSON các định dạng không trùng nhau, ví dụ [\"image/jpeg\",\"application/pdf\"].";
  let parsed: unknown;
  try {
    parsed = JSON.parse(value);
  } catch {
    return message;
  }
  if (
    !Array.isArray(parsed) ||
    parsed.length === 0 ||
    new Set(parsed).size !== parsed.length ||
    !parsed.every(
      (item) =>
        typeof item === "string" &&
        (UPLOAD_SNIFFABLE_TYPES as readonly string[]).includes(item),
    )
  ) {
    return message;
  }
  return null;
}

/**
 * Client-side check mirroring the backend rules (the backend stays the authority).
 * Returns a Vietnamese error message, or null when the value can be sent.
 */
export function validateSettingValue(key: string, value: string): string | null {
  const trimmed = value.trim();
  if (PERCENT_KEYS.has(key)) {
    if (!/^\d+(\.\d{1,2})?$/.test(trimmed)) {
      return "Giá trị phải là số từ 0 đến 100, tối đa 2 chữ số thập phân (ví dụ 12.5).";
    }
    if (Number(trimmed) > 100) {
      return "Giá trị không được vượt quá 100%.";
    }
    return null;
  }
  if (key === "UPLOAD_ALLOWED_TYPES") {
    return validateUploadTypes(trimmed);
  }
  if (BOOLEAN_SETTING_KEYS.has(key)) {
    return trimmed === "true" || trimmed === "false"
      ? null
      : "Giá trị phải là true (bật) hoặc false (tắt).";
  }
  const range = INTEGER_RANGES[key];
  if (range) {
    const [min, max, message] = range;
    if (!/^\d+$/.test(trimmed) || Number(trimmed) < min || Number(trimmed) > max) {
      return message;
    }
  }
  return null;
}

export function categorizeSetting(key: string): CategoryKey {
  if (key.startsWith("SUPPORT_") || key.startsWith("UPLOAD_") || key.startsWith("ACCOUNT_")) {
    return "SUPPORT";
  }
  if (key.startsWith("PLATFORM_FEE") || key === "VOUCHER_SHARED_PLATFORM_PERCENT") {
    return "FARE";
  }
  if (
    key.startsWith("RIDE_MIN") ||
    key.startsWith("RIDE_MAX") ||
    key.startsWith("RIDE_REF") ||
    key.startsWith("FOOD_MIN") ||
    key.startsWith("FOOD_MAX")
  ) {
    return "FARE";
  }
  if (
    key.includes("RADIUS") ||
    key.includes("TTL") ||
    key.includes("ROUNDS") ||
    key.includes("JOBS") ||
    key.includes("WINDOW") ||
    key.includes("ATTEMPTS") ||
    key.endsWith("_CODE_REQUIRED") ||
    key.startsWith("RATING_")
  ) {
    return "DISPATCH";
  }
  return "ZONE_PAYMENT";
}

export function getSettingIcon(category: CategoryKey): OpsIconName {
  switch (category) {
    case "FARE":
      return "receipt";
    case "DISPATCH":
      return "car";
    case "ZONE_PAYMENT":
      return "pin";
    case "SUPPORT":
      return "headset";
    default:
      return "settings";
  }
}

export function enrichPlatformSetting(row: {
  key: string;
  value: string;
  valueType: PlatformSettingRow["valueType"];
  source: "db" | "env";
  openIds: string[];
  updatedAt: string | null;
  updatedByUserId: string | null;
}): PlatformSettingRow {
  const meta = LABELS[row.key] ?? {
    label: row.key,
    hint: row.openIds.join(", ") || "Platform setting",
  };
  return { ...row, ...meta };
}
