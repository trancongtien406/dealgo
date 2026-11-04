"use client";

import { useMemo, useState } from "react";
import {
  AdminBreadcrumb,
  QuietChip,
  StatusChip,
  focusRing,
} from "@/components/ui/admin-list-ui";
import { SearchSelect } from "@/components/ui/search-select";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { toast } from "@/components/ui/toast";
import {
  HOME_BANNER_AUDIENCES,
  HOME_BANNER_CTA_EXAMPLES,
  HOME_BANNER_IMAGE_HINT,
  HOME_BANNER_IMAGE_MAX_BYTES,
  HOME_BANNER_SERVICES,
  HOME_BANNER_STATE_LABEL,
  checkHomeBannerDraft,
  diffHomeBannerPayload,
  draftFromHomeBanner,
  emptyHomeBannerDraft,
  formatCtr,
  formatIct,
  homeBannerCtaProblem,
  homeBannerImageSizeProblem,
  homeBannerImageSrc,
  moveHomeBannerId,
} from "@/features/home-banners/form";
import {
  useCreateHomeBannerMutation,
  useDeleteHomeBannerMutation,
  useHomeBannersQuery,
  usePatchHomeBannerMutation,
  useReorderHomeBannersMutation,
  useUploadHomeBannerImageMutation,
} from "@/features/home-banners/hooks";
import type {
  HomeBannerAudience,
  HomeBannerDraft,
  HomeBannerRow,
  HomeBannerState,
} from "@/features/home-banners/types";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { countFormat } from "@/lib/admin-format";
import { useZonesQuery } from "@/features/zones/hooks";
import type { ZoneItem } from "@/features/zones/types";
import { serviceRegionLabel } from "@/lib/service-region-labels";

const STATE_TONE: Record<
  HomeBannerState,
  "success" | "brand" | "food" | "danger" | "delivery"
> = {
  LIVE: "success",
  SCHEDULED: "brand",
  EXPIRED: "delivery",
  INACTIVE: "food",
  NO_IMAGE: "danger",
};

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof ApiError ? error.message : fallback;
}

