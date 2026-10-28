"use client";

import { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  countFormat,
  focusRing,
  ListPager,
  StatusChip,
  type PageSize,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminFilterField,
  AdminFilterToolbar,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
} from "@/components/ui/admin-state-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { ReasonDialog } from "@/components/ui/reason-dialog";
import { toast } from "@/components/ui/toast";
import { isForbiddenError } from "@/lib/api/errors";
import { formatOpsDateTime } from "@/lib/ops-time";
import {
  useReviewsFilters,
  useReviewsQuery,
  useSetReviewHiddenMutation,
} from "@/features/reviews/hooks";
import type { StoreReview } from "@/features/reviews/types";

const VISIBILITY_OPTIONS = [
  { value: "VISIBLE", label: "Đang hiển thị" },
  { value: "HIDDEN", label: "Đã ẩn" },
];

const STAR_OPTIONS = [
  { value: "1", label: "1 sao" },
  { value: "2", label: "Từ 2 sao trở xuống" },
  { value: "3", label: "Từ 3 sao trở xuống" },
];

function Stars({ value }: { value: number }) {
  return (
    <span className="inline-flex items-center gap-0.5" aria-label={`${value} sao`}>
      {[1, 2, 3, 4, 5].map((n) => (
        <span
          key={n}
          className={n <= value ? "text-amber-500" : "text-border"}
        >
          ★
        </span>
      ))}
    </span>
  );
}

export function ReviewsBoard() {
  const [filters, setFilters] = useReviewsFilters();
  const { data, isPending, isError, error, refetch } = useReviewsQuery();
  const forbidden = isError && isForbiddenError(error);
  const mutation = useSetReviewHiddenMutation();
  const [target, setTarget] = useState<StoreReview | null>(null);

  const items = data?.items ?? [];
  const total = data?.total ?? 0;
  const pageSize = (filters.limit as PageSize) || 10;
  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(filters.page, lastPage);

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Danh mục", href: "/catalog" },
          { label: "Đánh giá quán" },
        ]}
      />
      <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
        Đánh giá quán
      </h1>

      {forbidden ? (
        <AdminForbiddenState />
      ) : (
        <section className="min-w-0 rounded-2xl border border-border bg-white p-4 shadow-sm">
          {isError && items.length > 0 ? (
            <AdminListErrorBanner
              message={error instanceof Error ? error.message : "Không tải được dữ liệu."}
              onRetry={() => void refetch()}
            />
          ) : null}
          <AdminFilterToolbar>
            <AdminFilterField>
              <SearchSelect
                label="Trạng thái"
                value={filters.visibility || null}
                options={VISIBILITY_OPTIONS}
                placeholder="Tất cả"
                onChange={(v) => void setFilters({ visibility: v ?? "", page: 1 })}
              />
            </AdminFilterField>
            <AdminFilterField>
              <SearchSelect
                label="Số sao"
                value={filters.maxStars || null}
                options={STAR_OPTIONS}
                placeholder="Tất cả"
                onChange={(v) => void setFilters({ maxStars: v ?? "", page: 1 })}
              />
            </AdminFilterField>
            <AdminFilterField grow>
              <label htmlFor="reviews-search-input" className="text-xs font-medium text-muted">
                Tìm trong nội dung
              </label>
              <div className="relative mt-1.5">
                <OpsIcon
                  name="search"
                  className="pointer-events-none absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted"
                />
                <input
                  id="reviews-search-input"
                  value={filters.q}
                  onChange={(e) => void setFilters({ q: e.target.value, page: 1 })}
                  className={`h-10 w-full rounded-xl border border-border bg-white pr-3 pl-9 text-sm text-ink ${focusRing}`}
                />
              </div>
            </AdminFilterField>
            <AdminResetFilterButton
              onClick={() =>
                void setFilters({ q: "", visibility: "", maxStars: "", storeId: "", page: 1 })
              }
            />
          </AdminFilterToolbar>

          <ul className="mt-4 divide-y divide-border" data-testid="reviews-list">
            {isPending ? (
              <li className="py-10 text-center text-sm text-muted">Đang tải…</li>
            ) : items.length === 0 ? (
              <li>
                <AdminEmptyState
                  icon="search"
                  title="Chưa có đánh giá"
                  description="Không có đánh giá khớp bộ lọc."
                />
              </li>
            ) : (
              items.map((review) => (
                <li key={review.id} className="flex flex-col gap-2 py-4 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0 space-y-1.5">
                    <div className="flex flex-wrap items-center gap-2 text-sm">
                      <span className="font-semibold text-ink">{review.storeName}</span>
                      <Stars value={review.stars} />
                      <span className="text-xs text-muted">{formatOpsDateTime(review.createdAt)}</span>
                      {review.hidden ? <StatusChip tone="danger">Đã ẩn</StatusChip> : null}
                    </div>
                    {review.comment ? (
                      <p className="text-sm leading-relaxed break-words text-ink">{review.comment}</p>
                    ) : null}
                    {review.tags.length > 0 ? (
                      <div className="flex flex-wrap gap-1.5">
                        {review.tags.map((tag) => (
                          <span key={tag} className="rounded-full bg-canvas px-2 py-0.5 text-xs text-muted">
                            {tag}
                          </span>
                        ))}
                      </div>
                    ) : null}
                    {review.merchantReply ? (
                      <p className="rounded-lg bg-canvas px-3 py-2 text-xs break-words text-ink">
                        <span className="font-semibold">Quán trả lời: </span>
                        {review.merchantReply}
                      </p>
                    ) : null}
                    {review.hidden && review.hiddenReason ? (
                      <p className="text-xs text-rose-700">Lý do ẩn: {review.hiddenReason}</p>
                    ) : null}
                  </div>
                  <button
                    type="button"
                    disabled={mutation.isPending}
                    onClick={() => setTarget(review)}
                    data-testid={`review-toggle-${review.id}`}
                    className={`inline-flex h-8 shrink-0 items-center gap-1.5 rounded-lg border px-3 text-xs font-semibold transition-colors disabled:opacity-50 ${
                      review.hidden
                        ? "border-emerald-300 bg-emerald-50 text-emerald-800 hover:bg-emerald-100"
                        : "border-rose-300 bg-rose-50 text-rose-800 hover:bg-rose-100"
                    } ${focusRing}`}
                  >
                    {review.hidden ? "Hiện lại" : "Ẩn đánh giá"}
                  </button>
                </li>
              ))
            )}
          </ul>
          <ListPager
            page={currentPage}
            pageSize={pageSize}
            summary={`Hiển thị ${items.length} / ${countFormat.format(total)} đánh giá`}
            label="Phân trang đánh giá"
            onPageChange={(p) => void setFilters({ page: p })}
            onPageSizeChange={(size) => void setFilters({ limit: size, page: 1 })}
            lastPage={lastPage}
          />
        </section>
      )}

      <ReasonDialog
        open={target !== null}
        title={target?.hidden ? "Hiện lại đánh giá" : "Ẩn đánh giá"}
        description={target ? `${target.storeName} · ${target.stars} sao` : ""}
        confirmLabel={target?.hidden ? "Hiện lại" : "Ẩn"}
        tone={target?.hidden ? "brand" : "danger"}
        testId="review-visibility-dialog"
        onClose={() => setTarget(null)}
        onSubmit={async (reason) => {
          if (!target) return;
          await mutation.mutateAsync({ id: target.id, hidden: !target.hidden, reason });
          toast.success(target.hidden ? "Đã hiện lại đánh giá" : "Đã ẩn đánh giá");
        }}
      />
    </div>
  );
}
