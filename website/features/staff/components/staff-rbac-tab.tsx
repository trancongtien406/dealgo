"use client";

import { useState } from "react";
import { OpsIcon } from "@/components/ui/ops-icons";
import { focusRing } from "@/components/ui/admin-list-ui";
import { rbacRoleLabel, toRbacRows } from "@/features/staff/rbac-matrix";
import { useRbacMatrixQuery } from "@/features/staff/hooks";

import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";

export function StaffRbacTab() {
  const [showRoleModal, setShowRoleModal] = useState(false);
  const matrixQuery = useRbacMatrixQuery();
  const roles = matrixQuery.data?.roles ?? [];
  const rows = matrixQuery.data ? toRbacRows(matrixQuery.data) : [];

  return (
    <div role="tabpanel" className="p-4 space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-2">
        <div className="min-w-0">
          <h2 className="text-base font-semibold text-ink">
            Ma trận quyền theo vai trò
          </h2>
          <p className="mt-1 text-sm text-muted">
            Cấu hình phân quyền truy cập và giới hạn chức năng theo từng vai trò
            nhân sự.
          </p>
        </div>
        <button
          type="button"
          onClick={() => setShowRoleModal(true)}
          className={`inline-flex items-center gap-1 rounded-md text-sm font-semibold text-brand hover:underline cursor-pointer ${focusRing}`}
        >
          Quản lý vai trò
          <OpsIcon name="arrowRight" className="size-4" />
        </button>
      </div>

      {matrixQuery.isPending ? (
        <p className="py-8 text-center text-sm text-muted" role="status">
          Đang tải ma trận quyền…
        </p>
      ) : matrixQuery.isError ? (
        <div className="rounded-xl border border-border p-4 text-sm text-muted" role="alert">
          Không tải được ma trận quyền từ máy chủ.{" "}
          <button
            type="button"
            onClick={() => void matrixQuery.refetch()}
            className={`font-semibold text-brand hover:underline cursor-pointer ${focusRing}`}
          >
            Thử lại
          </button>
        </div>
      ) : rows.length === 0 ? (
        <p className="py-8 text-center text-sm text-muted">Chưa có quyền nào được cấu hình.</p>
      ) : (
        <AdminTableContainer minWidth="min-w-full">
          <AdminTable caption="Ma trận phân quyền nhân sự">
            <AdminTableHeader>
              <AdminTableRow>
                <AdminTableHead>Quyền truy cập</AdminTableHead>
                {roles.map((roleName) => (
                  <AdminTableHead key={roleName} align="center">
                    {rbacRoleLabel(roleName)}
                  </AdminTableHead>
                ))}
              </AdminTableRow>
            </AdminTableHeader>
            <AdminTableBody>
              {rows.map((grant) => (
                <AdminTableRow key={grant.permission}>
                  <AdminTableCell className="font-medium">
                    {grant.permission}
                  </AdminTableCell>
                  {grant.marks.map((allowed, idx) => (
                    <AdminTableCell key={roles[idx]} align="center">
                      {allowed ? (
                        <span className="inline-flex text-brand">
                          <OpsIcon name="check" className="size-4" />
                          <span className="sr-only">Có</span>
                        </span>
                      ) : (
                        <span className="text-muted">
                          —<span className="sr-only">Không</span>
                        </span>
                      )}
                    </AdminTableCell>
                  ))}
                </AdminTableRow>
              ))}
            </AdminTableBody>
          </AdminTable>
        </AdminTableContainer>
      )}

      {showRoleModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40 p-4">
          <div className="w-full max-w-md rounded-2xl bg-white p-6 shadow-xl space-y-4">
            <div className="flex items-center justify-between">
              <h3 className="text-lg font-bold text-ink">
                Quản lý vai trò nhân sự
              </h3>
              <button
                type="button"
                onClick={() => setShowRoleModal(false)}
                className="text-muted hover:text-ink cursor-pointer"
              >
                <OpsIcon name="close" className="size-5" />
              </button>
            </div>
            <p className="text-sm text-muted">
              Định nghĩa các nhóm quyền và quy tắc phân quyền tối thiểu cho từng
              bộ phận.
            </p>
            <div className="space-y-2">
              {roles.map((r) => (
                <div
                  key={r}
                  className="flex items-center justify-between rounded-xl border border-border p-3"
                >
                  <span className="font-medium text-ink">{rbacRoleLabel(r)}</span>
                  <span className="text-xs text-muted">Mặc định hệ thống</span>
                </div>
              ))}
            </div>
            <div className="flex justify-end pt-2">
              <button
                type="button"
                onClick={() => setShowRoleModal(false)}
                className="rounded-xl bg-brand px-4 py-2 text-sm font-medium text-white hover:bg-brand/90 cursor-pointer"
              >
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
