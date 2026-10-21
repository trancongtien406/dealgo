"use client";

import { useMemo, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  focusRing,
  PreviewLink,
  StatusChip,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
} from "@/components/ui/admin-state-ui";
import { ConfirmDialog } from "@/components/ui/confirm-dialog";
import { toast } from "@/components/ui/toast";
import {
  useApproveKycMutation,
  useKycCaseQuery,
  useRejectKycMutation,
} from "@/features/kyc/hooks";
import { kycStatusLabel, kycStatusTone } from "@/features/kyc/mappers";
import { ApiError, isForbiddenError } from "@/lib/api/errors";
import { SearchSelect } from "@/components/ui/search-select";
import {
  PartnerDocumentsPanel,
  PartnerIssuePicker,
  PartnerReviewOutcome,
} from "@/features/kyc/components/partner-review-panels";
import { validateIssues, type PartnerIssue } from "@/features/kyc/partner-review";

type Decision = "" | "approve" | "reject" | "request";
type PendingConfirm = null | "approve" | "reject";

const DECISION_OPTIONS = [
  { value: "approve", label: "Duyệt và kích hoạt" },
  { value: "request", label: "Yêu cầu bổ sung" },
  { value: "reject", label: "Từ chối hồ sơ" },
];

type LocalOutcome =
  | { kind: "idle" }
  | { kind: "approved"; note: string }
  | { kind: "rejected"; note: string }
  | { kind: "requested"; note: string };