export function HomeBannersBoard() {
  const { data, isPending, isError, error, refetch } = useHomeBannersQuery();
  const forbidden = isError && isForbiddenError(error);
  const rows = useMemo(() => data ?? [], [data]);
  const patchMutation = usePatchHomeBannerMutation();
  const deleteMutation = useDeleteHomeBannerMutation();
  const reorderMutation = useReorderHomeBannersMutation();
  const [editing, setEditing] = useState<HomeBannerRow | "new" | null>(null);
  const [deleting, setDeleting] = useState<HomeBannerRow | null>(null);
  const busy = patchMutation.isPending || reorderMutation.isPending;
  // Region targeting reuses the zones managed at /zones (single source of truth).
  const zonesQuery = useZonesQuery("ALL");
  const zones = useMemo(() => zonesQuery.data ?? [], [zonesQuery.data]);
  const regionName = (code: string) =>
    zones.find((z) => z.code === code)?.label ?? serviceRegionLabel(code);

  const move = (id: string, delta: -1 | 1) => {
    const next = moveHomeBannerId(
      rows.map((r) => r.id),
      id,
      delta,
    );
    if (!next || busy) {
      return;
    }
    reorderMutation.mutate(next, {
      onError: (e) => toast.error(errorMessage(e, "Không đổi được thứ tự.")),
    });
  };

  const toggle = (row: HomeBannerRow) => {
    if (busy) {
      return;
    }
    patchMutation.mutate(
      { id: row.id, patch: { active: !row.active } },
      {
        onSuccess: () =>
          toast.success(row.active ? "Đã tắt banner." : "Đã bật banner."),
        onError: (e) =>
          toast.error(errorMessage(e, "Không cập nhật được banner.")),
      },
    );
  };

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Banner trang chủ" },
        ]}
      />
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Banner trang chủ app
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-muted">
            Banner hiện ở đầu trang chủ app theo vai trò, dịch vụ và khu vực.
            App hiển thị tối đa 8 banner đang chạy, theo thứ tự bên dưới.
          </p>
        </div>
        <button
          type="button"
          className={`h-10 rounded-xl bg-brand px-4 text-sm font-semibold text-white ${focusRing}`}
          onClick={() => setEditing("new")}
        >
          Thêm banner
        </button>
      </div>

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý banner"
          description="Tài khoản của bạn cần quyền content.write để sửa banner trang chủ."
        />
      ) : isError && rows.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách banner. Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <ul className="space-y-3">
          {Array.from({ length: 3 }).map((_, idx) => (
            <li
              key={idx}
              className="flex animate-pulse gap-4 rounded-2xl border border-border bg-white p-4 shadow-sm"
            >
              <div className="aspect-[2/1] w-48 rounded-xl bg-canvas" />
              <div className="flex-1 space-y-2.5">
                <div className="h-5 w-1/2 rounded bg-canvas" />
                <div className="h-4 w-3/4 rounded bg-canvas/70" />
              </div>
            </li>
          ))}
        </ul>
      ) : rows.length === 0 ? (
        <AdminEmptyState
          icon="categories"
          title="Chưa có banner"
          description="Khi chưa có banner đang chạy, app ẩn hẳn khu vực banner trên trang chủ."
        />
      ) : (
        <ul className="space-y-3">
          {rows.map((row, index) => {
            const src = homeBannerImageSrc(row.imageUrl);
            return (
              <li
                key={row.id}
                className="flex flex-col gap-4 rounded-2xl border border-border bg-white p-4 shadow-sm md:flex-row"
              >
                <div className="aspect-[2/1] w-full shrink-0 overflow-hidden rounded-xl bg-canvas md:w-56">
                  {src ? (
                    // eslint-disable-next-line @next/next/no-img-element
                    <img
                      src={src}
                      alt={`Banner ${index + 1}`}
                      className="size-full object-cover"
                    />
                  ) : (
                    <div className="grid size-full place-items-center text-xs text-muted">
                      Chưa có ảnh
                    </div>
                  )}
                </div>
                <div className="min-w-0 flex-1 space-y-1.5">
                  <div className="flex flex-wrap gap-2">
                    <StatusChip tone={STATE_TONE[row.state]} dot>
                      {HOME_BANNER_STATE_LABEL[row.state]}
                    </StatusChip>
                    {row.audiences.map((a) => (
                      <QuietChip key={a}>
                        {
                          HOME_BANNER_AUDIENCES.find((x) => x.value === a)
                            ?.label
                        }
                      </QuietChip>
                    ))}
                    <QuietChip>
                      {
                        HOME_BANNER_SERVICES.find(
                          (s) => s.value === row.service,
                        )?.label
                      }
                    </QuietChip>
                    <QuietChip>
                      {row.regionCode
                        ? regionName(row.regionCode)
                        : "Mọi khu vực"}
                    </QuietChip>
                  </div>
                  <h2 className="text-base font-semibold text-ink">
                    Banner {index + 1}
                  </h2>
                  <p className="truncate text-xs text-muted">
                    Liên kết: {row.ctaUrl ?? "—"} · {formatIct(row.startsAt)} →{" "}
                    {formatIct(row.endsAt)}
                  </p>
                  <p className="text-xs text-muted">
                    Hiển thị {countFormat.format(row.stats.impressions)} · Chạm{" "}
                    {countFormat.format(row.stats.clicks)} · CTR{" "}
                    {formatCtr(row.stats.ctr)} · 7 ngày:{" "}
                    {countFormat.format(row.stats.last7d.impressions)}/
                    {countFormat.format(row.stats.last7d.clicks)}
                  </p>
                </div>
                <div className="flex shrink-0 flex-wrap items-start gap-2 md:flex-col md:items-stretch">
                  <div className="flex gap-2">
                    <button
                      type="button"
                      aria-label="Lên trên"
                      disabled={index === 0 || busy}
                      className={`h-9 w-9 rounded-xl border border-border text-sm disabled:opacity-40 ${focusRing}`}
                      onClick={() => move(row.id, -1)}
                    >
                      ↑
                    </button>
                    <button
                      type="button"
                      aria-label="Xuống dưới"
                      disabled={index === rows.length - 1 || busy}
                      className={`h-9 w-9 rounded-xl border border-border text-sm disabled:opacity-40 ${focusRing}`}
                      onClick={() => move(row.id, 1)}
                    >
                      ↓
                    </button>
                  </div>
                  <button
                    type="button"
                    disabled={busy || (!row.active && !row.imageUrl)}
                    title={!row.imageUrl ? "Tải ảnh trước khi bật" : undefined}
                    className={`h-9 rounded-xl border px-3 text-sm font-medium disabled:opacity-40 ${
                      row.active
                        ? "border-border text-ink"
                        : "border-brand/40 text-brand"
                    } ${focusRing}`}
                    onClick={() => toggle(row)}
                  >
                    {row.active ? "Tắt" : "Bật"}
                  </button>
                  <button
                    type="button"
                    className={`h-9 rounded-xl border border-border px-3 text-sm font-medium text-ink ${focusRing}`}
                    onClick={() => setEditing(row)}
                  >
                    Sửa
                  </button>
                  <button
                    type="button"
                    className={`h-9 rounded-xl border border-danger/30 px-3 text-sm font-medium text-danger ${focusRing}`}
                    onClick={() => setDeleting(row)}
                  >
                    Xoá
                  </button>
                </div>
              </li>
            );
          })}
        </ul>
      )}

      <ConfirmDialog
        open={deleting !== null}
        title="Xoá banner?"
        description="Banner sẽ biến mất khỏi app và ảnh bị xoá. Không hoàn tác được."
        confirmLabel="Xoá"
        pending={deleteMutation.isPending}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (!deleting) return;
          deleteMutation.mutate(deleting.id, {
            onSuccess: () => {
              setDeleting(null);
              toast.success("Đã xoá banner.");
            },
            onError: (e) =>
              toast.error(errorMessage(e, "Không xoá được banner.")),
          });
        }}
      />
      {editing ? (
        <HomeBannerEditor
          row={editing === "new" ? null : editing}
          zones={zones}
          onClose={() => setEditing(null)}
        />
      ) : null}
    </div>
  );
}

