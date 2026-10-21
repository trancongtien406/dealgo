import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

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
