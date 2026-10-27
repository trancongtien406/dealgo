"use client";

import { useState } from "react";
import { AdminBreadcrumb, focusRing, StatusChip } from "@/components/ui/admin-list-ui";
import {
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import {
  useMapsProvidersQuery,
  useSetMapsProviderMutation,
} from "@/features/maps-providers/hooks";
import {
  canChooseProvider,
  PROVIDER_LABELS,
} from "@/features/maps-providers/mappers";
import {
  MAPS_PROVIDER_CHOICES,
  type MapsCapabilityRow,
  type PendingMapsChoice,
} from "@/features/maps-providers/types";
import { isForbiddenError } from "@/lib/api/errors";

export function MapsProvidersBoard() {
  const { data, isPending, isError, error, refetch } = useMapsProvidersQuery();
  const forbidden = isError && isForbiddenError(error);
  const mutation = useSetMapsProviderMutation();
  const [pending, setPending] = useState<PendingMapsChoice | null>(null);

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Bản đồ" },
        ]}
      />
      <div className="min-w-0">
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
          Nhà cung cấp bản đồ
        </h1>
        <p className="mt-1 text-sm text-muted">
          Chọn Mapbox hoặc Google Maps cho từng chức năng. Nếu Google lỗi hoặc
          hết hạn mức, hệ thống tự quay về Mapbox.
        </p>
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xem cấu hình bản đồ"
          description="Cần quyền settings.read để xem và settings.write để đổi nhà cung cấp."
        />
      ) : isError ? (
        <AdminListErrorBanner
          message="Không thể tải cấu hình bản đồ. Vui lòng thử lại sau."
          onRetry={() => {
            void refetch();
          }}
        />
      ) : (
        <>
          <ul className="grid grid-cols-1 gap-3 sm:grid-cols-3">
            <li className="rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs font-medium tracking-wide text-muted uppercase">
                Google Maps
              </p>
              <p className="mt-1 flex items-center gap-2 text-sm font-semibold text-ink">
                {isPending ? (
                  "…"
                ) : data?.googleConfigured ? (
                  <StatusChip tone="success">Đã có API key</StatusChip>
                ) : (
                  <StatusChip tone="food">Chưa cấu hình</StatusChip>
                )}
              </p>
              {!isPending && !data?.googleConfigured ? (
                <p className="mt-2 text-xs leading-5 text-muted">
                  Thêm GOOGLE_MAPS_API_KEY vào backend.env rồi khởi động lại
                  API để bật lựa chọn Google.
                </p>
              ) : null}
            </li>
            <li className="rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs font-medium tracking-wide text-muted uppercase">
                Mặc định (env)
              </p>
              <p className="mt-1 text-sm text-ink">
                Tìm kiếm: <b>{data?.primary.maps ?? "…"}</b>
                <br />
                Lộ trình: <b>{data?.primary.routing ?? "…"}</b>
              </p>
              <p className="mt-2 text-xs text-muted">
                Bản đồ nền trong app luôn là Mapbox.
              </p>
            </li>
            <li className="rounded-2xl border border-border bg-white p-4 shadow-sm">
              <p className="text-xs font-medium tracking-wide text-muted uppercase">
                Chi phí & điều khoản
              </p>
              <p className="mt-1 text-xs leading-5 text-muted">
                Google tính phí theo lượt gọi (gợi ý + chi tiết địa điểm mỗi
                lần tìm). Điều khoản Google yêu cầu hiển thị kết quả trên bản
                đồ Google; app đang dùng nền Mapbox và ghi chú “Google Maps”
                — cần xem lại trước khi bật lâu dài.
              </p>
            </li>
          </ul>

          <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
            <div className="border-b border-border px-4 py-3">
              <h2 id="maps-capabilities" className="text-base font-semibold text-ink">
                Chức năng
              </h2>
              <p className="mt-0.5 text-sm text-muted">
                Mỗi lần đổi cần lý do (3–500 ký tự), ghi vào nhật ký kiểm toán.
              </p>
            </div>
            <ul aria-labelledby="maps-capabilities" className="divide-y divide-border">
              {isPending
                ? Array.from({ length: 3 }).map((_, idx) => (
                    <li key={idx} className="animate-pulse p-4">
                      <div className="h-4 w-40 rounded bg-canvas" />
                      <div className="mt-2 h-3 w-64 rounded bg-canvas" />
                    </li>
                  ))
                : (data?.rows ?? []).map((row) => (
                    <CapabilityRow
                      key={row.key}
                      row={row}
                      googleConfigured={data?.googleConfigured ?? false}
                      disabled={mutation.isPending}
                      onPick={(value) =>
                        setPending({ key: row.key, label: row.label, value })
                      }
                    />
                  ))}
            </ul>
          </section>
        </>
      )}

      {pending ? (
        <OpsInterveneDialog
          open
          labels={{
            title: `Chuyển sang ${PROVIDER_LABELS[pending.value]}`,
            confirm: "Xác nhận đổi",
            hint: "Lý do được ghi vào nhật ký kiểm toán. Thay đổi có hiệu lực sau vài giây.",
          }}
          confirmTone="brand"
          entityLabel={pending.label}
          pending={mutation.isPending}
          onClose={() => setPending(null)}
          onConfirm={async (reason) => {
            await mutation.mutateAsync({
              key: pending.key,
              value: pending.value,
              reason,
            });
          }}
        />
      ) : null}
    </div>
  );
}

function CapabilityRow({
  row,
  googleConfigured,
  disabled,
  onPick,
}: {
  row: MapsCapabilityRow;
  googleConfigured: boolean;
  disabled: boolean;
  onPick: (value: (typeof MAPS_PROVIDER_CHOICES)[number]) => void;
}) {
  return (
    <li className="flex flex-wrap items-center justify-between gap-3 px-4 py-4">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <p className="text-sm font-semibold text-ink">{row.label}</p>
          <StatusChip tone={row.effective === "google" ? "delivery" : "success"}>
            Đang dùng {PROVIDER_LABELS[row.effective]}
          </StatusChip>
          {row.degraded ? (
            <StatusChip tone="danger">Google chưa có key</StatusChip>
          ) : null}
        </div>
        <p className="mt-1 max-w-2xl text-sm text-muted">{row.hint}</p>
        <p className="mt-1 text-xs text-muted">
          {row.key} · cập nhật {row.updatedAtLabel}
          {row.updatedByUserId ? ` · bởi ${row.updatedByUserId}` : ""}
        </p>
      </div>
      <div
        role="radiogroup"
        aria-label={`Nhà cung cấp cho ${row.label}`}
        className="inline-flex shrink-0 rounded-xl border border-border bg-canvas p-1"
      >
        {MAPS_PROVIDER_CHOICES.map((value) => {
          const selected = row.chosen === value;
          const allowed = canChooseProvider({ googleConfigured }, value);
          return (
            <button
              key={value}
              type="button"
              role="radio"
              aria-checked={selected}
              disabled={disabled || !allowed || selected}
              title={allowed ? undefined : "Cần GOOGLE_MAPS_API_KEY trên server"}
              onClick={() => onPick(value)}
              className={`h-9 rounded-lg px-3 text-sm font-medium transition-colors disabled:cursor-not-allowed ${
                selected
                  ? "bg-white text-brand shadow-xs"
                  : allowed
                    ? "text-ink hover:bg-white/70 cursor-pointer"
                    : "text-muted opacity-50"
              } ${focusRing}`}
            >
              {PROVIDER_LABELS[value]}
            </button>
          );
        })}
      </div>
    </li>
  );
}
