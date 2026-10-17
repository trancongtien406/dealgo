"use client";

import { useMemo, useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import {
  AdminBreadcrumb,
  Avatar,
  avatarTone,
  countFormat,
  focusRing,
  KpiCard,
  ListPager,
  PreviewButton,
  PreviewLink,
  QuietChip,
  StatusChip,
  type PageSize,
} from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminResetFilterButton,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import { SearchSelect } from "@/components/ui/search-select";
import { storeApprovalStatusOptions } from "@/lib/admin-filter-options";
import { filteredStatusKpi } from "@/lib/admin-kpi";
import {
  storeApprovalStatusLabel,
  storeApprovalStatusTone,
} from "@/features/store-approvals/mappers";
import {
  useApproveStoreMutation,
  useRejectStoreMutation,
  useStoreApprovalsQuery,
} from "@/features/store-approvals/hooks";
import { toast } from "@/components/ui/toast";
import { ApiError, isForbiddenError } from "@/lib/api/errors";

import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import {
  STORE_APPROVAL_COLUMN_COUNT,
  STORE_APPROVAL_TABLE_COLUMNS,
} from "@/features/store-approvals/constants";

export function StoreApprovalsBoard() {
  const [status, setStatus] = useState<string | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState<PageSize>(10);

  const { data, isPending, isError, error, refetch } = useStoreApprovalsQuery({
    page,
    limit: pageSize,
    status,
  });
  const forbidden = isError && isForbiddenError(error);
  const approveMutation = useApproveStoreMutation();
  const rejectMutation = useRejectStoreMutation();

  const resetFilters = () => {
    setStatus(null);
    setPage(1);
  };

  const pagedApprovals = useMemo(() => data?.items ?? [], [data?.items]);
  const total = data?.total ?? pagedApprovals.length;
  const lastPage = Math.max(1, Math.ceil(total / pageSize));
  const currentPage = Math.min(page, lastPage);

  const [selectedCode, setSelectedCode] = useState<string>("");
  const [rejectReason, setRejectReason] = useState("");
  const selected =
    pagedApprovals.find((s) => s.code === selectedCode) ??
    pagedApprovals[0] ??
    null;

  const storeApprovalKpis = useMemo(() => {
    const pending = filteredStatusKpi({
      statusFilter: status,
      targetStatus: "PENDING_KYB",
      total,
      pageCount: pagedApprovals.filter((s) => s.status === "PENDING_KYB")
        .length,
    });
    const needsVerify = filteredStatusKpi({
      statusFilter: status,
      targetStatus: "NEEDS_VERIFY",
      total,
      pageCount: pagedApprovals.filter((s) => s.status === "NEEDS_VERIFY")
        .length,
    });
    const decided = filteredStatusKpi({
      statusFilter: status,
      targetStatus: ["APPROVED", "REJECTED"],
      total,
      pageCount: pagedApprovals.filter(
        (s) => s.status === "APPROVED" || s.status === "REJECTED",
      ).length,
    });
    return [
      {
        label: "Tổng hồ sơ",
        value: total,
        note: "theo bộ lọc",
        tone: "brand" as const,
        icon: "store" as const,
      },
      {
        label: "Chờ duyệt KYB",
        value: pending.value,
        note: pending.note,
        tone: "food" as const,
        icon: "clock" as const,
      },
      {
        label: "Cần xác minh",
        value: needsVerify.value,
        note: needsVerify.note,
        tone: "danger" as const,
        icon: "alert" as const,
      },
      {
        label: "Đã duyệt / từ chối",
        value: decided.value,
        note: decided.note,
        tone: "success" as const,
        icon: "check" as const,
      },
    ];
  }, [pagedApprovals, status, total]);

  const actionPending = approveMutation.isPending || rejectMutation.isPending;

  const handleApprove = async () => {
    if (!selected || selected.status === "APPROVED") return;
    try {
      await approveMutation.mutateAsync(selected.code);
      toast.success(`Đã duyệt hồ sơ ${selected.name}`);
    } catch (err) {
      toast.error(
        err instanceof ApiError ? err.message : "Không thể duyệt hồ sơ.",
      );
    }
  };

  const handleReject = async () => {
    if (!selected || selected.status === "REJECTED") return;
    const reason = rejectReason.trim();
    if (reason.length < 3) {
      toast.message("Nhập lý do từ chối (tối thiểu 3 ký tự).");
      return;
    }
    try {
      await rejectMutation.mutateAsync({ id: selected.code, reason });
      toast.success(`Đã từ chối hồ sơ ${selected.name}`);
      setRejectReason("");
    } catch (err) {
      toast.error(
        err instanceof ApiError ? err.message : "Không thể từ chối hồ sơ.",
      );
    }
  };

  return (
    <div className="space-y-5">
      {isError && !forbidden && pagedApprovals.length > 0 ? (
        <AdminListErrorBanner
          message="Không thể đồng bộ danh sách xét duyệt hồ sơ cửa hàng mới nhất."
          onRetry={() => void refetch()}
        />
      ) : null}
      <AdminBreadcrumb
        items={[
          { label: "Trang chủ", href: "/overview" },
          { label: "Cửa hàng", href: "/stores" },
          { label: "Xét duyệt hồ sơ" },
        ]}
      />
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <h1 className="text-2xl font-bold tracking-tight text-ink sm:text-3xl">
            Duyệt hồ sơ cửa hàng (KYB)
          </h1>
          <p className="mt-1 text-sm text-muted">
            Kiểm tra thông tin chủ sở hữu, giấy tờ, địa điểm trước khi cửa hàng
            được nhận đơn.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <PreviewLink href="/stores" tone="neutral">
            <OpsIcon name="arrowRight" className="size-4 rotate-180" />
            Danh sách cửa hàng
          </PreviewLink>
          <QuietChip>Hàng chờ hồ sơ</QuietChip>
        </div>
      </div>
      <ul className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-4">
        {storeApprovalKpis.map((kpi) => (
          <li key={kpi.label}>
            <KpiCard
              label={kpi.label}
              value={kpi.value}
              note={kpi.note}
              icon={kpi.icon}
              tone={kpi.tone}
            />
          </li>
        ))}
      </ul>
      <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
        <div className="flex flex-wrap items-end justify-between gap-3">
          <div className="w-full sm:w-72">
            <SearchSelect
              label="Trạng thái hồ sơ"
              icon="sliders"
              value={status}
              options={storeApprovalStatusOptions.filter(
                (o) => o.value !== "ALL",
              )}
              placeholder="Tất cả trạng thái"
              onChange={(val) => {
                setStatus(val);
                setPage(1);
              }}
            />
          </div>
          <AdminResetFilterButton onClick={resetFilters} />
        </div>
      </section>
      {forbidden ? (
        <AdminForbiddenState
          title="Không có quyền xét duyệt cửa hàng"
          description="Tài khoản Ops hiện tại không được phân quyền xét duyệt hồ sơ KYB hoặc mở quyền hoạt động cho cửa hàng."
        />
      ) : isError && pagedApprovals.length === 0 ? (
        <AdminListErrorBanner
          message="Lỗi kết nối máy chủ. Không thể tải danh sách xét duyệt hồ sơ cửa hàng."
          onRetry={() => void refetch()}
        />
      ) : !isPending && pagedApprovals.length === 0 ? (
        <AdminEmptyState
          icon="store"
          title="Không tìm thấy hồ sơ xét duyệt"
          description="Không có hồ sơ đăng ký cửa hàng nào khớp với điều kiện lọc hiện tại."
          action={<AdminResetFilterButton onClick={resetFilters} />}
        />
      ) : (
        <>
          {selected ? (
            <>
              <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                <div className="flex flex-wrap items-start justify-between gap-4">
                  <div className="flex min-w-0 items-start gap-3">
                    <Avatar
                      letters={selected.initials}
                      tone={avatarTone(0)}
                      large
                    />
                    <div className="min-w-0">
                      <div className="flex flex-wrap items-center gap-2">
                        <h2 className="text-lg font-semibold text-ink">
                          {selected.name}
                        </h2>
                        <StatusChip
                          tone={storeApprovalStatusTone(selected.status)}
                        >
                          {storeApprovalStatusLabel(selected.status)}
                        </StatusChip>
                      </div>
                      <p className="mt-1 text-sm text-muted">
                        {selected.code} · {selected.category} · {selected.area}
                      </p>
                    </div>
                  </div>
                  <dl className="grid gap-2 text-sm sm:grid-cols-3">
                    <div>
                      <dt className="text-muted">Ngày gửi hồ sơ</dt>
                      <dd className="font-medium text-ink">
                        {selected.submittedAt}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-muted">Người phụ trách</dt>
                      <dd className="font-medium text-ink">
                        {selected.assignee}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-muted">Trạng thái bán</dt>
                      <dd className="font-medium text-delivery">
                        {selected.saleReady
                          ? "Có thể nhận đơn"
                          : "Chưa thể nhận đơn"}
                      </dd>
                    </div>
                  </dl>
                </div>
              </section>
              <div className="grid grid-cols-1 items-start gap-4 xl:grid-cols-3">
                <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
                  <h3 className="text-sm font-semibold text-ink">
                    Thông tin đăng ký
                  </h3>
                  <dl className="mt-3 space-y-2 text-sm">
                    {[
                      ["Mã cửa hàng", selected.code],
                      ["Tên cửa hàng", selected.name],
                      ["Người đại diện", selected.owner],
                      ["Ngành hàng", selected.category],
                      ["Điện thoại", selected.phoneMasked],
                      ["Địa chỉ", selected.address],
                      ["Loại đăng ký", selected.registrationType],
                    ].map(([label, value]) => (
                      <div key={label} className="flex justify-between gap-3">
                        <dt className="text-muted">{label}</dt>
                        <dd className="max-w-[60%] text-right font-medium text-ink">
                          {value}
                        </dd>
                      </div>
                    ))}
                  </dl>
                </section>
                <section className="rounded-2xl border border-border bg-white p-4 shadow-sm xl:col-span-2">
                  <h3 className="text-sm font-semibold text-ink">
                    Giấy tờ & quyết định
                  </h3>
                  <p className="mt-3 text-sm text-muted">
                    Hồ sơ đối tác MERCHANT — duyệt/từ chối qua Nest
                    partner-applications.
                  </p>
                  {selected.status === "PENDING_KYB" ||
                  selected.status === "NEEDS_VERIFY" ? (
                    <div className="mt-4 space-y-3">
                      <label className="block text-xs font-medium text-muted">
                        Lý do từ chối (bắt buộc khi từ chối)
                        <textarea
                          value={rejectReason}
                          onChange={(e) => setRejectReason(e.target.value)}
                          rows={3}
                          className={`mt-1.5 w-full rounded-xl border border-border bg-white px-3 py-2 text-sm text-ink ${focusRing}`}
                          placeholder="Ví dụ: thiếu giấy phép kinh doanh / địa chỉ không khớp…"
                        />
                      </label>
                      <div className="flex flex-wrap gap-2">
                        <PreviewButton
                          tone="danger"
                          onClick={() => void handleReject()}
                        >
                          {rejectMutation.isPending
                            ? "Đang từ chối…"
                            : "Từ chối"}
                        </PreviewButton>
                        <PreviewButton
                          tone="brand"
                          onClick={() => void handleApprove()}
                        >
                          {approveMutation.isPending
                            ? "Đang duyệt…"
                            : "Duyệt hồ sơ"}
                        </PreviewButton>
                      </div>
                      {actionPending ? (
                        <p className="text-xs text-muted">
                          Đang gửi quyết định lên máy chủ…
                        </p>
                      ) : null}
                    </div>
                  ) : (
                    <p className="mt-3 text-sm text-muted">
                      Hồ sơ đã ở trạng thái{" "}
                      {storeApprovalStatusLabel(selected.status)}.
                    </p>
                  )}
                  <div className="mt-3">
                    <PreviewLink href="/drivers/kyc" tone="ghost">
                      Mở hàng đợi KYC tài xế
                    </PreviewLink>
                  </div>
                </section>
              </div>
            </>
          ) : null}
          <div className="grid grid-cols-1 gap-4 xl:grid-cols-[minmax(0,1.2fr)_minmax(0,1fr)]">
            <div className="min-w-0 space-y-4">
              <div className="px-1 py-1">
                <h2 className="text-sm font-semibold text-ink">
                  Hàng đợi duyệt cửa hàng
                </h2>
              </div>
              <AdminTableContainer minWidth="min-w-[720px]">
                <AdminTable caption="Hàng đợi duyệt cửa hàng">
                  <AdminTableHeader>
                    <AdminTableRow>
                      {STORE_APPROVAL_TABLE_COLUMNS.map((col) => (
                        <AdminTableHead key={col.id}>
                          {col.label}
                        </AdminTableHead>
                      ))}
                    </AdminTableRow>
                  </AdminTableHeader>
                  <AdminTableBody>
                    {isPending ? (
                      <AdminTableBodyShimmer
                        columns={STORE_APPROVAL_COLUMN_COUNT}
                        rows={5}
                      />
                    ) : (
                      pagedApprovals.map((item, index) => {
                        const isSelected = item.code === selected?.code;
                        return (
                          <AdminTableRow
                            key={item.code}
                            onClick={() => setSelectedCode(item.code)}
                            className={`cursor-pointer ${
                              isSelected
                                ? "bg-brand/5 ring-1 ring-inset ring-brand/30"
                                : undefined
                            }`}
                          >
                            <AdminTableCell>
                              <div className="flex items-center gap-3">
                                <Avatar
                                  letters={item.initials}
                                  tone={avatarTone(index)}
                                />
                                <div>
                                  <p className="font-semibold text-ink">
                                    {item.name}
                                  </p>
                                  <p className="text-xs text-muted">
                                    Đơn đăng ký · {item.code.slice(0, 8)}
                                  </p>
                                </div>
                              </div>
                            </AdminTableCell>
                            <AdminTableCell className="text-muted">
                              {item.owner}
                            </AdminTableCell>
                            <AdminTableCell className="text-muted">
                              {item.submittedAt}
                            </AdminTableCell>
                            <AdminTableCell>
                              <StatusChip
                                tone={storeApprovalStatusTone(item.status)}
                              >
                                {storeApprovalStatusLabel(item.status)}
                              </StatusChip>
                            </AdminTableCell>
                            <AdminTableCell>
                              <span className="text-sm font-semibold text-brand">
                                {isSelected ? "Đang xem" : "Xem"}
                              </span>
                            </AdminTableCell>
                          </AdminTableRow>
                        );
                      })
                    )}
                  </AdminTableBody>
                </AdminTable>
              </AdminTableContainer>
              <ListPager
                page={currentPage}
                pageSize={pageSize}
                onPageChange={setPage}
                onPageSizeChange={setPageSize}
                summary={`Hiển thị ${pagedApprovals.length} / ${countFormat.format(total)} hồ sơ`}
                label="Phân trang KYB"
                lastPage={lastPage}
              />
            </div>
            <section className="rounded-2xl border border-border bg-white p-4 shadow-sm">
              <h3 className="text-sm font-semibold text-ink">
                Nhật ký xét duyệt
              </h3>
              <p className="mt-3 text-sm text-muted">
                Chưa có nhật ký xét duyệt cho hồ sơ đã chọn. Quyết định duyệt/từ
                chối được ghi nhận trên máy chủ.
              </p>
              <div className="mt-4 flex gap-3 rounded-xl border border-delivery/20 bg-delivery/5 p-3 text-sm text-ink">
                <OpsIcon
                  name="shield"
                  className="size-5 shrink-0 text-delivery"
                />
                <p>
                  Quyền riêng tư & nhật ký kiểm toán. Quyết định thật cần lý do,
                  reviewer ID và thời gian ghi nhận trên máy chủ.
                </p>
              </div>
            </section>
          </div>
        </>
      )}
    </div>
  );
}
