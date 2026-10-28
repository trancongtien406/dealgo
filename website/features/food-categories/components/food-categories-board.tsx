"use client";

import { useMemo, useState, type DragEvent } from "react";
import {
  AdminBreadcrumb,
  QuietChip,
  StatusChip,
  focusRing,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { toast } from "@/components/ui/toast";
import {
  FOOD_CATEGORY_ICON_PHOTO,
  FOOD_CATEGORY_IMAGE_MAX_BYTES,
  FOOD_CATEGORY_PHOTOS,
  FOOD_CATEGORY_PHOTO_ICONS,
  FOOD_CATEGORY_TONE_META,
  checkFoodCategoryDraft,
  diffFoodCategoryPayload,
  draftFromFoodCategory,
  emptyFoodCategoryDraft,
  foodCategoryDefaultPhoto,
  foodCategoryImageSrc,
  foodCategoryPhotoSrc,
  moveFoodCategoryCode,
  previewFoodCategoryCode,
  suggestFoodCategoryLook,
} from "@/features/food-categories/form";
import {
  useCreateFoodCategoryMutation,
  useDeleteFoodCategoryMutation,
  useFoodCategoriesQuery,
  usePatchFoodCategoryMutation,
  useReorderFoodCategoriesMutation,
  useUploadFoodCategoryImageMutation,
} from "@/features/food-categories/hooks";
import {
  FOOD_CATEGORY_TONES,
  type FoodCategoryDraft,
  type FoodCategoryIcon,
  type FoodCategoryRow,
  type FoodCategoryTone,
} from "@/features/food-categories/types";
import { countFormat } from "@/lib/admin-format";
import { ApiError, isForbiddenError } from "@/lib/api/errors";

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof ApiError ? error.message : fallback;
}

/** The app tile: the uploaded image, otherwise the bundled default photo. */
export function FoodCategoryTile({
  code,
  icon,
  tone,
  imageSrc,
  name,
  size = "md",
}: {
  code: string | null;
  icon: FoodCategoryIcon;
  tone: FoodCategoryTone;
  imageSrc: string | null;
  name: string;
  size?: "sm" | "md";
}) {
  const palette = FOOD_CATEGORY_TONE_META[tone];
  const box = size === "sm" ? "size-11" : "size-14";
  const src = imageSrc ?? foodCategoryPhotoSrc(foodCategoryDefaultPhoto(code, icon));
  return (
    <span
      className={`grid shrink-0 place-items-center overflow-hidden rounded-2xl ${box}`}
      style={{ background: palette.bg }}
    >
      {/* eslint-disable-next-line @next/next/no-img-element */}
      <img src={src} alt={name} className="size-full object-cover" />
    </span>
  );
}

