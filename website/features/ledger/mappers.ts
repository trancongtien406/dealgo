import type { NestLedgerJournal } from "@/features/ledger/nest-types";
import type { LedgerJournal } from "@/features/ledger/types";
import { formatOpsDateTime } from "@/lib/ops-time";

export function mapNestLedgerJournal(
  journal: NestLedgerJournal,
): LedgerJournal {
  return {
    id: journal.id,
    entityType: journal.entityType,
    entityId: journal.entityId,
    event: journal.event,
    status: journal.status,
    currency: journal.currency,
    amountVnd: journal.amountVnd,
    postedAt: journal.postedAt,
    postedAtLabel: formatOpsDateTime(journal.postedAt),
    entries: journal.entries.map((entry) => ({
      id: entry.id,
      accountCode: entry.accountCode,
      direction: entry.direction,
      amountVnd: entry.amountVnd,
    })),
  };
}
