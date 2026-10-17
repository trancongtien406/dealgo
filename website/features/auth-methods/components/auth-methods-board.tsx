"use client";

import { useState } from "react";
import { toast } from "sonner";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  focusRing,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import {
  useAuthMethodsQuery,
  usePatchAuthMethodMutation,
} from "@/features/auth-methods/hooks";
import {
  authMethodHint,
  authMethodLabel,
  canDisableLastMethod,
} from "@/features/auth-methods/mappers";
import type {
  AuthMethodRow,
  PendingToggle,
} from "@/features/auth-methods/types";

import { isForbiddenError } from "@/lib/api/errors";

export function AuthMethodsBoard() {
  const { data, isPending, isError, error, refetch, isFetching } =
    useAuthMethodsQuery();
  const forbidden = isError && isForbiddenError(error);
  const patchMutation = usePatchAuthMethodMutation();
  const [pendingToggle, setPendingToggle] = useState<PendingToggle | null>(
    null,
  );
  const [bannerError, setBannerError] = useState<string | null>(null);
  const items = data ?? [];
  const enabledCount = items.filter((row) => row.enabled).length;

  const openToggle = (row: AuthMethodRow) => {
    const nextEnabled = !row.enabled;
    setBannerError(null);
    if (!nextEnabled && !canDisableLastMethod(items, row.method)) {
      setBannerError(
        "Không thể tắt phương thức xác thực cuối cùng còn bật. Bật thêm một phương thức khác trước.",
      );
      return;
    }
    setPendingToggle({ method: row.method, enabled: nextEnabled });
  };

  return (
    <div className="min-w-0 space-y-5">
      {bannerError ? (
        <p
          className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-danger"
          role="alert"
        >
          {bannerError}
        </p>
      ) : null}
      {isError && !forbidden && items.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách phương thức xác thực. Vui lòng thử lại sau."
          onRetry={() => {
            void refetch();
          }}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Phương thức xác thực" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Phương thức xác thực
          </h1>
          <p className="mt-1 text-sm text-muted">
            Quản lý cấu hình đăng nhập Passkey, OTP SMS và Email toàn hệ thống
            kèm nhật ký bảo mật.
          </p>
        </div>
        <button
          type="button"
          disabled={isPending || isFetching}
          onClick={() => {
            void refetch();
            toast.success("Đã đồng bộ trạng thái các phương thức xác thực");
          }}
          className={`inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3 text-sm font-medium text-ink shadow-xs transition-colors hover:bg-canvas hover:border-brand/40 cursor-pointer ${focusRing}`}
          title="Bấm để làm mới trạng thái xác thực"
        >
          <OpsIcon
            name="shield"
            className={`size-4 ${isFetching ? "animate-pulse text-brand" : "text-brand"}`}
          />
          <span>Bảo mật xác thực</span>
          <OpsIcon
            name="refresh"
            className={`size-3.5 text-muted ${isFetching ? "animate-spin text-brand" : ""}`}
          />
        </button>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <li className="rounded-2xl border border-border bg-white p-4 shadow-sm">
          <p className="text-xs font-medium tracking-wide text-muted uppercase">
            Đang bật
          </p>
          <p className="mt-1 text-2xl font-semibold tabular-nums text-ink">
            {enabledCount} / {items.length || 3}
          </p>
        </li>
        <li className="rounded-2xl border border-border bg-white p-4 shadow-sm sm:col-span-2">
          <p className="text-xs font-medium tracking-wide text-muted uppercase">
            Bảo vệ
          </p>
          <p className="mt-1 text-sm leading-6 text-muted">
            Hệ thống luôn yêu cầu duy trì ít nhất một phương thức xác thực hoạt
            động để đảm bảo an toàn truy cập.
          </p>
        </li>
      </ul>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý phương thức xác thực"
          description="Tài khoản của bạn không có quyền xem hoặc sửa cấu hình xác thực hệ thống. Vui lòng liên hệ bộ phận an ninh mạng."
        />
      ) : isError && items.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách phương thức xác thực. Vui lòng thử lại sau."
          onRetry={() => {
            void refetch();
          }}
        />
      ) : !isPending && items.length === 0 ? (
        <AdminEmptyState
          icon="shield"
          title="Chưa có phương thức xác thực"
          description="Không tìm thấy cấu hình phương thức xác thực nào trên máy chủ."
        />
      ) : (
        <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
          <div className="border-b border-border px-4 py-3">
            <h2
              id="auth-methods-list"
              className="text-base font-semibold text-ink"
            >
              Ba phương thức hệ thống
            </h2>
            <p className="mt-0.5 text-sm text-muted">
              Mỗi lần đổi trạng thái cần lý do (3–500 ký tự).
            </p>
          </div>
          <ul
            aria-labelledby="auth-methods-list"
            className="divide-y divide-border"
          >
            {isPending
              ? Array.from({ length: 3 }).map((_, idx) => (
                  <li
                    key={idx}
                    className="flex items-center justify-between p-4 animate-pulse"
                  >
                    <div className="space-y-2 flex-1">
                      <div className="h-4 w-40 rounded bg-canvas" />
                      <div className="h-3 w-64 rounded bg-canvas" />
                    </div>
                    <div className="h-7 w-12 rounded-full bg-canvas" />
                  </li>
                ))
              : items.map((row) => {
                  const lastLocked =
                    row.enabled && !canDisableLastMethod(items, row.method);
                  return (
                    <li
                      key={row.method}
                      className="flex flex-wrap items-center justify-between gap-3 px-4 py-4"
                    >
                      <div className="min-w-0">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="text-sm font-semibold text-ink">
                            {authMethodLabel(row.method)}
                          </p>
                          <StatusChip tone={row.enabled ? "success" : "food"}>
                            {row.enabled ? "Đang bật" : "Đã tắt"}
                          </StatusChip>
                          {lastLocked ? (
                            <StatusChip tone="danger">
                              Phương thức cuối
                            </StatusChip>
                          ) : null}
                        </div>
                        <p className="mt-1 text-sm text-muted">
                          {authMethodHint(row.method)}
                        </p>
                        <p className="mt-1 text-xs text-muted">
                          Cập nhật {row.updatedAtLabel}
                          {row.updatedByUserId
                            ? ` · bởi ${row.updatedByUserId}`
                            : ""}
                        </p>
                      </div>
                      <button
                        type="button"
                        role="switch"
                        aria-checked={row.enabled}
                        aria-label={`${row.enabled ? "Tắt" : "Bật"} ${authMethodLabel(row.method)}`}
                        disabled={patchMutation.isPending}
                        onClick={() => openToggle(row)}
                        className={`relative h-7 w-12 shrink-0 rounded-full transition-colors disabled:opacity-50 ${
                          row.enabled ? "bg-success" : "bg-border"
                        } ${focusRing}`}
                      >
                        <span
                          className={`absolute top-0.5 size-6 rounded-full bg-white shadow transition-transform ${
                            row.enabled ? "left-5" : "left-0.5"
                          }`}
                        />
                      </button>
                    </li>
                  );
                })}
          </ul>
        </section>
      )}
      {pendingToggle ? (
        <OpsInterveneDialog
          open
          labels={{
            title: pendingToggle.enabled
              ? "Bật phương thức xác thực"
              : "Tắt phương thức xác thực",
            confirm: pendingToggle.enabled ? "Xác nhận bật" : "Xác nhận tắt",
            hint: "Lý do được ghi vào nhật ký kiểm toán trên máy chủ.",
          }}
          confirmTone={pendingToggle.enabled ? "brand" : "danger"}
          entityLabel={authMethodLabel(pendingToggle.method)}
          pending={patchMutation.isPending}
          onClose={() => setPendingToggle(null)}
          onConfirm={async (reason) => {
            await patchMutation.mutateAsync({
              method: pendingToggle.method,
              enabled: pendingToggle.enabled,
              reason,
            });
            setBannerError(null);
          }}
        />
      ) : null}
    </div>
  );
}
