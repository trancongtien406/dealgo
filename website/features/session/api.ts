import type { LoginInput } from "@/features/session/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function login(input: LoginInput): Promise<void> {
  await apiFetch(apiPaths.opsSession(), {
    method: "POST",
    body: input,
  });
}

export async function logout(): Promise<void> {
  await apiFetch(apiPaths.opsSession(), {
    method: "DELETE",
  });
}
