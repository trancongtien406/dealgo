import type {
  DriverCreditSummary,
  DriverTopUp,
  DriverTopUpFilter,
  DriverTopUpStatus,
} from "@/features/driver-credit/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

type Envelope<T> = { success: boolean; data: T };

export async function fetchDriverTopUps(
  filter: DriverTopUpFilter,
): Promise<DriverTopUp[]> {
  const search = new URLSearchParams();
  if (filter.status && filter.status !== "ALL") {
    search.set("status", filter.status);
  }
  if (filter.driverId) {
    search.set("driverId", filter.driverId);
  }
  search.set("limit", String(filter.limit ?? 50));
  const query = search.toString();
  const envelope = await apiFetch<Envelope<DriverTopUp[]>>(
    `${apiPaths.opsDriverCreditTopUps()}?${query}`,
  );
  return envelope.data;
}

export async function fetchDriverCreditSummary(): Promise<DriverCreditSummary> {
  const envelope = await apiFetch<Envelope<DriverCreditSummary>>(
    apiPaths.opsDriverCreditSummary(),
  );
  return envelope.data;
}

export async function reconcileDriverTopUp(id: string): Promise<{
  id: string;
  status: DriverTopUpStatus;
  amountVnd: number;
}> {
  const envelope = await apiFetch<Envelope<DriverTopUp>>(
    apiPaths.opsDriverCreditTopUpReconcile(id),
    { method: "POST" },
  );
  return envelope.data;
}

export async function reconcilePendingDriverTopUps(): Promise<{
  checked: number;
  captured: number;
  closed: number;
}> {
  const envelope = await apiFetch<
    Envelope<{ checked: number; captured: number; closed: number }>
  >(apiPaths.opsDriverCreditReconcile(), { method: "POST" });
  return envelope.data;
}

export async function refundDriverTopUp(
  id: string,
  input: { reason: string; bankRef: string },
): Promise<{
  id: string;
  status: DriverTopUpStatus;
  remainingVnd: number;
  refundedVnd: number;
}> {
  const envelope = await apiFetch<Envelope<DriverTopUp>>(
    apiPaths.opsDriverCreditTopUpRefund(id),
    { method: "POST", body: JSON.stringify(input) },
  );
  return envelope.data;
}
