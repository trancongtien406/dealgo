/** Ops payment methods: GET/PATCH /v1/ops/payment-methods via BFF (audited, settings.write). */
import type { OpsPaymentMethodsView, PaymentMethodPatch } from "@/features/payment-methods/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchPaymentMethods(): Promise<OpsPaymentMethodsView> {
  const envelope = await apiFetch<{ success: boolean; data: OpsPaymentMethodsView }>(
    apiPaths.opsPaymentMethods(),
  );
  return envelope.data;
}

export async function patchPaymentMethods(input: {
  methods?: PaymentMethodPatch[];
  walletEnabled?: boolean;
  reason: string;
}): Promise<void> {
  await apiFetch<{ success: boolean }>(apiPaths.opsPaymentMethods(), {
    method: "PATCH",
    body: input,
  });
}
