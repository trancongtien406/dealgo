"use client";

import { useMemo, useState } from "react";
import { AdminBreadcrumb, focusRing } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { useAppVersionPolicyQuery, usePatchAppVersionPolicyMutation } from "@/features/app-version/hooks";
import { APP_PLATFORM_LABELS, type AppPlatform } from "@/features/app-version/types";
import { draftToPolicy, platformErrors, toPlatformDraft, type PlatformDraft } from "@/features/app-version/validate";
import { isForbiddenError } from "@/lib/api/errors";

const PLATFORMS: AppPlatform[] = ["ios", "android"];
const inputCls = `mt-1 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`;

type Draft = { platforms: Record<AppPlatform, PlatformDraft>; message: string; enforceApi: boolean };

function Field({ label, hint, value, onChange, error, placeholder }: {
  label: string; hint?: string; value: string; onChange: (v: string) => void; error?: string; placeholder?: string;
}) {
  return (
    <label className="block text-sm font-medium text-ink">
      {label}
      <input className={inputCls} value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} aria-invalid={Boolean(error)} />
      {error ? <span className="mt-1 block text-xs text-danger">{error}</span> : hint ? <span className="mt-1 block text-xs text-muted">{hint}</span> : null}
    </label>
  );
}

export function AppVersionBoard() {
  const { data, isPending, isError, error, refetch } = useAppVersionPolicyQuery();
  const forbidden = isError && isForbiddenError(error);
  const mutation = usePatchAppVersionPolicyMutation();
  const [draft, setDraft] = useState<Draft | null>(null);
  const [confirming, setConfirming] = useState(false);

  const base = useMemo<Draft>(
    () => ({
      platforms: { ios: toPlatformDraft(data?.ios), android: toPlatformDraft(data?.android) },
      message: data?.message ?? "",
      enforceApi: data?.enforceApi ?? true,
    }),
    [data],
  );
  const d = draft ?? base;
  const errors = { ios: platformErrors("ios", d.platforms.ios), android: platformErrors("android", d.platforms.android) };
  const hasErrors = PLATFORMS.some((p) => Object.keys(errors[p]).length > 0);
  const payload = draftToPolicy(d.platforms, d.message, d.enforceApi);
  const dirty = JSON.stringify(payload) !== JSON.stringify(draftToPolicy(base.platforms, base.message, base.enforceApi));
  const setPlatform = (p: AppPlatform, next: Partial<PlatformDraft>) =>
    setDraft({ ...d, platforms: { ...d.platforms, [p]: { ...d.platforms[p], ...next } } });

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb items={[{ label: "Trang chủ", href: "/overview" }, { label: "Cài đặt & Nhật ký", href: "/settings" }, { label: "Cập nhật ứng dụng" }]} />
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">Yêu cầu cập nhật ứng dụng</h1>
        <p className="mt-1 text-sm text-muted">
          Build thấp hơn <b>build tối thiểu</b> bị chặn bằng màn hình “Cập nhật bắt buộc” (không bỏ qua được). Build thấp hơn{" "}
          <b>build mới nhất</b> chỉ nhận lời nhắc có thể đóng. Để trống = tắt. Ứng dụng kiểm tra khi mở và khi quay lại từ nền.
          Chỉ nâng build tối thiểu khi bản mới đã có trên cửa hàng.
        </p>
      </div>
      {forbidden ? (
        <AdminForbiddenState title="Không có quyền cấu hình cập nhật" description="Cần quyền settings.write." />
      ) : isError ? (
        <AdminListErrorBanner message="Không thể tải chính sách cập nhật." onRetry={() => { void refetch(); }} />
      ) : isPending ? (
        <p className="text-sm text-muted">Đang tải…</p>
      ) : (
        <>
          {PLATFORMS.map((p) => (
            <section key={p} className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
              <h2 className="text-base font-bold text-ink">{APP_PLATFORM_LABELS[p]}</h2>
              <div className="grid gap-4 md:grid-cols-3">
                <Field label="Build tối thiểu (bắt buộc)" placeholder="0 = tắt" hint="Ví dụ 23 cho bản 1.0.0+23" value={d.platforms[p].minBuild} error={errors[p].minBuild} onChange={(v) => setPlatform(p, { minBuild: v })} />
                <Field label="Build mới nhất (nhắc nhở)" placeholder="0 = tắt" value={d.platforms[p].latestBuild} error={errors[p].latestBuild} onChange={(v) => setPlatform(p, { latestBuild: v })} />
                <Field label="Phiên bản hiển thị" placeholder="1.0.1" value={d.platforms[p].latestVersion} onChange={(v) => setPlatform(p, { latestVersion: v })} />
              </div>
              <Field
                label="Link cửa hàng"
                placeholder={p === "ios" ? "https://apps.apple.com/vn/app/…" : "https://play.google.com/store/apps/details?id=…"}
                hint="Bắt buộc khi đặt build tối thiểu; nút “Cập nhật” trong ứng dụng mở link này."
                value={d.platforms[p].storeUrl}
                error={errors[p].storeUrl}
                onChange={(v) => setPlatform(p, { storeUrl: v })}
              />
            </section>
          ))}
          <section className="space-y-4 rounded-2xl border border-border bg-white p-4 shadow-sm">
            <h2 className="text-base font-bold text-ink">Thông điệp & chặn API</h2>
            <label className="block text-sm font-medium text-ink">
              Thông điệp (tuỳ chọn, tối đa 300 ký tự)
              <textarea className={`${inputCls} min-h-20`} maxLength={300} value={d.message} placeholder="Để trống = câu mặc định của ứng dụng" onChange={(e) => setDraft({ ...d, message: e.target.value })} />
            </label>
            <label className="flex items-start gap-2 text-sm text-ink">
              <input type="checkbox" className="mt-1" checked={d.enforceApi} onChange={(e) => setDraft({ ...d, enforceApi: e.target.checked })} />
              <span>
                Chặn cả API với build dưới mức tối thiểu (lỗi <code>APP_UPDATE_REQUIRED</code>). Chỉ áp dụng cho bản có gửi số build
                (từ bản phát hành có tính năng này trở đi).
              </span>
            </label>
          </section>
          <div className="flex flex-wrap justify-end gap-3">
            <button type="button" disabled={!dirty} onClick={() => setDraft(null)} className={`rounded-xl border border-border px-4 py-2 text-sm font-semibold text-ink disabled:opacity-50 ${focusRing}`}>
              Hoàn tác
            </button>
            <button type="button" disabled={!dirty || hasErrors} onClick={() => setConfirming(true)} className={`rounded-xl bg-brand px-4 py-2 text-sm font-semibold text-white disabled:opacity-50 ${focusRing}`}>
              Lưu thay đổi
            </button>
          </div>
        </>
      )}
      {confirming ? (
        <OpsInterveneDialog
          open
          labels={{ title: "Lưu chính sách cập nhật", confirm: "Xác nhận lưu", hint: "Nâng build tối thiểu sẽ chặn ngay người dùng bản cũ. Lý do được ghi nhật ký kiểm toán.", success: "Đã cập nhật chính sách." }}
          confirmTone="brand"
          entityLabel="Cập nhật ứng dụng"
          pending={mutation.isPending}
          onClose={() => setConfirming(false)}
          onConfirm={async (reason) => {
            await mutation.mutateAsync({ policy: payload, reason });
            setDraft(null);
          }}
        />
      ) : null}
    </div>
  );
}
