import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";
import { parseDriverBalance, type DriverBalance } from "@/lib/driver-balance";

export type DriverFeeBalance = { amountVnd: number; settledThrough: string | null };

export async function cancelAccountDeletion(id: string, reason: string): Promise<void> {
  await apiFetch(apiPaths.opsUserDeletionCancel(id), { method: "POST", body: { reason } });
}

export async function fetchDriverFeeBalance(id: string): Promise<DriverFeeBalance> {
  const res = await apiFetch<{ success: boolean; data: DriverFeeBalance }>(
    apiPaths.opsUserFeeBalance(id),
  );
  return {
    amountVnd: Number(res.data.amountVnd) || 0,
    settledThrough: res.data.settledThrough ?? null,
  };
}

export async function settleDriverFees(
  id: string,
  reason: string,
): Promise<{ amountVnd: number; settledThrough: string }> {
  const res = await apiFetch<{
    success: boolean;
    data: { amountVnd: number; settledThrough: string };
  }>(apiPaths.opsUserFeeSettlement(id), { method: "POST", body: { reason } });
  return res.data;
}

/** Partial driver payment / top-up (DRIVER_PAID) or DealGo payout (DEALGO_PAID). */
export async function recordDriverPayment(
  id: string,
  input: { direction: "DRIVER_PAID" | "DEALGO_PAID"; amountVnd: number; reason: string },
): Promise<{ id: string; adjustmentVnd: number }> {
  const res = await apiFetch<{
    success: boolean;
    data: { id: string; adjustmentVnd: number };
  }>(apiPaths.opsUserDriverPayment(id), { method: "POST", body: input });
  return res.data;
}

/** Fees + adjustments vs the configurable debt limit, with the recent ledger. */
export async function fetchDriverBalance(id: string): Promise<DriverBalance> {
  const res = await apiFetch<{ success: boolean; data: unknown }>(apiPaths.opsUserDriverBalance(id));
  return parseDriverBalance(res.data);
}
