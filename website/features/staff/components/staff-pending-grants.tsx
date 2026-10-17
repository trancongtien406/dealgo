"use client";

import { useState } from "react";
import { toast } from "sonner";
import {
  useApproveRoleGrantMutation,
  usePendingRoleGrantsQuery,
  useRejectRoleGrantMutation,
} from "@/features/staff/hooks";
import { staffRoleLabel } from "@/features/staff/mappers";
import { countFormat, StatusChip } from "@/components/ui/admin-list-ui";
import { formatOpsDate } from "@/lib/ops-time";
import { ApiError } from "@/lib/api/errors";

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
  STAFF_PENDING_GRANTS_COLUMN_COUNT,
  STAFF_PENDING_GRANTS_TABLE_COLUMNS,
} from "@/features/staff/constants";

export function StaffPendingGrants() {
  const pendingGrantsQuery = usePendingRoleGrantsQuery();
  const approveGrantMutation = useApproveRoleGrantMutation();
  const rejectGrantMutation = useRejectRoleGrantMutation();

  const [reviewingGrantId, setReviewingGrantId] = useState<string | null>(null);

  const pendingGrants = pendingGrantsQuery.data?.items ?? [];
  const pendingGrantTotal =
    pendingGrantsQuery.data?.total ?? pendingGrants.length;

  const handleApproveGrant = async (id: string, label: string) => {
    setReviewingGrantId(id);
    try {
      await approveGrantMutation.mutateAsync(id);
      toast.success(`Đã duyệt quyền cho ${label}`);
    } catch (err) {
      toast.error(
        err instanceof ApiError ? err.message : "Duyệt cấp quyền thất bại.",
      );
    } finally {
      setReviewingGrantId(null);
    }
  };

  const handleRejectGrant = async (id: string, label: string) => {
    setReviewingGrantId(id);
    try {
      await rejectGrantMutation.mutateAsync(id);
      toast.success(`Đã từ chối cấp quyền cho ${label}`);
    } catch (err) {
      toast.error(
        err instanceof ApiError ? err.message : "Từ chối cấp quyền thất bại.",
      );
    } finally {
      setReviewingGrantId(null);
    }
  };

  return (
    <section className="min-w-0 overflow-hidden rounded-2xl border border-border bg-white shadow-sm">
      <div className="flex flex-wrap items-start justify-between gap-2 border-b border-border px-4 py-3">
        <div className="min-w-0">
          <h2 className="text-base font-semibold text-ink">Chờ duyệt</h2>
          <p className="mt-1 text-sm text-muted">
            Yêu cầu cấp role đang PENDING — duyệt hoặc từ chối trên máy chủ.
          </p>
        </div>
        <StatusChip tone="food">
          {countFormat.format(pendingGrantTotal)} chờ duyệt
        </StatusChip>
      </div>
      <AdminTableContainer minWidth="min-w-[720px]">
        <AdminTable caption="Danh sách cấp quyền chờ duyệt">
          <AdminTableHeader>
            <AdminTableRow>
              {STAFF_PENDING_GRANTS_TABLE_COLUMNS.map((col) => (
                <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
              ))}
            </AdminTableRow>
          </AdminTableHeader>
          <AdminTableBody>
            {pendingGrantsQuery.isPending ? (
              <AdminTableRow>
                <AdminTableCell
                  colSpan={STAFF_PENDING_GRANTS_COLUMN_COUNT}
                  className="py-8 text-center text-sm text-muted"
                >
                  Đang tải yêu cầu cấp quyền…
                </AdminTableCell>
              </AdminTableRow>
            ) : pendingGrantsQuery.isError ? (
              <AdminTableRow>
                <AdminTableCell
                  colSpan={STAFF_PENDING_GRANTS_COLUMN_COUNT}
                  className="py-8 text-center text-sm text-danger"
                >
                  Không tải được hàng đợi cấp quyền. Thử tải lại trang.
                </AdminTableCell>
              </AdminTableRow>
            ) : pendingGrants.length === 0 ? (
              <AdminTableRow>
                <AdminTableCell
                  colSpan={STAFF_PENDING_GRANTS_COLUMN_COUNT}
                  className="py-8 text-center text-sm text-muted"
                >
                  Không có yêu cầu cấp quyền đang chờ duyệt.
                </AdminTableCell>
              </AdminTableRow>
            ) : (
              pendingGrants.map((grant) => {
                const label =
                  grant.displayName ||
                  grant.email ||
                  grant.phone ||
                  grant.userId.slice(0, 8);
                const busy = reviewingGrantId === grant.id;
                return (
                  <AdminTableRow key={grant.id}>
                    <AdminTableCell>
                      <p className="font-medium text-ink">{label}</p>
                      <p className="truncate text-xs text-muted">
                        {grant.email || grant.userId}
                      </p>
                    </AdminTableCell>
                    <AdminTableCell>
                      {staffRoleLabel(grant.role)}
                    </AdminTableCell>
                    <AdminTableCell>
                      {grant.phone || grant.email || "—"}
                    </AdminTableCell>
                    <AdminTableCell>
                      {formatOpsDate(grant.createdAt)}
                    </AdminTableCell>
                    <AdminTableCell>
                      <div className="flex flex-wrap gap-2">
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() =>
                            void handleApproveGrant(grant.id, label)
                          }
                          className="rounded-lg border border-brand/20 bg-brand/10 px-3 py-1 text-xs font-semibold text-brand hover:bg-brand/20 disabled:cursor-not-allowed disabled:opacity-60 cursor-pointer"
                        >
                          {busy && approveGrantMutation.variables === grant.id
                            ? "Đang duyệt…"
                            : "Duyệt"}
                        </button>
                        <button
                          type="button"
                          disabled={busy}
                          onClick={() =>
                            void handleRejectGrant(grant.id, label)
                          }
                          className="rounded-lg border border-danger/20 bg-danger/10 px-3 py-1 text-xs font-semibold text-danger hover:bg-danger/20 disabled:cursor-not-allowed disabled:opacity-60 cursor-pointer"
                        >
                          {busy && rejectGrantMutation.variables === grant.id
                            ? "Đang từ chối…"
                            : "Từ chối"}
                        </button>
                      </div>
                    </AdminTableCell>
                  </AdminTableRow>
                );
              })
            )}
          </AdminTableBody>
        </AdminTable>
      </AdminTableContainer>
    </section>
  );
}