export function KycCaseDetail({ code }: { code: string }) {
  const {
    data: selected,
    isPending,
    isError,
    error,
    refetch,
  } = useKycCaseQuery(code);
  const forbidden = isError && isForbiddenError(error);
  const approveMutation = useApproveKycMutation(code);
  const rejectMutation = useRejectKycMutation(code);
  const [decision, setDecision] = useState<Decision>("");
  const [note, setNote] = useState("");
  const [outcome, setOutcome] = useState<LocalOutcome>({ kind: "idle" });
  const [actionError, setActionError] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<PendingConfirm>(null);
  const [issues, setIssues] = useState<PartnerIssue[]>([]);

  const crumbs = useMemo(
    () => [
      { label: "Trang chủ", href: "/overview" },
      { label: "Tài xế & Đối tác", href: "/drivers" },
      { label: "Duyệt hồ sơ KYC", href: "/drivers/kyc" },
      { label: selected?.name || code },
    ],
    [selected?.name, code],
  );

  const locked =
    outcome.kind !== "idle" ||
    approveMutation.isPending ||
    rejectMutation.isPending ||
    (selected
      ? selected.status === "APPROVED" || selected.status === "REJECTED"
      : false);

  const canApprove = decision === "approve" && note.trim().length > 0;

  const runApprove = async () => {
    if (locked || !canApprove) {
      return;
    }
    setActionError(null);
    try {
      await approveMutation.mutateAsync();
      setOutcome({ kind: "approved", note: note.trim() });
      toast.success("Đã duyệt hồ sơ KYC.");
      setConfirm(null);
    } catch (error) {
      const message = errorMessage(error);
      setActionError(message);
      toast.error(message);
    }
  };

  const runReject = async () => {
    if (locked || decision !== "reject" || note.trim().length === 0) {
      return;
    }
    setActionError(null);
    try {
      await rejectMutation.mutateAsync(note.trim());
      setOutcome({ kind: "rejected", note: note.trim() });
      toast.success("Đã từ chối hồ sơ KYC.");
      setConfirm(null);
    } catch (error) {
      const message = errorMessage(error);
      setActionError(message);
      toast.error(message);
    }
  };

  const runRequestMoreInfo = async () => {
    if (locked || decision !== "request") {
      return;
    }
    const invalid = validateIssues(issues);
    if (invalid) {
      setActionError(invalid);
      return;
    }
    setActionError(null);
    const reason = note.trim() || "Hồ sơ cần bổ sung theo các mục bên dưới.";
    try {
      await rejectMutation.mutateAsync({
        reason,
        issues: issues.map((issue) => ({ ...issue, note: issue.note.trim() })),
      });
      setOutcome({ kind: "requested", note: reason });
      toast.success("Đã gửi yêu cầu bổ sung hồ sơ.");
    } catch (error) {
      const message = errorMessage(error);
      setActionError(message);
      toast.error(message);
    }
  };

  return (
    <div className="space-y-5">
      {forbidden ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminForbiddenState
            title="Không có quyền xem chi tiết KYC"
            description="Tài khoản của bạn không được phân quyền xử lý hồ sơ đối tác này."
          />
        </>
      ) : isError ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminListErrorBanner
            message="Không thể tải chi tiết hồ sơ KYC. Vui lòng thử lại."
            onRetry={() => void refetch()}
          />
        </>
      ) : isPending ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <div className="animate-pulse space-y-4" aria-busy="true">
            <span className="sr-only">Đang tải hồ sơ KYC…</span>
            <div className="h-9 w-72 max-w-full rounded-lg bg-canvas" />
            <div className="h-28 rounded-2xl border border-border bg-white" />
            <div className="grid gap-4 xl:grid-cols-2">
              <div className="h-64 rounded-2xl border border-border bg-white" />
              <div className="h-64 rounded-2xl border border-border bg-white" />
            </div>
          </div>
        </>
      ) : !selected ? (
        <>
          <AdminBreadcrumb items={crumbs} />
          <AdminEmptyState
            icon="driver"
            title="Không tìm thấy hồ sơ KYC"
            description="Không tìm thấy hồ sơ đối tác."
            action={
              <PreviewLink href="/drivers/kyc" tone="neutral">
                <OpsIcon name="arrowRight" className="size-4 rotate-180" />
                Hàng đợi KYC
              </PreviewLink>
            }
          />
        </>
      ) : (
        <>
          <ConfirmDialog
            open={confirm === "approve"}
            title="Xác nhận duyệt KYC"
            description={`Duyệt và kích hoạt hồ sơ ${selected.code}?`}
            confirmLabel="Duyệt hồ sơ"
            tone="brand"
            pending={approveMutation.isPending}
            onClose={() => setConfirm(null)}
            onConfirm={() => void runApprove()}
          />
          <ConfirmDialog
            open={confirm === "reject"}
            title="Xác nhận từ chối KYC"
            description={`Từ chối hồ sơ ${selected.code}? Lý do đã nhập sẽ được gửi lên máy chủ.`}
            confirmLabel="Từ chối"
            tone="danger"
            pending={rejectMutation.isPending}
            onClose={() => setConfirm(null)}
            onConfirm={() => void runReject()}
          />
          <AdminBreadcrumb items={crumbs} />
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
                Duyệt hồ sơ KYC tài xế
              </h1>
              <p className="mt-1 text-sm text-muted">
                Kiểm tra giấy tờ, điều kiện dịch vụ và quyết định kích hoạt tài
                xế.
              </p>
            </div>
            <div className="flex flex-wrap gap-2">
              <PreviewLink href="/drivers/kyc" tone="neutral">
                <OpsIcon name="arrowRight" className="size-4 rotate-180" />
                Hàng đợi KYC
              </PreviewLink>
              <PreviewLink href="/settings/faqs" tone="ghost">
                <OpsIcon name="shield" className="size-4" />
                Xem FAQ quy trình
              </PreviewLink>
            </div>
          </div>
          <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-[minmax(16rem,20rem)_minmax(0,1fr)_minmax(16rem,22rem)]">
            <div className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <p className="text-xs font-medium text-muted">Hồ sơ đang xét</p>
                <div className="mt-3 flex items-start gap-3">
                  <Avatar
                    letters={selected.initials}
                    tone={avatarTone(0)}
                    large
                  />
                  <div className="min-w-0">
                    <p className="text-xs text-muted">{selected.code}</p>
                    <h2 className="text-base font-semibold text-ink">
                      {selected.name}
                    </h2>
                    <div className="mt-1 flex flex-wrap gap-2">
                      <StatusChip
                        tone={
                          outcome.kind === "approved"
                            ? kycStatusTone("APPROVED")
                            : outcome.kind === "rejected"
                              ? kycStatusTone("REJECTED")
                              : outcome.kind === "requested"
                                ? kycStatusTone("NEEDS_MORE_INFO")
                                : kycStatusTone(selected.status)
                        }
                      >
                        {outcome.kind === "approved"
                          ? kycStatusLabel("APPROVED")
                          : outcome.kind === "rejected"
                            ? kycStatusLabel("REJECTED")
                            : outcome.kind === "requested"
                              ? kycStatusLabel("NEEDS_MORE_INFO")
                              : kycStatusLabel(selected.status)}
                      </StatusChip>
                      <StatusChip tone="brand">{selected.activity}</StatusChip>
                    </div>
                  </div>
                </div>
                <dl className="mt-4 space-y-2 text-sm">
                  {[
                    ["Điện thoại", selected.phoneMasked],
                    ["Khu vực đăng ký", selected.area],
                    ["Loại xe", selected.vehicleKind],
                    ["Mẫu xe", selected.vehicle],
                    ["Biển số", selected.plate],
                    [
                      "Trạng thái điều phối",
                      selected.activated || outcome.kind === "approved"
                        ? "Đã kích hoạt"
                        : "Chưa kích hoạt",
                    ],
                  ].map(([label, value]) => (
                    <div key={label} className="flex justify-between gap-3">
                      <dt className="text-muted">{label}</dt>
                      <dd className="text-right font-medium text-ink">
                        {value}
                      </dd>
                    </div>
                  ))}
                </dl>
              </section>
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Dòng thời gian hồ sơ
                </h3>
                <ol className="mt-3 space-y-3 border-l border-border pl-4">
                  <li className="relative text-sm">
                    <span
                      aria-hidden="true"
                      className="absolute top-1.5 -left-[1.3rem] size-2 rounded-full bg-brand"
                    />
                    <p className="font-medium text-ink">Nộp hồ sơ đối tác</p>
                    <p className="text-xs text-muted">
                      {selected.submittedAt || "Chưa có dữ liệu"} · Trạng thái{" "}
                      {kycStatusLabel(selected.status)}
                    </p>
                  </li>
                  {outcome.kind !== "idle" ? (
                    <li className="relative text-sm">
                      <span
                        aria-hidden="true"
                        className="absolute top-1.5 -left-[1.3rem] size-2 rounded-full bg-success"
                      />
                      <p className="font-medium text-ink">
                        {outcome.kind === "approved"
                          ? "Đã duyệt hồ sơ đối tác"
                          : outcome.kind === "rejected"
                            ? "Đã từ chối hồ sơ đối tác"
                            : "Đã gửi yêu cầu bổ sung hồ sơ"}
                      </p>
                      <p className="text-xs text-muted">
                        Vừa xong · {outcome.note || "Không có ghi chú"}
                      </p>
                    </li>
                  ) : null}
                </ol>
                {selected.reviewedAt && outcome.kind === "idle" ? (
                  <p className="mt-3 text-xs text-muted">
                    Đã xét duyệt lúc {selected.reviewedAt}.
                  </p>
                ) : null}
              </section>
            </div>
            <div className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Kiểm tra giấy tờ tải lên
                </h3>
                <PartnerDocumentsPanel documents={selected.documents} />
              </section>
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Thông tin đối tác khai báo
                </h3>
                {selected.details.length > 0 ? (
                  <dl className="mt-3 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
                    {selected.details.map(([label, value]) => (
                      <div
                        key={label}
                        className="flex justify-between gap-3 rounded-xl border border-border px-3 py-2"
                      >
                        <dt className="text-muted">{label}</dt>
                        <dd className="text-right font-medium text-ink">{value}</dd>
                      </div>
                    ))}
                  </dl>
                ) : (
                  <p className="mt-3 text-sm text-muted">Hồ sơ chưa có thông tin khai báo.</p>
                )}
              </section>
            </div>
            <aside className="space-y-4">
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Ra quyết định
                </h3>
                <div className="mt-3 rounded-xl border border-food/30 bg-food/5 px-3 py-2 text-sm text-ink">
                  Kiểm tra kỹ thông tin định danh, giấy tờ tùy thân và phương
                  tiện trước khi ra quyết định.
                </div>
                {actionError ? (
                  <div
                    role="alert"
                    className="mt-3 rounded-xl border border-danger/30 bg-danger/5 px-3 py-2 text-sm text-danger"
                  >
                    {actionError}
                  </div>
                ) : null}
                {selected.status === "REJECTED" && outcome.kind === "idle" ? (
                  <PartnerReviewOutcome
                    role={selected.role}
                    reason={selected.reason}
                    issues={selected.issues}
                  />
                ) : null}
                {outcome.kind !== "idle" ? (
                  <div
                    role="status"
                    className="mt-3 rounded-xl border border-success/30 bg-success/5 px-3 py-2 text-sm text-ink"
                  >
                    {outcome.kind === "approved"
                      ? "Đã duyệt trên máy chủ."
                      : outcome.kind === "rejected"
                        ? "Đã từ chối trên máy chủ."
                        : "Đã gửi yêu cầu bổ sung; đối tác thấy từng mục trong ứng dụng."}
                  </div>
                ) : null}
                <div className="mt-3">
                  <SearchSelect
                    label="Kết quả đánh giá"
                    value={decision || null}
                    placeholder="Chưa chọn quyết định"
                    disabled={locked}
                    options={DECISION_OPTIONS}
                    onChange={(val) => setDecision((val ?? "") as Decision)}
                  />
                </div>
                {decision === "request" ? (
                  <PartnerIssuePicker
                    role={selected.role}
                    value={issues}
                    onChange={setIssues}
                    disabled={locked}
                  />
                ) : null}
                <label
                  htmlFor="kyc-note"
                  className="mt-3 block text-xs font-medium text-muted"
                >
                  Lý do / ghi chú nội bộ
                </label>
                <textarea
                  id="kyc-note"
                  rows={3}
                  disabled={locked}
                  value={note}
                  onChange={(event) => setNote(event.target.value)}
                  placeholder="Nhập ghi chú kiểm duyệt..."
                  className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink placeholder:text-muted disabled:opacity-60 ${focusRing}`}
                />
                <div className="mt-3 flex flex-wrap gap-2">
                  <button
                    type="button"
                    disabled={locked || decision !== "request"}
                    onClick={() => void runRequestMoreInfo()}
                    className={`inline-flex h-10 items-center rounded-xl border border-brand/30 bg-white px-3 text-sm font-medium text-brand disabled:cursor-not-allowed disabled:opacity-40 ${focusRing}`}
                  >
                    Yêu cầu bổ sung
                  </button>
                  <button
                    type="button"
                    disabled={
                      locked ||
                      decision !== "reject" ||
                      note.trim().length === 0
                    }
                    onClick={() => setConfirm("reject")}
                    className={`inline-flex h-10 items-center rounded-xl border border-danger/40 bg-white px-3 text-sm font-medium text-danger disabled:cursor-not-allowed disabled:opacity-40 ${focusRing}`}
                  >
                    {rejectMutation.isPending ? "Đang từ chối…" : "Từ chối"}
                  </button>
                </div>
                <button
                  type="button"
                  disabled={locked || !canApprove}
                  onClick={() => setConfirm("approve")}
                  className={`mt-2 inline-flex h-11 w-full items-center justify-center rounded-xl border px-3 text-sm font-semibold disabled:cursor-not-allowed ${
                    canApprove && !locked
                      ? `border-transparent bg-brand text-white ${focusRing}`
                      : "border-border bg-canvas text-muted"
                  }`}
                >
                  {approveMutation.isPending
                    ? "Đang duyệt…"
                    : canApprove && !locked
                      ? "Duyệt hồ sơ"
                      : "Chưa đủ điều kiện duyệt"}
                </button>
              </section>
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <h3 className="text-sm font-semibold text-ink">
                  Kiểm soát quyết định
                </h3>
                <dl className="mt-3 space-y-2 text-sm">
                  <div className="flex justify-between gap-3">
                    <dt className="text-muted">SLA mục tiêu</dt>
                    <dd className="font-medium text-ink">24 giờ</dd>
                  </div>
                  <div className="flex justify-between gap-3">
                    <dt className="text-muted">Nguồn dữ liệu</dt>
                    <dd className="font-medium text-ink">Hồ sơ đối tác</dd>
                  </div>
                  <div className="flex justify-between gap-3">
                    <dt className="text-muted">Nhật ký kiểm toán</dt>
                    <dd className="font-medium text-ink">Ghi nhận tự động</dd>
                  </div>
                </dl>
              </section>
            </aside>
          </div>
        </>
      )}
    </div>
  );
}

function errorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    return error.message;
  }
  if (error instanceof Error && error.message.trim()) {
    return error.message;
  }
  return "Thao tác thất bại. Thử lại.";
}
