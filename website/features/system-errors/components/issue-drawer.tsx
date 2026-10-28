"use client";

import { useEffect, useState } from "react";
import { StatusChip, focusRing } from "@/components/ui/admin-list-ui";
import { AdminListErrorBanner } from "@/components/ui/admin-state-ui";
import { OpsIcon } from "@/components/ui/ops-icons";
import { OpsInterveneDialog } from "@/components/ui/ops-intervene-dialog";
import { secondaryButton } from "@/features/integrations/components/integration-ui";
import {
  useSystemErrorQuery,
  useUpdateIssueStatusMutation,
} from "@/features/system-errors/hooks";
import {
  formatIssueCount,
  frameLocation,
  issueStatusLabel,
  issueStatusTone,
  levelTone,
  projectLabel,
} from "@/features/system-errors/mappers";
import type {
  IssueStatusUpdate,
  SentryIssueDetail,
} from "@/features/system-errors/types";
import { formatOpsDateTime } from "@/lib/ops-time";

const STATUS_ACTIONS: Record<
  IssueStatusUpdate,
  { label: string; title: string; success: string }
> = {
  resolved: {
    label: "Đã xử lý",
    title: "Đánh dấu đã xử lý",
    success: "Đã đánh dấu đã xử lý.",
  },
  ignored: { label: "Bỏ qua", title: "Bỏ qua lỗi", success: "Đã bỏ qua lỗi." },
  unresolved: {
    label: "Mở lại",
    title: "Mở lại lỗi",
    success: "Đã mở lại lỗi.",
  },
};

export function IssueDrawer({
  id,
  onClose,
}: {
  id: string;
  onClose: () => void;
}) {
  const { data, isPending, isError, error, refetch } = useSystemErrorQuery(id);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      <button
        type="button"
        aria-label="Đóng"
        className="absolute inset-0 bg-ink/30"
        onClick={onClose}
      />
      <aside
        role="dialog"
        aria-modal="true"
        aria-label="Chi tiết lỗi"
        className="relative flex h-full w-full max-w-2xl flex-col overflow-hidden bg-white shadow-xl"
      >
        <div className="flex items-center justify-between gap-3 border-b border-border px-5 py-3">
          <span className="font-mono text-sm text-muted">
            {data?.shortId ?? "…"}
          </span>
          <button
            type="button"
            onClick={onClose}
            aria-label="Đóng"
            className={`rounded-lg p-1.5 hover:bg-canvas ${focusRing}`}
          >
            <OpsIcon name="close" className="size-4" />
          </button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-4">
          {isError ? (
            <AdminListErrorBanner
              message={
                error instanceof Error
                  ? error.message
                  : "Không tải được chi tiết lỗi."
              }
              onRetry={() => void refetch()}
            />
          ) : isPending || !data ? (
            <div className="space-y-3" aria-busy="true">
              {[0, 1, 2, 3].map((i) => (
                <div key={i} className="h-5 animate-pulse rounded bg-canvas" />
              ))}
            </div>
          ) : (
            <IssueDetailBody issue={data} />
          )}
        </div>
      </aside>
    </div>
  );
}

