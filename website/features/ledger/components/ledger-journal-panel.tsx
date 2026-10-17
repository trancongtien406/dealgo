"use client";

import type { LedgerJournal } from "@/features/ledger/types";
import { DetailSection } from "@/components/ui/admin-detail-ui";
import { StatusChip, vnd } from "@/components/ui/admin-list-ui";
import {
  AdminTableContainer,
  AdminTable,
  AdminTableHeader,
  AdminTableHead,
  AdminTableBody,
  AdminTableRow,
  AdminTableCell,
} from "@/components/ui/admin-table";
import { LEDGER_JOURNAL_COLUMNS } from "@/features/ledger/constants";

type LedgerJournalPanelProps = {
  sectionId: string;
  journal: LedgerJournal | null | undefined;
  isPending: boolean;
  isError: boolean;
};

export function LedgerJournalPanel({
  sectionId,
  journal,
  isPending,
  isError,
}: LedgerJournalPanelProps) {
  const extra =
    !isPending && !isError ? (
      journal ? (
        <StatusChip tone="success">{journal.status}</StatusChip>
      ) : (
        <StatusChip tone="food">Chưa ghi sổ</StatusChip>
      )
    ) : null;

  return (
    <DetailSection id={sectionId} title="Sổ bút toán COD" extra={extra}>
      {isPending ? (
        <p className="text-sm text-muted">Đang tải bút toán…</p>
      ) : isError ? (
        <p className="text-sm text-danger" role="alert">
          Không tải được sổ bút toán. Thử làm mới trang.
        </p>
      ) : !journal ? (
        <p className="text-sm text-muted">
          Chưa có bút toán COD cho bản ghi này (thường ghi nhận sau khi đơn hoàn
          tất thanh toán tiền mặt).
        </p>
      ) : (
        <>
          <dl className="grid gap-2 text-sm sm:grid-cols-2">
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted">Sự kiện</dt>
              <dd className="font-medium text-ink">{journal.event}</dd>
            </div>
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted">Số tiền</dt>
              <dd className="font-semibold text-ink tabular-nums">
                {vnd(journal.amountVnd)}
              </dd>
            </div>
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted">Ghi sổ lúc</dt>
              <dd className="font-medium text-ink">{journal.postedAtLabel}</dd>
            </div>
            <div className="flex justify-between gap-3 sm:block">
              <dt className="text-muted">Journal ID</dt>
              <dd
                className="truncate font-mono text-xs text-ink"
                title={journal.id}
              >
                {journal.id}
              </dd>
            </div>
          </dl>
          <AdminTableContainer className="mt-4">
            <AdminTable minWidth="min-w-[28rem]">
              <AdminTableHeader>
                <AdminTableRow>
                  {LEDGER_JOURNAL_COLUMNS.map((col) => (
                    <AdminTableHead
                      key={col.id}
                      align={"align" in col ? col.align : "left"}
                    >
                      {col.label}
                    </AdminTableHead>
                  ))}
                </AdminTableRow>
              </AdminTableHeader>
              <AdminTableBody>
                {journal.entries.map((entry) => (
                  <AdminTableRow key={entry.id}>
                    <AdminTableCell className="font-mono text-xs">
                      {entry.accountCode}
                    </AdminTableCell>
                    <AdminTableCell className="text-muted">
                      {entry.direction}
                    </AdminTableCell>
                    <AdminTableCell
                      align="right"
                      className="font-medium tabular-nums"
                    >
                      {vnd(entry.amountVnd)}
                    </AdminTableCell>
                  </AdminTableRow>
                ))}
              </AdminTableBody>
            </AdminTable>
          </AdminTableContainer>
        </>
      )}
    </DetailSection>
  );
}
