import { mapNestLedgerJournal } from "@/features/ledger/mappers";
import type { NestLedgerJournal } from "@/features/ledger/nest-types";
import type { LedgerJournal } from "@/features/ledger/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchRideLedger(
  rideId: string,
): Promise<LedgerJournal | null> {
  return fetchLedger(apiPaths.opsRideLedger(rideId));
}

export async function fetchFoodOrderLedger(
  orderId: string,
): Promise<LedgerJournal | null> {
  return fetchLedger(apiPaths.opsFoodOrderLedger(orderId));
}

async function fetchLedger(path: string): Promise<LedgerJournal | null> {
  try {
    const envelope = await apiFetch<{
      success: boolean;
      data: NestLedgerJournal;
    }>(path);
    return mapNestLedgerJournal(envelope.data);
  } catch (error) {
    if (isNotFound(error)) {
      return null;
    }
    throw error;
  }
}

function isNotFound(error: unknown): boolean {
  return (
    typeof error === "object" &&
    error !== null &&
    "code" in error &&
    (error as { code: string }).code === "NOT_FOUND"
  );
}
