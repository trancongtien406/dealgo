"use client";

import { useState, type Dispatch, type SetStateAction } from "react";
import { toast } from "sonner";
import { AdminBreadcrumb } from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { vehicleClassImageSrc } from "@/features/ride-vehicle-classes/api";
import {
  useClearRideVehicleClassImageMutation,
  usePatchRideVehicleClassMutation,
  useRideVehicleClassesQuery,
  useUploadRideVehicleClassImageMutation,
} from "@/features/ride-vehicle-classes/hooks";
import type { RideVehicleClassRow } from "@/features/ride-vehicle-classes/types";
import { isForbiddenError } from "@/lib/api/errors";

type Draft = Omit<RideVehicleClassRow, "code" | "sortOrder" | "imageUrl">;

const MAX_IMAGE_BYTES = 1_500_000;

function draftFrom(row: RideVehicleClassRow): Draft {
  return {
    name: row.name,
    seats: row.seats,
    enabled: row.enabled,
    baseFareVnd: row.baseFareVnd,
    perKmVnd: row.perKmVnd,
    perMinuteVnd: row.perMinuteVnd,
    minFareVnd: row.minFareVnd,
    maxFareVnd: row.maxFareVnd,
    assumedSpeedKmh: row.assumedSpeedKmh,
  };
}

function draftsFrom(
  rows: RideVehicleClassRow[] | undefined,
): Record<string, Draft> {
  return rows
    ? Object.fromEntries(rows.map((row) => [row.code, draftFrom(row)]))
    : {};
}

function vnd(value: number): string {
  return `${new Intl.NumberFormat("vi-VN").format(value)}đ`;
}

