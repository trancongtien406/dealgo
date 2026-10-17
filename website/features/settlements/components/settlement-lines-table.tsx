import { StatusChip, vnd } from "@/components/ui/admin-list-ui";
import {
  AdminEmptyState,
  AdminForbiddenState,
  AdminListErrorBanner,
  AdminTableBodyShimmer,
} from "@/components/ui/admin-state-ui";
import {
  AdminTable,
  AdminTableBody,
  AdminTableCell,
  AdminTableContainer,
  AdminTableHead,
  AdminTableHeader,
  AdminTableRow,
} from "@/components/ui/admin-table";
import { useSettlementLinesQuery } from "@/features/settlements/hooks";
import {
  settlementLineStatusLabel,
  settlementLineStatusTone,
} from "@/features/settlements/mappers";
import {
  SETTLEMENT_LINE_COLUMN_COUNT,
  SETTLEMENT_LINE_TABLE_COLUMNS,
} from "@/features/settlements/constants";
import { isForbiddenError } from "@/lib/api/errors";

export function SettlementLinesTable() {
  const query = useSettlementLinesQuery(1, 20);
  const forbidden = query.isError && isForbiddenError(query.error);
  const lines = query.data?.items ?? [];

  return forbidden ? (
    <AdminForbiddenState
      title="Không có quyền truy cập bút toán đối soát"
      description="Tài khoản Ops hiện tại không được phân quyền xem sổ đối soát tài chính."
    />
  ) : query.isError && lines.length === 0 ? (
    <div className="p-4">
      <AdminListErrorBanner
        message="Không tải được bút toán đối soát từ máy chủ."
        onRetry={() => void query.refetch()}
      />
    </div>
  ) : !query.isPending && lines.length === 0 ? (
    <AdminEmptyState
      icon="wallet"
      title="Không có bút toán đối soát"
      description="Không tìm thấy bút toán nào trong kỳ đối soát này."
    />
  ) : (
    <>
      <AdminTableContainer minWidth="min-w-[860px]">
        <AdminTable caption="Bút toán đối soát kỳ này">
          <AdminTableHeader>
            <AdminTableRow>
              {SETTLEMENT_LINE_TABLE_COLUMNS.map((col) => (
                <AdminTableHead key={col.id}>{col.label}</AdminTableHead>
              ))}
            </AdminTableRow>
          </AdminTableHeader>
          <AdminTableBody>
            {query.isPending ? (
              <AdminTableBodyShimmer
                columns={SETTLEMENT_LINE_COLUMN_COUNT}
                rows={5}
              />
            ) : (
              lines.map((line) => (
                <AdminTableRow key={line.ref}>
                  <AdminTableCell>{line.kind}</AdminTableCell>
                  <AdminTableCell className="font-medium text-brand">
                    {line.ref}
                  </AdminTableCell>
                  <AdminTableCell className="text-muted">
                    {line.at}
                  </AdminTableCell>
                  <AdminTableCell className="tabular-nums">
                    {vnd(line.revenue)}
                  </AdminTableCell>
                  <AdminTableCell className="tabular-nums">
                    {vnd(line.fee)}
                  </AdminTableCell>
                  <AdminTableCell className="font-semibold tabular-nums">
                    {vnd(line.provisional)}
                  </AdminTableCell>
                  <AdminTableCell>
                    <StatusChip tone={settlementLineStatusTone(line.status)}>
                      {settlementLineStatusLabel(line.status)}
                    </StatusChip>
                  </AdminTableCell>
                </AdminTableRow>
              ))
            )}
          </AdminTableBody>
        </AdminTable>
      </AdminTableContainer>
      <div className="border-t border-border px-4 py-3 text-sm text-muted">
        Bút toán COD và doanh thu được tổng hợp tự động theo ngày giao dịch thực
        tế của đối tác trong kỳ đối soát.
      </div>
    </>
  );
}
