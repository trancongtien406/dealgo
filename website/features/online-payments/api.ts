/** Ops online payment intents via BFF (/api/ops/payment-intents → /v1/ops/payment-intents). */
import type {
  IntentListFilter,
  OpsPaymentIntent,
  OpsPaymentIntentDetail,
  ReconcileSummary,
} from "@/features/online-payments/types";
import { intentListSearchParams } from "@/features/online-payments/mappers";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchPaymentIntents(filter: IntentListFilter): Promise<OpsPaymentIntent[]> {
  const envelope = await apiFetch<{ success: boolean; data: OpsPaymentIntent[] }>(
    `${apiPaths.opsPaymentIntents()}?${intentListSearchParams(filter).toString()}`,
  );
  return envelope.data;
}

export async function fetchPaymentIntent(id: string): Promise<OpsPaymentIntentDetail> {
  const envelope = await apiFetch<{ success: boolean; data: OpsPaymentIntentDetail }>(
    apiPaths.opsPaymentIntent(id),
  );
  return envelope.data;
}

export async function refundPaymentIntent(input: {
  id: string;
  amountVnd: number;
  reason: string;
  /** Stable per confirmed refund: a retry/double click replays instead of refunding twice. */
  idempotencyKey: string;
}): Promise<void> {
  await apiFetch<{ success: boolean }>(apiPaths.opsPaymentIntentRefund(input.id), {
    method: "POST",
    headers: { "Idempotency-Key": input.idempotencyKey },
    body: { amountVnd: input.amountVnd, reason: input.reason },
  });
}

export async function reconcilePaymentIntents(): Promise<ReconcileSummary> {
  const envelope = await apiFetch<{ success: boolean; data: ReconcileSummary }>(
    apiPaths.opsPaymentIntentsReconcile(),
    { method: "POST", body: {} },
  );
  return envelope.data;
}
