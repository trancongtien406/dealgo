/**
 * Ops auth-method controls (DEC-PROD-006 / FR-OPS-010).
 * Nest GET/PATCH /v1/ops/auth-methods via BFF.
 */
import { mapNestAuthMethod } from "@/features/auth-methods/mappers";
import type { NestAuthMethod } from "@/features/auth-methods/nest-types";
import type { AuthMethod, AuthMethodRow } from "@/features/auth-methods/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchAuthMethods(): Promise<AuthMethodRow[]> {
  return fetchAuthMethodsFromBff();
}

export async function patchAuthMethod(
  method: AuthMethod,
  input: { enabled: boolean; reason: string },
): Promise<AuthMethodRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestAuthMethod;
  }>(apiPaths.opsAuthMethod(method), {
    method: "PATCH",
    body: { enabled: input.enabled, reason: input.reason },
  });
  return mapNestAuthMethod(envelope.data);
}

async function fetchAuthMethodsFromBff(): Promise<AuthMethodRow[]> {
  const envelope = await apiFetch<{
    success: boolean;
    data: NestAuthMethod[];
  }>(apiPaths.opsAuthMethods());
  return envelope.data.map(mapNestAuthMethod);
}