export function FoodCategoriesBoard() {
  const { data, isPending, isError, error, refetch } = useFoodCategoriesQuery();
  const forbidden = isError && isForbiddenError(error);
  const rows = useMemo(() => data ?? [], [data]);
  const patchMutation = usePatchFoodCategoryMutation();
  const deleteMutation = useDeleteFoodCategoryMutation();
  const reorderMutation = useReorderFoodCategoriesMutation();
  const [editing, setEditing] = useState<FoodCategoryRow | "new" | null>(null);
  const [deleting, setDeleting] = useState<FoodCategoryRow | null>(null);
  const [dragging, setDragging] = useState<string | null>(null);
  const [over, setOver] = useState<string | null>(null);
  const busy = patchMutation.isPending || reorderMutation.isPending;
  const activeCount = rows.filter((r) => r.active).length;
  const storeTotal = rows.reduce((sum, r) => sum + r.storeCount, 0);

  const reorder = (next: string[] | null) => {
    if (!next || busy) return;
    reorderMutation.mutate(next, {
      onError: (e) => toast.error(errorMessage(e, "Không đổi được thứ tự.")),
    });
  };
  const codes = rows.map((r) => r.code);
  const move = (code: string, delta: -1 | 1) => {
    const at = codes.indexOf(code);
    const target = codes[at + delta];
    if (target) reorder(moveFoodCategoryCode(codes, code, target));
  };
  const onDrop = (event: DragEvent, target: string) => {
    event.preventDefault();
    const from = dragging ?? event.dataTransfer.getData("text/plain");
    setDragging(null);
    setOver(null);
    if (from) reorder(moveFoodCategoryCode(codes, from, target));
  };

  const toggle = (row: FoodCategoryRow) => {
    if (busy) return;
    patchMutation.mutate(
      { code: row.code, patch: { active: !row.active } },
      {
        onSuccess: () =>
          toast.success(
            row.active
              ? `Đã ẩn “${row.nameVi}” khỏi app.`
              : `Đã hiện “${row.nameVi}” trên app.`,
          ),
        onError: (e) =>
          toast.error(errorMessage(e, "Không cập nhật được danh mục.")),
      },
    );
  };

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Danh mục", href: "/catalog" },
          { label: "Ngành hàng đồ ăn" },
        ]}
      />
      <div className="flex flex-wrap items-end justify-between gap-3">
        <div>
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Ngành hàng đồ ăn
          </h1>
          <p className="mt-1 max-w-2xl text-sm text-muted">
            Danh mục hiện trên trang chủ app, bộ lọc Đồ ăn và trong cài đặt cửa
            hàng. Kéo thả để đổi thứ tự; tắt để ẩn khỏi app mà không ảnh hưởng
            cửa hàng đang dùng.
          </p>
        </div>
        <button
          type="button"
          className={`h-10 rounded-xl bg-brand px-4 text-sm font-semibold text-white ${focusRing}`}
          onClick={() => setEditing("new")}
        >
          Thêm danh mục
        </button>
      </div>
      {rows.length > 0 ? (
        <div className="flex flex-wrap gap-2 text-sm">
          <QuietChip>{countFormat.format(rows.length)} danh mục</QuietChip>
          <QuietChip>{countFormat.format(activeCount)} đang hiện</QuietChip>
          <QuietChip>{countFormat.format(storeTotal)} cửa hàng đã gán</QuietChip>
        </div>
      ) : null}

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý danh mục"
          description="Tài khoản của bạn cần quyền catalog.write để sửa ngành hàng."
        />
      ) : isError && rows.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh mục. Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <ul className="space-y-2">
          {Array.from({ length: 5 }).map((_, idx) => (
            <li
              key={idx}
              className="flex animate-pulse items-center gap-4 rounded-2xl border border-border bg-white p-3 shadow-sm"
            >
              <div className="size-14 rounded-2xl bg-canvas" />
              <div className="flex-1 space-y-2">
                <div className="h-4 w-1/3 rounded bg-canvas" />
                <div className="h-3 w-1/2 rounded bg-canvas/70" />
              </div>
            </li>
          ))}
        </ul>
      ) : rows.length === 0 ? (
        <AdminEmptyState
          icon="categories"
          title="Chưa có danh mục"
          description="Thêm danh mục để khách lọc quán và chủ quán chọn ngành hàng."
        />
      ) : (
        <ul className="space-y-2" aria-label="Danh mục — kéo thả để sắp xếp">
          {rows.map((row, index) => (
            <li
              key={row.code}
              draggable={!busy}
              onDragStart={(e) => {
                setDragging(row.code);
                e.dataTransfer.effectAllowed = "move";
                e.dataTransfer.setData("text/plain", row.code);
              }}
              onDragEnd={() => {
                setDragging(null);
                setOver(null);
              }}
              onDragOver={(e) => {
                e.preventDefault();
                if (over !== row.code) setOver(row.code);
              }}
              onDrop={(e) => onDrop(e, row.code)}
              className={`flex items-center gap-3 rounded-2xl border bg-white p-3 shadow-sm transition ${
                over === row.code && dragging && dragging !== row.code
                  ? "border-brand ring-2 ring-brand/20"
                  : "border-border"
              } ${dragging === row.code ? "opacity-50" : ""} ${
                row.active ? "" : "bg-canvas/60"
              }`}
            >
              <span
                className="cursor-grab select-none px-1 text-lg text-muted active:cursor-grabbing"
                title="Kéo để sắp xếp"
                aria-hidden
              >
                ⠿
              </span>
              <FoodCategoryTile
                code={row.code}
                icon={row.icon}
                tone={row.tone}
                imageSrc={foodCategoryImageSrc(row.imageUrl)}
                name={row.nameVi}
              />
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <h2 className="truncate text-base font-semibold text-ink">
                    {row.nameVi}
                  </h2>
                  <StatusChip tone={row.active ? "success" : "food"} dot>
                    {row.active ? "Đang hiện" : "Đang ẩn"}
                  </StatusChip>
                </div>
                <p className="truncate text-xs text-muted">
                  {row.nameEn} · mã <code>{row.code}</code> ·{" "}
                  {countFormat.format(row.storeCount)} cửa hàng
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-1.5">
                <button
                  type="button"
                  aria-label={`Đưa ${row.nameVi} lên`}
                  disabled={index === 0 || busy}
                  className={`size-9 rounded-xl border border-border text-sm disabled:opacity-40 ${focusRing}`}
                  onClick={() => move(row.code, -1)}
                >
                  ↑
                </button>
                <button
                  type="button"
                  aria-label={`Đưa ${row.nameVi} xuống`}
                  disabled={index === rows.length - 1 || busy}
                  className={`size-9 rounded-xl border border-border text-sm disabled:opacity-40 ${focusRing}`}
                  onClick={() => move(row.code, 1)}
                >
                  ↓
                </button>
                <button
                  type="button"
                  role="switch"
                  aria-checked={row.active}
                  aria-label={`Hiện ${row.nameVi} trên app`}
                  disabled={busy}
                  onClick={() => toggle(row)}
                  className={`relative h-6 w-11 rounded-full transition disabled:opacity-50 ${
                    row.active ? "bg-brand" : "bg-border"
                  } ${focusRing}`}
                >
                  <span
                    className={`absolute top-0.5 size-5 rounded-full bg-white shadow transition-all ${
                      row.active ? "left-[22px]" : "left-0.5"
                    }`}
                  />
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
                  disabled={row.storeCount > 0}
                  title={
                    row.storeCount > 0
                      ? "Còn cửa hàng dùng danh mục này — hãy tắt thay vì xoá"
                      : undefined
                  }
                  className={`h-9 rounded-xl border border-danger/30 px-3 text-sm font-medium text-danger disabled:opacity-40 ${focusRing}`}
                  onClick={() => setDeleting(row)}
                >
                  Xoá
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}

      <ConfirmDialog
        open={deleting !== null}
        title={`Xoá “${deleting?.nameVi ?? ""}”?`}
        description="Danh mục biến mất khỏi app và bộ lọc. Không hoàn tác được."
        confirmLabel="Xoá"
        pending={deleteMutation.isPending}
        onClose={() => setDeleting(null)}
        onConfirm={() => {
          if (!deleting) return;
          deleteMutation.mutate(deleting.code, {
            onSuccess: () => {
              setDeleting(null);
              toast.success("Đã xoá danh mục.");
            },
            onError: (e) =>
              toast.error(errorMessage(e, "Không xoá được danh mục.")),
          });
        }}
      />
      {editing ? (
        <FoodCategoryEditor
          row={editing === "new" ? null : editing}
          takenCodes={codes}
          onClose={() => setEditing(null)}
        />
      ) : null}
    </div>
  );
}

function FoodCategoryEditor({
  row,
  takenCodes,
  onClose,
}: {
  row: FoodCategoryRow | null;
  takenCodes: string[];
  onClose: () => void;
}) {
  const [draft, setDraft] = useState<FoodCategoryDraft>(() =>
    row ? draftFromFoodCategory(row) : emptyFoodCategoryDraft(),
  );
  // Until the admin picks a look by hand, typing a name suggests one.
  const [lookTouched, setLookTouched] = useState(row !== null);
  const [file, setFile] = useState<{ name: string; dataUrl: string } | null>(
    null,
  );
  const [removeImage, setRemoveImage] = useState(false);
  const [problem, setProblem] = useState<string | null>(null);
  const createMutation = useCreateFoodCategoryMutation();
  const patchMutation = usePatchFoodCategoryMutation();
  const uploadMutation = useUploadFoodCategoryImageMutation();
  const pending =
    createMutation.isPending ||
    patchMutation.isPending ||
    uploadMutation.isPending;
  const savedImage = removeImage ? null : foodCategoryImageSrc(row?.imageUrl ?? null);
  const previewSrc = file?.dataUrl ?? savedImage;
  const code = row?.code ?? previewFoodCategoryCode(draft.nameVi, takenCodes);
  const set = <K extends keyof FoodCategoryDraft>(
    key: K,
    value: FoodCategoryDraft[K],
  ) => setDraft((d) => ({ ...d, [key]: value }));

  const setName = (nameVi: string) => {
    const look = lookTouched ? null : suggestFoodCategoryLook(nameVi);
    setDraft((d) => ({ ...d, nameVi, ...(look ?? {}) }));
  };

  const pickFile = async (picked: File | undefined) => {
    setProblem(null);
    if (!picked) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(picked.type)) {
      setProblem("Chọn ảnh JPEG, PNG hoặc WebP.");
      return;
    }
    if (picked.size > FOOD_CATEGORY_IMAGE_MAX_BYTES) {
      setProblem("Ảnh tối đa 1 MB.");
      return;
    }
    try {
      setFile({ name: picked.name, dataUrl: await readDataUrl(picked) });
      setRemoveImage(false);
    } catch {
      setProblem("Không đọc được ảnh.");
    }
  };

  const save = async () => {
    const check = checkFoodCategoryDraft(draft);
    if (!check.ok) {
      setProblem(check.message);
      return;
    }
    setProblem(null);
    try {
      let saved = row?.code;
      if (!row) {
        saved = (await createMutation.mutateAsync(check.payload)).code;
      } else {
        const patch = {
          ...diffFoodCategoryPayload(row, check.payload),
          ...(removeImage && row.imageUrl && !file ? { imageUrl: null } : {}),
        };
        if (Object.keys(patch).length > 0) {
          await patchMutation.mutateAsync({ code: row.code, patch });
        }
      }
      if (file && saved) {
        await uploadMutation.mutateAsync({ code: saved, dataUrl: file.dataUrl });
      }
      toast.success(row ? "Đã lưu danh mục." : "Đã thêm danh mục.");
      onClose();
    } catch (e) {
      setProblem(errorMessage(e, "Không lưu được danh mục."));
    }
  };

  const input = `mt-1 block h-10 w-full rounded-xl border border-border bg-white px-3 text-sm ${focusRing}`;
  return (
    <div
      className="fixed inset-0 z-50 grid place-items-center bg-ink/40 p-4"
      role="dialog"
      aria-modal="true"
      aria-label={row ? "Sửa danh mục" : "Thêm danh mục"}
    >
      <div className="grid max-h-[92vh] w-full max-w-3xl gap-5 overflow-y-auto rounded-2xl border border-border bg-white p-5 shadow-lg md:grid-cols-[1fr_240px]">
        <div className="space-y-4">
          <h2 className="text-lg font-semibold text-ink">
            {row ? "Sửa danh mục" : "Thêm danh mục"}
          </h2>
          <label className="block text-sm font-medium text-ink">
            Tên danh mục *
            <input
              autoFocus
              className={input}
              maxLength={60}
              placeholder="Ví dụ: Bún bò Huế"
              value={draft.nameVi}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <p className="-mt-2 text-xs text-muted">
            Mã đường dẫn {row ? "(cố định)" : "(tự tạo)"}:{" "}
            <code className="rounded bg-canvas px-1.5 py-0.5 text-ink">{code}</code>
          </p>
          <label className="block text-sm font-medium text-ink">
            Tên tiếng Anh (tuỳ chọn)
            <input
              className={input}
              maxLength={60}
              placeholder={draft.nameVi.trim() || "Để trống sẽ dùng tên tiếng Việt"}
              value={draft.nameEn}
              onChange={(e) => set("nameEn", e.target.value)}
            />
          </label>
          <fieldset>
            <legend className="text-sm font-medium text-ink">Ảnh mặc định</legend>
            <div className="mt-1 grid grid-cols-5 gap-1.5 sm:grid-cols-9">
              {FOOD_CATEGORY_PHOTO_ICONS.map((key) => (
                <button
                  key={key}
                  type="button"
                  title={FOOD_CATEGORY_PHOTOS[FOOD_CATEGORY_ICON_PHOTO[key]]}
                  aria-label={FOOD_CATEGORY_PHOTOS[FOOD_CATEGORY_ICON_PHOTO[key]]}
                  aria-pressed={FOOD_CATEGORY_ICON_PHOTO[draft.icon] === FOOD_CATEGORY_ICON_PHOTO[key]}
                  onClick={() => {
                    setLookTouched(true);
                    set("icon", key);
                  }}
                  className={`size-12 overflow-hidden rounded-xl border-2 transition ${
                    FOOD_CATEGORY_ICON_PHOTO[draft.icon] === FOOD_CATEGORY_ICON_PHOTO[key]
                      ? "border-brand ring-2 ring-brand/20"
                      : "border-transparent hover:border-border"
                  } ${focusRing}`}
                >
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={foodCategoryPhotoSrc(FOOD_CATEGORY_ICON_PHOTO[key])}
                    alt=""
                    className="size-full object-cover"
                  />
                </button>
              ))}
            </div>
          </fieldset>
          <fieldset>
            <legend className="text-sm font-medium text-ink">Màu nền</legend>
            <div className="mt-1 flex flex-wrap gap-2">
              {FOOD_CATEGORY_TONES.map((tone) => (
                <button
                  key={tone}
                  type="button"
                  title={FOOD_CATEGORY_TONE_META[tone].label}
                  aria-label={FOOD_CATEGORY_TONE_META[tone].label}
                  aria-pressed={draft.tone === tone}
                  onClick={() => {
                    setLookTouched(true);
                    set("tone", tone);
                  }}
                  className={`size-8 rounded-full border-2 transition ${
                    draft.tone === tone ? "border-ink scale-110" : "border-white shadow"
                  } ${focusRing}`}
                  style={{ background: FOOD_CATEGORY_TONE_META[tone].fg }}
                />
              ))}
            </div>
          </fieldset>
          <div className="text-sm font-medium text-ink">
            Ảnh riêng (thay ảnh mặc định)
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <label
                className={`inline-flex h-9 cursor-pointer items-center rounded-xl border border-border px-3 text-sm ${focusRing}`}
              >
                {previewSrc ? "Đổi ảnh" : "Chọn ảnh"}
                <input
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  className="sr-only"
                  onChange={(e) => void pickFile(e.target.files?.[0])}
                />
              </label>
              {previewSrc ? (
                <button
                  type="button"
                  className={`h-9 rounded-xl border border-danger/30 px-3 text-sm text-danger ${focusRing}`}
                  onClick={() => {
                    setFile(null);
                    setRemoveImage(true);
                  }}
                >
                  Bỏ ảnh
                </button>
              ) : null}
              <span className="text-xs font-normal text-muted">
                Vuông, JPEG/PNG/WebP ≤ 1 MB.
              </span>
            </div>
          </div>
          <label className="flex items-center gap-2 text-sm text-ink">
            <input
              type="checkbox"
              checked={draft.active}
              onChange={(e) => set("active", e.target.checked)}
            />
            Hiện trên app
          </label>
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
          <div className="rounded-[28px] border border-border bg-canvas p-4">
            <div className="flex flex-col items-center gap-1.5">
              <FoodCategoryTile
                code={code}
                icon={draft.icon}
                tone={draft.tone}
                imageSrc={previewSrc}
                name={draft.nameVi}
              />
              <span className="max-w-full truncate text-xs font-medium text-ink">
                {draft.nameVi.trim() || "Tên danh mục"}
              </span>
            </div>
            <div className="mt-4 flex flex-wrap justify-center gap-1.5">
              <span className="rounded-full border border-border bg-white px-3 py-1 text-xs text-muted">
                Gần bạn
              </span>
              <span
                className="rounded-full px-3 py-1 text-xs font-semibold"
                style={{
                  background: FOOD_CATEGORY_TONE_META[draft.tone].bg,
                  color: FOOD_CATEGORY_TONE_META[draft.tone].fg,
                }}
              >
                {draft.nameVi.trim() || "Danh mục"}
              </span>
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
