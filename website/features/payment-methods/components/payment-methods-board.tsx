"use client";

import { useMemo, useState } from "react";
import { AdminBreadcrumb, focusRing, StatusChip } from "@/components/ui/admin-list-ui";
import { AdminForbiddenState, AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import {
  usePatchPaymentMethodsMutation,
  usePaymentMethodsQuery,
} from "@/features/payment-methods/hooks";
import {
  configStatus,
  diffPatches,
  draftFromMethod,
  GROUP_LABELS,
  SERVICE_LABELS,
} from "@/features/payment-methods/mappers";
import {
  PAYMENT_SERVICES,
  type OpsPaymentMethod,
  type PaymentMethodDraft,
} from "@/features/payment-methods/types";
import { isForbiddenError } from "@/lib/api/errors";

export function PaymentMethodsBoard() {
  const { data, isPending, isError, error, refetch } = usePaymentMethodsQuery();
  const forbidden = isError && isForbiddenError(error);
  const mutation = usePatchPaymentMethodsMutation();
  const [edits, setEdits] = useState<Record<string, PaymentMethodDraft>>({});
  const [confirming, setConfirming] = useState(false);

  const methods = useMemo(() => data?.methods ?? [], [data]);
  const drafts = useMemo(() => {
    const out: Record<string, PaymentMethodDraft> = {};
    for (const m of methods) out[m.code] = edits[m.code] ?? draftFromMethod(m);
    return out;
  }, [methods, edits]);
  const patches = useMemo(() => diffPatches(methods, drafts), [methods, drafts]);
  const dirty = patches.length > 0;

  const update = (code: string, next: Partial<PaymentMethodDraft>) =>
    setEdits((prev) => ({ ...prev, [code]: { ...drafts[code]!, ...next } }));

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Thanh toán" },
        ]}
      />
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
          Phương thức thanh toán
        </h1>
        <p className="mt-1 text-sm text-muted">
          Bật/tắt từng phương thức theo dịch vụ. Phương thức chỉ hiện cho khách khi được bật,
          đã tích hợp thật và đủ biến môi trường. Tiền mặt luôn bật để hệ thống vẫn chạy khi ẩn
          mọi cổng thanh toán. Khóa bí mật không bao giờ hiển thị ở đây.
        </p>
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem phương thức thanh toán"
          description="Cần quyền settings.read để xem và settings.write để thay đổi."
        />
      ) : isError ? (
        <AdminListErrorBanner
          message="Không thể tải phương thức thanh toán. Vui lòng thử lại sau."
          onRetry={() => {
            void refetch();
          }}
        />
      ) : (
        <>
          {!isPending && !data?.publicBaseUrlConfigured ? (
            <p className="rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger">
              Chưa đặt PAYMENT_PUBLIC_BASE_URL — mọi cổng online đang bị ẩn.
            </p>
          ) : null}

          <section className="min-w-0 overflow-x-auto rounded-2xl border border-border bg-white shadow-sm">
            <table className="w-full min-w-[880px] text-sm">
              <thead className="border-b border-border text-left text-xs uppercase tracking-wide text-muted">
                <tr>
                  <th className="px-4 py-3">Phương thức</th>
                  {PAYMENT_SERVICES.map((s) => (
                    <th key={s} className="px-2 py-3 text-center">
                      {SERVICE_LABELS[s]}
                    </th>
                  ))}
                  <th className="px-2 py-3">Thứ tự</th>
                  <th className="px-2 py-3">Lý do khi ẩn</th>
                  <th className="px-4 py-3">Cấu hình</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                {isPending
                  ? Array.from({ length: 4 }).map((_, i) => (
                      <tr key={i} className="animate-pulse">
                        <td colSpan={7} className="px-4 py-4">
                          <div className="h-4 w-60 rounded bg-canvas" />
                        </td>
                      </tr>
                    ))
                  : methods.map((m) => (
                      <MethodRow
                        key={m.code}
                        method={m}
                        draft={drafts[m.code]!}
                        publicBaseUrlConfigured={data?.publicBaseUrlConfigured ?? false}
                        disabled={mutation.isPending}
                        onChange={(next) => update(m.code, next)}
                      />
                    ))}
              </tbody>
            </table>
          </section>

          <div className="flex flex-wrap justify-end gap-2">
            <button
              type="button"
              disabled={!dirty || mutation.isPending}
              onClick={() => {
                setEdits({});
              }}
              className={`h-10 rounded-xl border border-border bg-white px-4 text-sm font-medium text-ink disabled:opacity-50 cursor-pointer ${focusRing}`}
            >
              Hoàn tác
            </button>
            <button
              type="button"
              disabled={!dirty || mutation.isPending}
              onClick={() => setConfirming(true)}
              className={`h-10 rounded-xl bg-brand px-4 text-sm font-semibold text-white disabled:opacity-50 cursor-pointer ${focusRing}`}
            >
              Lưu thay đổi
            </button>
          </div>
        </>
      )}

      {confirming ? (
        <OpsInterveneDialog
          open
          labels={{
            title: "Lưu phương thức thanh toán",
            confirm: "Xác nhận lưu",
            hint: "Lý do được ghi vào nhật ký kiểm toán. Khách thấy thay đổi sau vài giây.",
            success: "Đã cập nhật phương thức thanh toán.",
          }}
          confirmTone="brand"
          entityLabel={`${patches.length} phương thức`}
          pending={mutation.isPending}
          onClose={() => setConfirming(false)}
          onConfirm={async (reason) => {
            await mutation.mutateAsync({
              ...(patches.length > 0 ? { methods: patches } : {}),
              reason,
            });
            setEdits({});
          }}
        />
      ) : null}
    </div>
  );
}