function IssueDetailBody({ issue }: { issue: SentryIssueDetail }) {
  const [action, setAction] = useState<IssueStatusUpdate | null>(null);
  const update = useUpdateIssueStatusMutation();
  const event = issue.latestEvent;
  const actions = (["resolved", "ignored", "unresolved"] as const).filter(
    (s) =>
      s === "unresolved"
        ? issue.status !== "unresolved"
        : issue.status === "unresolved",
  );

  return (
    <div className="space-y-5">
      <div className="space-y-2">
        <div className="flex flex-wrap items-center gap-2">
          <StatusChip tone={levelTone(issue.level)}>{issue.level}</StatusChip>
          <StatusChip tone={issueStatusTone(issue.status)} dot>
            {issueStatusLabel(issue.status)}
          </StatusChip>
          <StatusChip tone="brand">{projectLabel(issue.project)}</StatusChip>
        </div>
        <h2 className="break-words text-lg font-semibold text-ink">
          {issue.title}
        </h2>
        {issue.culprit ? (
          <p className="break-all font-mono text-xs text-muted">
            {issue.culprit}
          </p>
        ) : null}
      </div>

      <dl className="grid grid-cols-2 gap-3 text-sm sm:grid-cols-4">
        <Stat label="Sự kiện" value={formatIssueCount(issue.count)} />
        <Stat label="Người dùng" value={formatIssueCount(issue.userCount)} />
        <Stat label="Lần đầu" value={formatOpsDateTime(issue.firstSeen)} />
        <Stat label="Gần nhất" value={formatOpsDateTime(issue.lastSeen)} />
      </dl>

      <div className="flex flex-wrap gap-2">
        <a
          href={issue.permalink}
          target="_blank"
          rel="noreferrer noopener"
          className={`${secondaryButton} gap-1.5`}
        >
          Mở trong Sentry
          <OpsIcon name="arrowRight" className="size-3.5" />
        </a>
        {issue.canWrite
          ? actions.map((s) => (
              <button
                key={s}
                type="button"
                className={secondaryButton}
                disabled={update.isPending}
                onClick={() => setAction(s)}
              >
                {STATUS_ACTIONS[s].label}
              </button>
            ))
          : null}
      </div>

      {event ? (
        <>
          <section>
            <h3 className="mb-2 text-sm font-semibold text-ink">
              Sự kiện gần nhất
            </h3>
            <p className="text-xs text-muted">
              {formatOpsDateTime(event.dateCreated)}
              {event.environment ? ` · ${event.environment}` : ""}
              {event.release ? ` · ${event.release}` : ""}
            </p>
            {event.exception ? (
              <p className="mt-2 break-words rounded-lg bg-danger/5 px-3 py-2 font-mono text-xs text-danger">
                {[event.exception.type, event.exception.value]
                  .filter(Boolean)
                  .join(": ")}
              </p>
            ) : null}
          </section>
          <section>
            <h3 className="mb-2 text-sm font-semibold text-ink">Stack trace</h3>
            {event.frames.length === 0 ? (
              <p className="text-xs text-muted">Không có stack trace.</p>
            ) : (
              <ol className="divide-y divide-border overflow-hidden rounded-xl border border-border">
                {event.frames.map((frame, i) => (
                  <li
                    key={i}
                    className={`px-3 py-2 font-mono text-xs ${frame.inApp ? "bg-white text-ink" : "bg-canvas text-muted"}`}
                  >
                    <span className="font-semibold">
                      {frame.function ?? "<anonymous>"}
                    </span>
                    <span className="block break-all">
                      {frameLocation(frame)}
                    </span>
                  </li>
                ))}
              </ol>
            )}
          </section>
          {event.tags.length > 0 ? (
            <section>
              <h3 className="mb-2 text-sm font-semibold text-ink">Tags</h3>
              <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-xs">
                {event.tags.map((tag) => (
                  <div key={tag.key} className="contents">
                    <dt className="font-mono text-muted">{tag.key}</dt>
                    <dd className="break-all font-mono text-ink">
                      {tag.value}
                    </dd>
                  </div>
                ))}
              </dl>
            </section>
          ) : null}
        </>
      ) : (
        <p className="text-sm text-muted">
          Chưa có sự kiện nào trong kỳ lưu trữ.
        </p>
      )}

      {action ? (
        <OpsInterveneDialog
          open
          labels={{
            title: STATUS_ACTIONS[action].title,
            confirm: STATUS_ACTIONS[action].label,
            hint: "Cập nhật trạng thái trên Sentry, lý do ghi vào nhật ký kiểm toán.",
            success: STATUS_ACTIONS[action].success,
          }}
          confirmTone="brand"
          entityLabel={issue.shortId}
          pending={update.isPending}
          onClose={() => setAction(null)}
          onConfirm={async (reason) => {
            await update.mutateAsync({ id: issue.id, status: action, reason });
          }}
        />
      ) : null}
    </div>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0 rounded-xl border border-border px-3 py-2">
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="truncate font-semibold text-ink">{value}</dd>
    </div>
  );
}
