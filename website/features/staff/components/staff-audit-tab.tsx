"use client";

import { useStaffAuditLogsQuery } from "@/features/staff/hooks";
import { StatusChip } from "@/components/ui/admin-list-ui";
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
  STAFF_AUDIT_COLUMN_COUNT,
  STAFF_AUDIT_TABLE_COLUMNS,
} from "@/features/staff/constants";

export function StaffAuditTab() {
  const auditLogsQuery = useStaffAuditLogsQuery();
  const auditLogs = auditLogsQuery.data ?? [];

  return (
    <div role="tabpanel" className="p-4 space-y-3">
      <h2 className="text-base font-semibold text-ink">
        Nhật ký phân quyền &amp; tài khoản
      </h2>
      <p className="text-sm text-muted">
        Ghi nhận mọi thay đổi về vai trò và phạm vi
      </p>
      <div className="mt-3">
        <AdminTableContainer minWidth="min-w-full">
          <AdminTable caption="Nhật ký phân quyền và tài khoản">
            <AdminTableHeader>
              <AdminTableRow>
                {STAFF_AUDIT_TABLE_COLUMNS.map((col) => (
                  <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
                ))}
              </AdminTableRow>
            </AdminTableHeader>
            <AdminTableBody>
              {auditLogsQuery.isPending ? (
                <AdminTableRow>
                  <AdminTableCell
                    colSpan={STAFF_AUDIT_COLUMN_COUNT}
                    className="py-8 text-center text-sm text-muted"
                  >
                    Đang tải nhật ký phân quyền…
                  </AdminTableCell>
                </AdminTableRow>
              ) : auditLogs.length === 0 ? (
                <AdminTableRow>
                  <AdminTableCell
                    colSpan={STAFF_AUDIT_COLUMN_COUNT}
                    className="py-8 text-center text-sm text-muted"
                  >
                    Chưa có sự kiện nhật ký phân quyền nào.
                  </AdminTableCell>
                </AdminTableRow>
              ) : (
                auditLogs.map((log, idx) => (
                  <AdminTableRow key={log.time + log.action + idx}>
                    <AdminTableCell>{log.time}</AdminTableCell>
                    <AdminTableCell className="font-medium text-brand">
                      {log.actor}
                    </AdminTableCell>
                    <AdminTableCell>{log.action}</AdminTableCell>
                    <AdminTableCell className="text-muted">
                      {log.target}
                    </AdminTableCell>
                    <AdminTableCell>
                      <StatusChip tone="success">{log.status}</StatusChip>
                    </AdminTableCell>
                  </AdminTableRow>
                ))
              )}
            </AdminTableBody>
          </AdminTable>
        </AdminTableContainer>
      </div>
    </div>
  );
}