export function VehicleClassesBoard() {
  const { data, isPending, isError, error, refetch } =
    useRideVehicleClassesQuery();
  const forbidden = isError && isForbiddenError(error);
  const patchMutation = usePatchRideVehicleClassMutation();
  const uploadMutation = useUploadRideVehicleClassImageMutation();
  const clearMutation = useClearRideVehicleClassImageMutation();
  const [drafts, setDrafts] = useState<Record<string, Draft>>(() =>
    draftsFrom(data),
  );
  const [syncedData, setSyncedData] = useState(data);
  const [previews, setPreviews] = useState<Record<string, string>>({});

  // Reset local drafts when the server list changes (React "adjusting state
  // when a prop changes" pattern) instead of syncing inside an effect.
  if (data !== syncedData) {
    setSyncedData(data);
    if (data) {
      setDrafts(draftsFrom(data));
    }
  }

  const save = async (code: string) => {
    const draft = drafts[code];
    if (!draft) {
      return;
    }
    try {
      await patchMutation.mutateAsync({ code, patch: draft });
      toast.success(`Đã lưu ${draft.name}`);
    } catch (saveError) {
      toast.error(
        saveError instanceof Error ? saveError.message : "Chưa lưu được loại xe",
      );
    }
  };

  const upload = async (code: string, file: File | undefined) => {
    if (!file) {
      return;
    }
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      toast.error("Chỉ nhận JPEG, PNG hoặc WebP.");
      return;
    }
    if (file.size > MAX_IMAGE_BYTES) {
      toast.error("Ảnh lớn hơn 1,5 MB.");
      return;
    }
    const dataUrl = await readDataUrl(file);
    const preview = URL.createObjectURL(file);
    setPreviews((current) => {
      const previous = current[code];
      if (previous) {
        URL.revokeObjectURL(previous);
      }
      return { ...current, [code]: preview };
    });
    try {
      await uploadMutation.mutateAsync({ code, dataUrl });
      setPreviews((current) => {
        const next = { ...current };
        if (next[code]) {
          URL.revokeObjectURL(next[code]);
          delete next[code];
        }
        return next;
      });
      toast.success("Đã cập nhật ảnh loại xe");
    } catch (uploadError) {
      setPreviews((current) => {
        const next = { ...current };
        if (next[code]) {
          URL.revokeObjectURL(next[code]);
          delete next[code];
        }
        return next;
      });
      toast.error(
        uploadError instanceof Error ? uploadError.message : "Chưa tải được ảnh",
      );
    }
  };

  const clearImage = async (code: string) => {
    try {
      await clearMutation.mutateAsync(code);
      setPreviews((current) => {
        const next = { ...current };
        delete next[code];
        return next;
      });
      toast.success("Đã gỡ ảnh");
    } catch (clearError) {
      toast.error(
        clearError instanceof Error ? clearError.message : "Chưa gỡ được ảnh",
      );
    }
  };

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Loại xe" },
        ]}
      />
      <div>
        <h1 className="text-xl font-semibold text-ink">Loại xe</h1>
        <p className="mt-1 max-w-3xl text-sm text-muted">
          Ảnh giúp nhận ra từng loại. Giá bên dưới là mức tham chiếu để khách
          chào giá trong khoảng cho phép.
        </p>
      </div>
      {forbidden ? <AdminForbiddenState /> : null}
      {isError && !forbidden ? (
        <AdminListErrorBanner
          message="Không tải được danh sách loại xe."
          onRetry={() => {
            void refetch();
          }}
        />
      ) : null}
      {isPending ? <p className="text-sm text-muted">Đang tải…</p> : null}
      {!isPending && !forbidden && (data?.length ?? 0) === 0 ? (
        <AdminEmptyState
          title="Chưa có loại xe"
          description="Danh sách được tạo khi có báo giá đầu tiên."
        />
      ) : null}
      <div className="grid gap-4 lg:grid-cols-3">
        {(data ?? []).map((row) => {
          const draft = drafts[row.code] ?? draftFrom(row);
          const image = previews[row.code] ?? vehicleClassImageSrc(row.imageUrl);
          return (
            <article
              key={row.code}
              className="overflow-hidden rounded-2xl border border-border bg-white"
            >
              <div className="relative h-44 bg-canvas">
                {image ? (
                  // Local blob: previews and admin-uploaded URLs; next/image cannot optimise blob: sources.
                  // eslint-disable-next-line @next/next/no-img-element
                  <img
                    src={image}
                    alt={draft.name}
                    className="h-full w-full object-cover"
                  />
                ) : (
                  <div className="flex h-full flex-col items-center justify-center gap-1 text-muted">
                    <span className="text-3xl" aria-hidden>
                      {row.code === "MOTORBIKE" ? "🛵" : "🚗"}
                    </span>
                    <span className="text-sm">Chưa có ảnh</span>
                  </div>
                )}
                <div className="absolute inset-x-3 bottom-3 flex gap-2">
                  <label className="inline-flex h-9 cursor-pointer items-center rounded-xl bg-white/95 px-3 text-sm font-medium text-ink shadow-sm">
                    {uploadMutation.isPending ? "Đang tải…" : "Tải ảnh"}
                    <input
                      type="file"
                      accept="image/jpeg,image/png,image/webp"
                      className="sr-only"
                      onChange={(event) => {
                        const file = event.target.files?.[0];
                        event.target.value = "";
                        void upload(row.code, file);
                      }}
                    />
                  </label>
                  {row.imageUrl ? (
                    <button
                      type="button"
                      className="inline-flex h-9 items-center rounded-xl bg-white/95 px-3 text-sm font-medium text-danger shadow-sm"
                      onClick={() => {
                        void clearImage(row.code);
                      }}
                    >
                      Gỡ ảnh
                    </button>
                  ) : null}
                </div>
              </div>
              <form
                className="space-y-4 p-4"
                onSubmit={(event) => {
                  event.preventDefault();
                  void save(row.code);
                }}
              >
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <p className="text-lg font-semibold text-ink">{draft.name}</p>
                    <p className="text-xs text-muted">
                      {row.code} · {draft.seats} chỗ
                    </p>
                  </div>
                  <span
                    className={`rounded-full px-2.5 py-1 text-xs font-medium ${
                      draft.enabled
                        ? "bg-brand/10 text-brand"
                        : "bg-canvas text-muted"
                    }`}
                  >
                    {draft.enabled ? "Đang mở" : "Đang tắt"}
                  </span>
                </div>
                <dl className="grid grid-cols-3 gap-2 text-center">
                  <Stat label="Mở cửa" value={vnd(draft.baseFareVnd)} />
                  <Stat label="Mỗi km" value={vnd(draft.perKmVnd)} />
                  <Stat label="Mỗi phút" value={vnd(draft.perMinuteVnd)} />
                </dl>
                <p className="text-sm text-muted">
                  Khách chào từ {vnd(draft.minFareVnd)} đến {vnd(draft.maxFareVnd)}
                </p>
                <label className="flex items-center gap-2 text-sm text-ink">
                  <input
                    type="checkbox"
                    checked={draft.enabled}
                    onChange={(event) =>
                      setDraft(setDrafts, row.code, draft, {
                        enabled: event.target.checked,
                      })
                    }
                  />
                  Nhận chuyến loại này
                </label>
                <div className="grid gap-3 sm:grid-cols-2">
                  <Field
                    label="Tên hiển thị"
                    value={draft.name}
                    onChange={(name) => setDraft(setDrafts, row.code, draft, { name })}
                  />
                  <NumberField
                    label="Số chỗ"
                    value={draft.seats}
                    onChange={(seats) =>
                      setDraft(setDrafts, row.code, draft, { seats })
                    }
                  />
                  <NumberField
                    label="Giá mở cửa"
                    value={draft.baseFareVnd}
                    onChange={(baseFareVnd) =>
                      setDraft(setDrafts, row.code, draft, { baseFareVnd })
                    }
                  />
                  <NumberField
                    label="Mỗi km"
                    value={draft.perKmVnd}
                    onChange={(perKmVnd) =>
                      setDraft(setDrafts, row.code, draft, { perKmVnd })
                    }
                  />
                  <NumberField
                    label="Mỗi phút"
                    value={draft.perMinuteVnd}
                    onChange={(perMinuteVnd) =>
                      setDraft(setDrafts, row.code, draft, { perMinuteVnd })
                    }
                  />
                  <NumberField
                    label="Tối thiểu"
                    value={draft.minFareVnd}
                    onChange={(minFareVnd) =>
                      setDraft(setDrafts, row.code, draft, { minFareVnd })
                    }
                  />
                  <NumberField
                    label="Tối đa"
                    value={draft.maxFareVnd}
                    onChange={(maxFareVnd) =>
                      setDraft(setDrafts, row.code, draft, { maxFareVnd })
                    }
                  />
                  <NumberField
                    label="Tốc độ ước lượng (km/h)"
                    value={draft.assumedSpeedKmh}
                    onChange={(assumedSpeedKmh) =>
                      setDraft(setDrafts, row.code, draft, { assumedSpeedKmh })
                    }
                  />
                </div>
                <button
                  type="submit"
                  disabled={patchMutation.isPending}
                  className="inline-flex h-10 items-center rounded-xl bg-brand px-4 text-sm font-medium text-white disabled:opacity-60"
                >
                  Lưu thông số
                </button>
              </form>
            </article>
          );
        })}
      </div>
    </div>
  );
}

