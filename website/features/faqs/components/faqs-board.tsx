"use client";

import { useState } from "react";
import {
  AdminBreadcrumb,
  QuietChip,
  focusRing,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
} from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { toast } from "@/components/ui/toast";
import { useFaqsQuery, usePatchFaqMutation } from "@/features/faqs/hooks";
import { faqCategoryLabel, faqStatusLabel } from "@/features/faqs/mappers";
import type { FaqRow, FaqStatus } from "@/features/faqs/types";
import { FAQ_FILTER_TABS } from "@/features/faqs/constants";
import { ApiError, isForbiddenError } from "@/lib/api/errors";

export function FaqsBoard() {
  const [filter, setFilter] = useState<"all" | FaqStatus>("all");
  const { data, isPending, isError, error, refetch } = useFaqsQuery(
    filter === "all" ? undefined : filter,
  );
  const forbidden = isError && isForbiddenError(error);
  const patchMutation = usePatchFaqMutation();
  const [activeId, setActiveId] = useState<string | null>(null);
  const [answer, setAnswer] = useState("");
  const [reason, setReason] = useState("");
  const [banner, setBanner] = useState<string | null>(null);
  const [confirmPublish, setConfirmPublish] = useState(false);
  const rows = data ?? [];

  const openEdit = (row: FaqRow) => {
    setBanner(null);
    setConfirmPublish(false);
    setActiveId(row.id);
    setAnswer(row.suggestedAnswer);
    setReason("");
  };

  const save = (status?: FaqStatus) => {
    if (!activeId || patchMutation.isPending) {
      return;
    }
    const trimmedReason = reason.trim();
    if (trimmedReason.length < 3) {
      setBanner("Lý do phải từ 3 ký tự.");
      setConfirmPublish(false);
      return;
    }
    patchMutation.mutate(
      {
        id: activeId,
        suggestedAnswer: answer,
        status,
        reason: trimmedReason,
      },
      {
        onSuccess: () => {
          setActiveId(null);
          setConfirmPublish(false);
          toast.success(
            status === "PUBLISHED" ? "Đã xuất bản FAQ nội bộ." : "Đã lưu FAQ.",
          );
        },
        onError: (error) => {
          const message =
            error instanceof ApiError ? error.message : "Không lưu được FAQ.";
          setBanner(message);
          toast.error(message);
          setConfirmPublish(false);
        },
      },
    );
  };

  const requestPublish = () => {
    if (!activeId || patchMutation.isPending) {
      return;
    }
    if (reason.trim().length < 3) {
      setBanner("Lý do phải từ 3 ký tự.");
      return;
    }
    setConfirmPublish(true);
  };

  return (
    <div className="min-w-0 space-y-5">
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cài đặt & Nhật ký", href: "/settings" },
          { label: "Câu hỏi thường gặp (FAQ)" },
        ]}
      />
      <div>
        <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
          Quản lý câu hỏi thường gặp (FAQ)
        </h1>
        <p className="mt-1 max-w-2xl text-sm text-muted">
          Soạn thảo và phát hành nội dung giải đáp thắc mắc dành cho khách hàng,
          tài xế và đối tác cửa hàng.
        </p>
      </div>
      <ConfirmDialog
        open={confirmPublish}
        title="Xác nhận xuất bản FAQ"
        description="Nội dung câu hỏi và câu trả lời sẽ được cập nhật công khai trên trung tâm trợ giúp."
        confirmLabel="Xuất bản"
        tone="brand"
        pending={patchMutation.isPending}
        onClose={() => setConfirmPublish(false)}
        onConfirm={() => save("PUBLISHED")}
      />
      <div className="flex flex-wrap gap-2">
        {FAQ_FILTER_TABS.map((tab) => (
          <button
            key={tab.value}
            type="button"
            className={`h-9 rounded-full border px-3 text-sm font-medium ${
              filter === tab.value
                ? "border-brand bg-brand/10 text-brand"
                : "border-border bg-white text-ink"
            } ${focusRing}`}
            onClick={() => setFilter(tab.value)}
          >
            {tab.label}
          </button>
        ))}
      </div>
      {banner ? (
        <p
          className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-danger"
          role="alert"
        >
          {banner}
        </p>
      ) : null}
      {isError && !forbidden && rows.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách câu hỏi thường gặp (FAQ). Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : null}

      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền quản lý FAQ"
          description="Tài khoản quản trị của bạn không có quyền xem hoặc sửa các câu hỏi thường gặp. Vui lòng liên hệ quản trị viên."
        />
      ) : isError && rows.length === 0 ? (
        <AdminListErrorBanner
          message="Không thể tải danh sách câu hỏi thường gặp (FAQ). Vui lòng thử lại sau."
          onRetry={() => void refetch()}
        />
      ) : isPending ? (
        <ul className="space-y-3">
          {Array.from({ length: 3 }).map((_, idx) => (
            <li
              key={idx}
              className="rounded-2xl border border-border bg-white p-4 shadow-sm animate-pulse"
            >
              <div className="space-y-2.5">
                <div className="flex gap-2">
                  <div className="h-5 w-16 rounded-full bg-canvas" />
                  <div className="h-5 w-20 rounded-full bg-canvas" />
                </div>
                <div className="h-5 w-1/2 rounded bg-canvas" />
                <div className="h-4 w-3/4 rounded bg-canvas/70" />
              </div>
            </li>
          ))}
        </ul>
      ) : rows.length === 0 ? (
        <AdminEmptyState
          icon="headset"
          title="Không có câu hỏi thường gặp"
          description={
            filter !== "all"
              ? "Không có FAQ nào khớp với bộ lọc trạng thái hiện tại."
              : "Chưa có câu hỏi thường gặp nào được tạo trên hệ thống."
          }
          action={
            filter !== "all" ? (
              <AdminResetFilterButton onClick={() => setFilter("all")} />
            ) : undefined
          }
        />
      ) : (
        <ul className="space-y-3">
          {rows.map((row) => (
            <li
              key={row.id}
              className="rounded-2xl border border-border bg-white p-4 shadow-sm"
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div className="min-w-0 space-y-1">
                  <div className="flex flex-wrap gap-2">
                    {row.openId ? (
                      <StatusChip tone="brand">{row.openId}</StatusChip>
                    ) : null}
                    <QuietChip>{faqCategoryLabel(row.category)}</QuietChip>
                    <StatusChip
                      tone={row.status === "PUBLISHED" ? "success" : "food"}
                    >
                      {faqStatusLabel(row.status)}
                    </StatusChip>
                  </div>
                  <h2 className="text-base font-semibold text-ink">
                    {row.question}
                  </h2>
                  <p className="whitespace-pre-wrap text-sm leading-6 text-muted">
                    {row.suggestedAnswer}
                  </p>
                </div>
                <button
                  type="button"
                  className={`h-10 shrink-0 rounded-xl border border-border px-3 text-sm font-medium text-ink ${focusRing}`}
                  onClick={() => openEdit(row)}
                >
                  Chỉnh / duyệt
                </button>
              </div>
            </li>
          ))}
        </ul>
      )}
      {activeId ? (
        <div
          className="fixed inset-0 z-50 grid place-items-center bg-ink/40 p-4"
          role="dialog"
          aria-modal="true"
        >
          <div className="max-h-[90vh] w-full max-w-2xl space-y-3 overflow-y-auto rounded-2xl border border-border bg-white p-5 shadow-lg">
            <h2 className="text-lg font-semibold text-ink">
              Sửa câu trả lời gợi ý
            </h2>
            <textarea
              value={answer}
              onChange={(event) => setAnswer(event.target.value)}
              rows={12}
              className={`w-full rounded-xl border border-border px-3 py-2 text-sm leading-6 text-ink ${focusRing}`}
            />
            <textarea
              value={reason}
              onChange={(event) => setReason(event.target.value)}
              rows={2}
              placeholder="Lý do thay đổi (audit)"
              className={`w-full rounded-xl border border-border px-3 py-2 text-sm text-ink ${focusRing}`}
            />
            <div className="flex flex-wrap justify-end gap-2">
              <button
                type="button"
                className={`h-10 rounded-xl border border-border px-3 text-sm ${focusRing}`}
                disabled={patchMutation.isPending}
                onClick={() => setActiveId(null)}
              >
                Đóng
              </button>
              <button
                type="button"
                className={`h-10 rounded-xl border border-border px-3 text-sm font-medium ${focusRing}`}
                disabled={patchMutation.isPending}
                onClick={() => save("DRAFT")}
              >
                Lưu nháp
              </button>
              <button
                type="button"
                className={`h-10 rounded-xl bg-brand px-3 text-sm font-semibold text-white disabled:opacity-60 ${focusRing}`}
                disabled={patchMutation.isPending}
                onClick={requestPublish}
              >
                Xuất bản nội bộ
              </button>
            </div>
          </div>
        </div>
      ) : null}
    </div>
  );
}