function HomeBannerEditor({
  row,
  zones,
  onClose,
}: {
  row: HomeBannerRow | null;
  zones: ZoneItem[];
  onClose: () => void;
}) {
  const [draft, setDraft] = useState<HomeBannerDraft>(() =>
    row ? draftFromHomeBanner(row) : emptyHomeBannerDraft(),
  );
  const [file, setFile] = useState<{ name: string; dataUrl: string } | null>(
    null,
  );
  const [problem, setProblem] = useState<string | null>(null);
  const [imageWarning, setImageWarning] = useState<string | null>(null);
  const createMutation = useCreateHomeBannerMutation();
  const patchMutation = usePatchHomeBannerMutation();
  const uploadMutation = useUploadHomeBannerImageMutation();
  const pending =
    createMutation.isPending ||
    patchMutation.isPending ||
    uploadMutation.isPending;
  const ctaProblem = homeBannerCtaProblem(draft.ctaUrl, draft.audiences);
  const previewSrc = file?.dataUrl ?? homeBannerImageSrc(row?.imageUrl ?? null);
  const set = <K extends keyof HomeBannerDraft>(
    key: K,
    value: HomeBannerDraft[K],
  ) => setDraft((d) => ({ ...d, [key]: value }));

  const toggleAudience = (a: HomeBannerAudience) =>
    set(
      "audiences",
      draft.audiences.includes(a)
        ? draft.audiences.filter((x) => x !== a)
        : [...draft.audiences, a],
    );

  const pickFile = async (picked: File | undefined) => {
    setProblem(null);
    setImageWarning(null);
    if (!picked) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(picked.type)) {
      setProblem("Chọn ảnh JPEG, PNG hoặc WebP.");
      return;
    }
    if (picked.size > HOME_BANNER_IMAGE_MAX_BYTES) {
      setProblem("Ảnh tối đa 2 MB.");
      return;
    }
    try {
      const dataUrl = await readDataUrl(picked);
      setFile({ name: picked.name, dataUrl });
      const size = await readImageSize(dataUrl).catch(() => ({ w: 0, h: 0 }));
      setImageWarning(homeBannerImageSizeProblem(size.w, size.h));
    } catch {
      setProblem("Không đọc được ảnh.");
    }
  };

  const save = async () => {
    if (!row && !file) {
      setProblem("Chọn ảnh banner.");
      return;
    }
    const check = checkHomeBannerDraft(draft);
    if (!check.ok) {
      setProblem(check.message);
      return;
    }
    setProblem(null);
    try {
      let id = row?.id;
      if (!row) {
        id = (await createMutation.mutateAsync(check.payload)).id;
      } else {
        const patch = diffHomeBannerPayload(row, check.payload);
        if (Object.keys(patch).length > 0) {
          await patchMutation.mutateAsync({ id: row.id, patch });
        }
      }
      if (file && id) {
        await uploadMutation.mutateAsync({ id, dataUrl: file.dataUrl });
      }
      toast.success(
        row
          ? "Đã lưu banner."
          : "Đã tạo banner (đang tắt). Bật khi đã sẵn sàng.",
      );
      onClose();
    } catch (e) {
      setProblem(errorMessage(e, "Không lưu được banner."));
    }
  };

  const input = `mt-1 block h-10 w-full rounded-xl border border-border bg-white px-3 text-sm ${focusRing}`;
  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center bg-ink/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={row ? "Sửa banner" : "Thêm banner"}
    >
      <div className="grid max-h-[92vh] w-full max-w-4xl gap-5 overflow-y-auto rounded-2xl border border-border bg-white p-5 shadow-lg md:grid-cols-[1fr_320px]">
        <div className="space-y-3">
          <h2 className="text-lg font-semibold text-ink">
            {row ? "Sửa banner" : "Thêm banner"}
          </h2>
          <label className="block text-sm font-medium text-ink">
            Ảnh banner{row ? "" : " *"}
            <input
              type="file"
              accept="image/jpeg,image/png,image/webp"
              className="mt-1 block w-full text-sm"
              onChange={(e) => void pickFile(e.target.files?.[0])}
            />
          </label>
          <p
            className={`text-xs ${imageWarning ? "text-food" : "text-muted"}`}
            role={imageWarning ? "status" : undefined}
          >
            {imageWarning ??
              `${HOME_BANNER_IMAGE_HINT} Chữ (nếu có) thiết kế sẵn trong ảnh.`}
          </p>
          <fieldset className="text-sm text-ink">
            <legend className="font-medium">Hiển thị cho</legend>
            <div className="mt-1 flex flex-wrap gap-2">
              {HOME_BANNER_AUDIENCES.map((a) => (
                <label
                  key={a.value}
                  className="inline-flex h-9 items-center gap-2 rounded-full border border-border px-3"
                >
                  <input
                    type="checkbox"
                    checked={draft.audiences.includes(a.value)}
                    onChange={() => toggleAudience(a.value)}
                  />
                  {a.label}
                </label>
              ))}
            </div>
          </fieldset>
          <div className="grid gap-3 sm:grid-cols-2">
            <div>
              <SearchSelect
                label="Dịch vụ"
                icon="sliders"
                value={draft.service}
                options={HOME_BANNER_SERVICES}
                placeholder="Chọn dịch vụ"
                onChange={(val) => {
                  if (val) set("service", val as HomeBannerDraft["service"]);
                }}
              />
            </div>
            <div>
              <SearchSelect
                label="Khu vực"
                icon="pin"
                value={draft.regionCode || null}
                options={[
                  ...zones.map((z) => ({
                    value: z.code,
                    label: `${z.label}${z.status === "ACTIVE" ? "" : " (sắp mở)"}`,
                  })),
                  ...(draft.regionCode && !zones.some((z) => z.code === draft.regionCode)
                    ? [
                        {
                          value: draft.regionCode,
                          label:
                            serviceRegionLabel(draft.regionCode) ??
                            draft.regionCode,
                        },
                      ]
                    : []),
                ]}
                placeholder="Mọi khu vực"
                clearLabel="Mọi khu vực"
                onChange={(val) => set("regionCode", val ?? "")}
              />
            </div>
            <label className="block text-sm font-medium text-ink">
              Bắt đầu (ICT, tuỳ chọn)
              <input
                type="datetime-local"
                className={input}
                value={draft.startsAt}
                onChange={(e) => set("startsAt", e.target.value)}
              />
            </label>
            <label className="block text-sm font-medium text-ink">
              Kết thúc (ICT, tuỳ chọn)
              <input
                type="datetime-local"
                className={input}
                value={draft.endsAt}
                onChange={(e) => set("endsAt", e.target.value)}
              />
            </label>
          </div>
          <label className="block text-sm font-medium text-ink">
            Liên kết khi chạm (tuỳ chọn)
            <input
              className={input}
              placeholder="/customer/shop hoặc https://..."
              value={draft.ctaUrl}
              onChange={(e) => set("ctaUrl", e.target.value)}
            />
          </label>
          <p className={`text-xs ${ctaProblem ? "text-danger" : "text-muted"}`}>
            {ctaProblem ??
              `Ví dụ: ${draft.audiences
                .flatMap((a) => HOME_BANNER_CTA_EXAMPLES[a])
                .slice(0, 4)
                .join(", ")}. Liên kết https mở trong trình duyệt của app.`}
          </p>
          {problem ? (
            <p
              className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-danger"
              role="alert"
            >
              {problem}
            </p>
          ) : null}
          <div className="flex justify-end gap-2">
            <button
              type="button"
              disabled={pending}
              className={`h-10 rounded-xl border border-border px-3 text-sm ${focusRing}`}
              onClick={onClose}
            >
              Đóng
            </button>
            <button
              type="button"
              disabled={pending}
              className={`h-10 rounded-xl bg-brand px-4 text-sm font-semibold text-white disabled:opacity-60 ${focusRing}`}
              onClick={() => void save()}
            >
              {pending ? "Đang lưu…" : "Lưu"}
            </button>
          </div>
        </div>
        <div className="space-y-2">
          <p className="text-sm font-medium text-ink">Xem trước trên app</p>
          <div className="rounded-[28px] border border-border bg-canvas p-3">
            <div className="relative aspect-[2/1] overflow-hidden rounded-[20px] bg-white shadow-sm">
              {previewSrc ? (
                // eslint-disable-next-line @next/next/no-img-element
                <img
                  src={previewSrc}
                  alt="Xem trước banner"
                  className="size-full object-cover"
                />
              ) : (
                <div className="grid size-full place-items-center text-xs text-muted">
                  Ảnh 2:1
                </div>
              )}
            </div>
            <div className="mt-2 flex justify-center gap-1">
              <span className="h-1.5 w-4 rounded-full bg-brand" />
              <span className="h-1.5 w-1.5 rounded-full bg-border" />
              <span className="h-1.5 w-1.5 rounded-full bg-border" />
            </div>
          </div>
          {file ? (
            <p className="truncate text-xs text-muted">Ảnh mới: {file.name}</p>
          ) : null}
        </div>
      </div>
    </div>
  );
}

function readImageSize(src: string): Promise<{ w: number; h: number }> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve({ w: img.naturalWidth, h: img.naturalHeight });
    img.onerror = () => reject(new Error("decode"));
    img.src = src;
  });
}

function readDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () =>
      typeof reader.result === "string"
        ? resolve(reader.result)
        : reject(new Error("read"));
    reader.onerror = () => reject(new Error("read"));
    reader.readAsDataURL(file);
  });
}