function setDraft(
  setDrafts: Dispatch<SetStateAction<Record<string, Draft>>>,
  code: string,
  draft: Draft,
  patch: Partial<Draft>,
) {
  setDrafts((current) => ({ ...current, [code]: { ...draft, ...patch } }));
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-canvas px-2 py-2">
      <dt className="text-[11px] text-muted">{label}</dt>
      <dd className="mt-0.5 text-sm font-semibold text-ink">{value}</dd>
    </div>
  );
}

function Field({
  label,
  value,
  onChange,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
}) {
  return (
    <label className="block text-sm text-ink">
      <span className="mb-1 block text-xs text-muted">{label}</span>
      <input
        className="h-10 w-full rounded-xl border border-border bg-white px-3"
        value={value}
        onChange={(event) => onChange(event.target.value)}
      />
    </label>
  );
}

function NumberField({
  label,
  value,
  onChange,
}: {
  label: string;
  value: number;
  onChange: (value: number) => void;
}) {
  return (
    <label className="block text-sm text-ink">
      <span className="mb-1 block text-xs text-muted">{label}</span>
      <input
        className="h-10 w-full rounded-xl border border-border bg-white px-3"
        inputMode="numeric"
        value={String(value)}
        onChange={(event) => {
          const next = Number(event.target.value.replace(/[^\d]/g, ""));
          onChange(Number.isFinite(next) ? next : 0);
        }}
      />
    </label>
  );
}

function readDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === "string") {
        resolve(reader.result);
        return;
      }
      reject(new Error("Không đọc được ảnh"));
    };
    reader.onerror = () => reject(new Error("Không đọc được ảnh"));
    reader.readAsDataURL(file);
  });
}