function MethodRow({
  method,
  draft,
  publicBaseUrlConfigured,
  disabled,
  onChange,
}: {
  method: OpsPaymentMethod;
  draft: PaymentMethodDraft;
  publicBaseUrlConfigured: boolean;
  disabled: boolean;
  onChange: (next: Partial<PaymentMethodDraft>) => void;
}) {
  const status = configStatus(method, publicBaseUrlConfigured);
  return (
    <tr className="align-top">
      <td className="px-4 py-3">
        <p className="font-semibold text-ink">{method.label}</p>
        <p className="text-xs text-muted">
          {method.code} · {GROUP_LABELS[method.group]}
          {method.locked ? " · luôn bật" : ""}
        </p>
      </td>
      {PAYMENT_SERVICES.map((s) => (
        <td key={s} className="px-2 py-3 text-center">
          <input
            type="checkbox"
            aria-label={`${method.label} cho ${SERVICE_LABELS[s]}`}
            className={`size-4 accent-brand ${focusRing}`}
            checked={draft.services[s]}
            disabled={disabled || method.locked}
            onChange={(e) =>
              onChange({ services: { ...draft.services, [s]: e.target.checked } })
            }
          />
          <p className="mt-1 text-[11px] text-muted">
            {method.availableFor[s] ? "Đang hiện" : "Ẩn"}
          </p>
        </td>
      ))}
      <td className="px-2 py-3">
        <input
          type="number"
          min={0}
          max={999}
          aria-label={`Thứ tự ${method.label}`}
          className={`h-9 w-20 rounded-lg border border-border px-2 ${focusRing}`}
          value={draft.sortOrder}
          disabled={disabled || method.locked}
          onChange={(e) =>
            onChange({ sortOrder: Math.max(0, Math.min(999, Number(e.target.value) || 0)) })
          }
        />
      </td>
      <td className="px-2 py-3">
        <input
          type="text"
          maxLength={160}
          aria-label={`Lý do ẩn ${method.label}`}
          placeholder="Mặc định: Sắp ra mắt"
          className={`h-9 w-56 rounded-lg border border-border px-2 ${focusRing}`}
          value={draft.unsupportedReason}
          disabled={disabled || method.locked}
          onChange={(e) => onChange({ unsupportedReason: e.target.value })}
        />
      </td>
      <td className="px-4 py-3">
        <StatusChip tone={status.tone}>{status.label}</StatusChip>
        {method.requiredEnv.length > 0 ? (
          <p className="mt-1 max-w-[220px] break-words font-mono text-[11px] text-muted">
            {method.requiredEnv.join(", ")}
          </p>
        ) : null}
      </td>
    </tr>
  );
}
