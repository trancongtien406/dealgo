import { formatOpsDate } from "@/lib/ops-time";

/** Nest OpsUserDeletionView (S027, DEC-PROD-037). */
export type AccountDeletionInfo = {
  status: "SCHEDULED" | "PURGED";
  deletedAt: string;
  purgeAfter: string | null;
  purgedAt: string | null;
};

export function parseAccountDeletion(raw: unknown): AccountDeletionInfo | null {
  if (!raw || typeof raw !== "object") {
    return null;
  }
  const row = raw as Record<string, unknown>;
  if ((row.status !== "SCHEDULED" && row.status !== "PURGED") || typeof row.deletedAt !== "string") {
    return null;
  }
  return {
    status: row.status,
    deletedAt: row.deletedAt,
    purgeAfter: typeof row.purgeAfter === "string" ? row.purgeAfter : null,
    purgedAt: typeof row.purgedAt === "string" ? row.purgedAt : null,
  };
}

export function accountDeletionLabel(info: AccountDeletionInfo): string {
  return info.status === "PURGED" ? "Đã xoá tài khoản" : "Đang chờ xoá";
}

/** One line for the detail card: when it was requested and what happens next. */
export function accountDeletionSummary(info: AccountDeletionInfo): string {
  const requested = `Người dùng xác nhận xoá lúc ${formatOpsDate(info.deletedAt)}`;
  if (info.status === "PURGED") {
    return `${requested}. Dữ liệu cá nhân đã được ẩn danh${
      info.purgedAt ? ` lúc ${formatOpsDate(info.purgedAt)}` : ""
    }; lịch sử chuyến/đơn được giữ để đối soát.`;
  }
  return `${requested}. Tài khoản đã bị khoá đăng nhập; dữ liệu cá nhân sẽ bị ẩn danh${
    info.purgeAfter ? ` sau ${formatOpsDate(info.purgeAfter)}` : ""
  }. Có thể khôi phục trước thời điểm đó.`;
}

export function canRestoreAccount(info: AccountDeletionInfo | null | undefined): boolean {
  return info?.status === "SCHEDULED";
}
