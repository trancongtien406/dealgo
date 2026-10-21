"use client";

import { useMemo, useState } from "react";
import {
  AdminBreadcrumb,
  QuietChip,
  focusRing,
  StatusChip,
  KpiCard,
  ExportCsvButton,
} from "@/components/ui/admin-list-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { toast } from "@/components/ui/toast";
import {
  usePatchPlatformSettingMutation,
  usePlatformSettingsQuery,
} from "@/features/platform-settings/hooks";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
} from "@/components/ui/admin-state-ui";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { formatOpsDate } from "@/lib/ops-time";
import { OpsIcon } from "@/components/ui/ops-icons";
import type {
  CategoryKey,
  Draft,
  PlatformSettingRow,
  PlatformSettingSourceFilter,
} from "../types";
import {
  PLATFORM_SETTING_CATEGORIES,
  PLATFORM_SETTING_SOURCES,
} from "../constants";
import {
  BOOLEAN_SETTING_KEYS,
  categorizeSetting,
  getSettingIcon,
  validateSettingValue,
} from "../mappers";

export function PlatformSettingsBoard() {
  const [searchQuery, setSearchQuery] = useState("");
  const [activeCategory, setActiveCategory] = useState<CategoryKey>("ALL");
  const [sourceFilter, setSourceFilter] =
    useState<PlatformSettingSourceFilter>("ALL");

  const { data, isPending, isError, error, refetch } = usePlatformSettingsQuery(
    {
      q: searchQuery,
      category: activeCategory,
      source: sourceFilter,
    },
  );

  const { data: allData } = usePlatformSettingsQuery();

  const forbidden = isError && isForbiddenError(error);
  const patchMutation = usePatchPlatformSettingMutation();
  const [draft, setDraft] = useState<Draft | null>(null);
  const [editValue, setEditValue] = useState("");
  const [reason, setReason] = useState("");
  const [banner, setBanner] = useState<string | null>(null);
  const [confirmSave, setConfirmSave] = useState(false);

  const rows = useMemo(() => data ?? [], [data]);

  const dbOverrideCount = useMemo(
    () => (allData ?? rows).filter((r) => r.source === "db").length,
    [allData, rows],
  );
  const envDefaultCount = useMemo(
    () => (allData ?? rows).filter((r) => r.source !== "db").length,
    [allData, rows],
  );

  const openEdit = (row: PlatformSettingRow) => {
    setBanner(null);
    setConfirmSave(false);
    setDraft({ key: row.key, label: row.label });
    setEditValue(row.value);
    setReason("");
  };

  const requestSave = () => {
    if (!draft || patchMutation.isPending) {
      return;
    }
    const invalid = validateSettingValue(draft.key, editValue);
    if (invalid) {
      setBanner(invalid);
      return;
    }
    const trimmedReason = reason.trim();
    if (trimmedReason.length < 3) {
      setBanner(
        "Lý do thay đổi cấu hình phải từ 3 ký tự để lưu vết kiểm toán.",
      );
      return;
    }
    setConfirmSave(true);
  };

  const save = () => {
    if (!draft || patchMutation.isPending) {
      return;
    }
    const trimmedReason = reason.trim();
    if (trimmedReason.length < 3) {
      setBanner("Lý do thay đổi cấu hình phải từ 3 ký tự.");
      setConfirmSave(false);
      return;
    }
    patchMutation.mutate(
      { key: draft.key, value: editValue, reason: trimmedReason },
      {
        onSuccess: () => {
          setDraft(null);
          setConfirmSave(false);
          toast.success(`Đã cập nhật tham số ${draft.key}`);
        },
        onError: (error) => {
          const message =
            error instanceof ApiError
              ? error.message
              : "Không lưu được cấu hình.";
          setBanner(message);
          toast.error(message);
          setConfirmSave(false);
        },
      },
    );
  };

  return (
    <div className="min-w-0 space-y-6">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Tham số vận hành hệ thống" },
        ]}
      />

      <div className="flex flex-wrap items-start justify-between gap-4">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Cài đặt tham số vận hành
          </h1>
          <p className="mt-1 max-w-3xl text-sm text-muted">
            Quản trị tập trung các ngưỡng giá cước, biên độ trả giá, bán kính
            tìm tài xế và quy tắc điều phối của toàn hệ thống DealGo. Mọi thay
            đổi đều ghi nhận vào Audit Log.
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            onClick={() => void refetch()}
            className="inline-flex h-10 items-center gap-2 rounded-xl border border-border bg-white px-3.5 text-sm font-medium text-ink hover:bg-canvas cursor-pointer shadow-xs"
          >
            <OpsIcon name="undo" className="size-4 text-muted" />
            Làm mới
          </button>
          <ExportCsvButton
            filename="platform_settings.csv"
            headers={["Khóa tham số", "Mô tả", "Giá trị", "Nguồn", "Ghi chú"]}
            rows={rows.map((r) => [r.key, r.label, r.value, r.source, r.hint])}
          >
            <OpsIcon name="download" className="size-4" />
            Xuất dữ liệu
          </ExportCsvButton>
        </div>
      </div>

      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <li className="h-full">
          <KpiCard
            label="Tổng tham số cấu hình"
            value={rows.length}
            note="Hệ thống vận hành DealGo"
            icon="settings"
            tone="brand"
          />
        </li>
        <li className="h-full">
          <KpiCard
            label="DB Override"
            value={dbOverrideCount}
            note="Đã ghi đè từ Database"
            noteTone="food"
            icon="sliders"
            tone="food"
          />
        </li>
        <li className="h-full">
          <KpiCard
            label="Mặc định Environment"
            value={envDefaultCount}
            note="Bootstrap từ file .env"
            icon="shield"
            tone="delivery"
          />
        </li>
        <li className="h-full">
          <KpiCard
            label="Trạng thái đồng bộ"
            value={"API Trực tiếp"}
            note={"Hệ thống đang hoạt động"}
            noteTone="success"
            icon="check"
            tone="success"
          />
        </li>
      </ul>

      <div className="rounded-2xl border border-border bg-white p-4 shadow-sm space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div className="flex flex-wrap gap-1 rounded-xl bg-canvas p-1 border border-border">
            {PLATFORM_SETTING_CATEGORIES.map((tab) => {
              const active = activeCategory === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveCategory(tab.id as CategoryKey)}
                  className={`rounded-lg px-3 py-1.5 text-xs font-semibold transition-colors cursor-pointer ${
                    active
                      ? "bg-white text-ink shadow-xs"
                      : "text-muted hover:text-ink"
                  }`}
                >
                  {tab.label}
                </button>
              );
            })}
          </div>

          <div className="flex items-center gap-1.5 text-xs">
            <span className="text-muted font-medium mr-1">Nguồn:</span>
            {PLATFORM_SETTING_SOURCES.map((src) => {
              const isSelected = sourceFilter === src.id;
              return (
                <button
                  key={src.id}
                  type="button"
                  onClick={() =>
                    setSourceFilter(src.id as PlatformSettingSourceFilter)
                  }
                  className={`rounded-lg px-2.5 py-1 font-medium transition-colors cursor-pointer ${
                    isSelected
                      ? "bg-brand/10 text-brand font-semibold"
                      : "bg-canvas text-muted hover:text-ink"
                  }`}
                >
                  {src.label}
                </button>
              );
            })}
          </div>
        </div>

        <div className="relative">
          <OpsIcon
            name="search"
            className="pointer-events-none absolute top-1/2 left-3.5 size-4 -translate-y-1/2 text-muted"
          />
          <input
            type="search"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Tìm theo tên tham số, mã khóa (RIDE_MIN, RADIUS...), giá trị hoặc ghi chú..."
            className={`h-10 w-full rounded-xl border border-border bg-white pr-4 pl-10 text-sm text-ink placeholder:text-muted ${focusRing}`}
          />
        </div>
      </div>

      {banner ? (
        <div
          className="flex items-center justify-between rounded-xl border border-danger/30 bg-danger/5 px-4 py-3 text-sm text-danger"
          role="alert"
        >
          <span>{banner}</span>
          <button
            type="button"
            onClick={() => setBanner(null)}
            className="text-xs font-semibold underline hover:no-underline cursor-pointer"
          >
            Đóng
          </button>
        </div>
      ) : null}

      {isError && !forbidden && rows.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách cấu hình hệ thống. Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : null}

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền truy cập cấu hình hệ thống"
          description="Tài khoản quản trị của bạn không có quyền xem hoặc chỉnh sửa tham số hệ thống. Vui lòng liên hệ Super Admin."
        />
      ) : isError && rows.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách cấu hình hệ thống. Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {Array.from({ length: 4 }).map((_, index) => (
            <div
              key={index}
              className="flex min-h-[16rem] flex-col justify-between rounded-2xl border border-border bg-white p-5 shadow-xs animate-pulse"
            >
              <div className="space-y-3">
                <div className="flex items-center gap-3">
                  <div className="size-9 rounded-xl bg-canvas" />
                  <div className="space-y-1.5 flex-1">
                    <div className="h-4 w-1/2 rounded bg-canvas" />
                    <div className="h-3 w-1/3 rounded bg-canvas" />
                  </div>
                </div>
                <div className="h-10 rounded bg-canvas/70" />
                <div className="h-12 rounded-xl bg-canvas" />
              </div>
              <div className="h-8 border-t border-border pt-3" />
            </div>
          ))}
        </div>
      ) : rows.length === 0 ? (
        <AdminEmptyState
          icon="settings"
          title="Không tìm thấy tham số cấu hình"
          description={
            searchQuery.trim() ||
            activeCategory !== "ALL" ||
            sourceFilter !== "ALL"
              ? "Không có tham số nào khớp với bộ lọc và từ khóa tìm kiếm hiện tại."
              : "Chưa có tham số cấu hình hệ thống nào được thiết lập."
          }
          action={
            searchQuery.trim() ||
            activeCategory !== "ALL" ||
            sourceFilter !== "ALL" ? (
              <AdminResetFilterButton
                onClick={() => {
                  setSearchQuery("");
                  setActiveCategory("ALL");
                  setSourceFilter("ALL");
                }}
              />
            ) : undefined
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {rows.map((row) => {
            const category = categorizeSetting(row.key);
            const icon = getSettingIcon(category);
            return (
              <div
                key={row.key}
                className="flex flex-col justify-between rounded-2xl border border-border bg-white p-5 shadow-xs hover:border-brand/30 hover:shadow-sm transition-all"
              >
                <div className="space-y-3">
                  <div className="flex items-start justify-between gap-3">
                    <div className="flex items-center gap-2.5">
                      <span className="grid size-9 shrink-0 place-items-center rounded-xl bg-brand/10 text-brand">
                        <OpsIcon name={icon} className="size-4" />
                      </span>
                      <div className="min-w-0">
                        <h3 className="text-sm font-semibold text-ink truncate">
                          {row.label}
                        </h3>
                        <span className="font-mono text-xs text-muted block truncate">
                          {row.key}
                        </span>
                      </div>
                    </div>
                    <div>
                      {row.source === "db" ? (
                        <StatusChip tone="brand">DB override</StatusChip>
                      ) : (
                        <QuietChip>Env default</QuietChip>
                      )}
                    </div>
                  </div>

                  <p className="text-xs text-muted leading-relaxed min-h-[2.5rem]">
                    {row.hint}
                  </p>

                  <div className="rounded-xl border border-border/80 bg-canvas/80 p-3">
                    <div className="flex items-center justify-between text-xs text-muted">
                      <span>Giá trị hiện tại</span>
                      <span className="font-medium text-ink">
                        {row.valueType}
                      </span>
                    </div>
                    <div className="mt-1 font-mono text-base font-bold text-ink break-all">
                      {row.value || "—"}
                    </div>
                  </div>

                  {row.openIds.length > 0 ? (
                    <div className="flex flex-wrap items-center gap-1.5 pt-1">
                      <span className="text-[11px] text-muted">
                        Quyết định:
                      </span>
                      {row.openIds.map((id) => (
                        <span
                          key={id}
                          className="rounded-md bg-canvas px-1.5 py-0.5 text-[11px] font-medium text-muted border border-border"
                        >
                          {id}
                        </span>
                      ))}
                    </div>
                  ) : null}
                </div>

                <div className="mt-4 flex items-center justify-between border-t border-border pt-3">
                  <span className="text-xs text-muted">
                    {row.updatedAt
                      ? `Cập nhật: ${formatOpsDate(row.updatedAt)}`
                      : "Mặc định từ hệ thống"}
                  </span>
                  <button
                    type="button"
                    onClick={() => openEdit(row)}
                    className={`inline-flex items-center gap-1.5 rounded-xl border border-border bg-white px-3 py-1.5 text-xs font-semibold text-ink hover:bg-canvas hover:text-brand cursor-pointer transition-colors shadow-2xs ${focusRing}`}
                  >
                    <OpsIcon name="sliders" className="size-3.5 text-muted" />
                    Chỉnh sửa
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {draft ? (
        <div
          className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-ink/40 backdrop-blur-xs"
          role="dialog"
          aria-modal="true"
          aria-labelledby="platform-setting-title"
        >
          <div className="w-full max-w-lg space-y-4 rounded-2xl border border-border bg-white p-6 shadow-2xl">
            <div className="flex items-start justify-between gap-3 border-b border-border pb-3">
              <div>
                <span className="inline-block rounded-md bg-brand/10 px-2 py-0.5 text-xs font-bold text-brand">
                  {draft.key}
                </span>
                <h2
                  id="platform-setting-title"
                  className="mt-1 text-lg font-bold text-ink"
                >
                  Chỉnh sửa {draft.label}
                </h2>
              </div>
              <button
                type="button"
                onClick={() => setDraft(null)}
                className="rounded-lg p-1 text-muted hover:bg-canvas hover:text-ink cursor-pointer"
              >
                <OpsIcon name="close" className="size-5" />
              </button>
            </div>

            <label className="block space-y-1.5">
              <span className="text-xs font-semibold text-ink uppercase tracking-wide">
                Giá trị tham số mới
              </span>
              {BOOLEAN_SETTING_KEYS.has(draft.key) ? (
                <div
                  role="radiogroup"
                  aria-label="Giá trị tham số mới"
                  className="flex gap-2"
                >
                  {(
                    [
                      ["true", "Bật"],
                      ["false", "Tắt"],
                    ] as const
                  ).map(([value, label]) => (
                    <button
                      key={value}
                      type="button"
                      role="radio"
                      aria-checked={editValue.trim() === value}
                      onClick={() => setEditValue(value)}
                      className={`inline-flex h-10 flex-1 items-center justify-center rounded-xl border text-sm font-semibold cursor-pointer ${
                        editValue.trim() === value
                          ? "border-brand bg-brand/10 text-brand"
                          : "border-border bg-white text-ink"
                      } ${focusRing}`}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              ) : (
                <textarea
                  value={editValue}
                  onChange={(event) => setEditValue(event.target.value)}
                  rows={3}
                  placeholder="Nhập giá trị mới..."
                  className={`w-full rounded-xl border border-border bg-canvas/30 px-3 py-2 font-mono text-sm text-ink ${focusRing}`}
                />
              )}
            </label>

            <label className="block space-y-1.5">
              <span className="text-xs font-semibold text-ink uppercase tracking-wide">
                Lý do thay đổi (bắt buộc cho Audit Log)
              </span>
              <textarea
                value={reason}
                onChange={(event) => setReason(event.target.value)}
                rows={2}
                placeholder="Ví dụ: Cập nhật giá cước theo đợt cao điểm hoặc quy định điều phối mới..."
                className={`w-full rounded-xl border border-border bg-canvas/30 px-3 py-2 text-sm text-ink ${focusRing}`}
              />
              <p className="text-[11px] text-muted">
                Tối thiểu 3 ký tự. Thông tin này sẽ được lưu vĩnh viễn trong
                nhật ký kiểm toán hệ thống.
              </p>
            </label>

            <div className="flex flex-wrap justify-end gap-2 border-t border-border pt-4">
              <button
                type="button"
                className={`h-10 rounded-xl border border-border bg-canvas px-4 text-xs font-semibold text-ink hover:bg-border/60 cursor-pointer ${focusRing}`}
                disabled={patchMutation.isPending}
                onClick={() => setDraft(null)}
              >
                Hủy bỏ
              </button>
              <button
                type="button"
                className={`h-10 rounded-xl bg-brand px-5 text-xs font-semibold text-white shadow-xs hover:bg-brand/90 disabled:opacity-60 cursor-pointer ${focusRing}`}
                disabled={patchMutation.isPending}
                onClick={requestSave}
              >
                {patchMutation.isPending
                  ? "Đang lưu cấu hình..."
                  : "Tiếp tục & Lưu"}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <ConfirmDialog
        open={confirmSave && Boolean(draft)}
        title="Xác nhận lưu cấu hình hệ thống"
        description={
          draft
            ? `Bạn có chắc chắn muốn cập nhật giá trị mới cho tham số “${draft.label}” (${draft.key})? Thay đổi này sẽ ảnh hưởng tới toàn bộ ứng dụng và backend.`
            : undefined
        }
        confirmLabel="Xác nhận lưu"
        tone="brand"
        pending={patchMutation.isPending}
        onClose={() => setConfirmSave(false)}
        onConfirm={save}
      />
    </div>
  );
}
