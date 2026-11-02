import type { LegalPolicyVersion } from "@/features/legal-consent/types";

/** Two-step send: preview the recipient count first, then confirm that exact count. */
export type EmailStep =
  | { kind: "done"; label: string }
  | { kind: "preview" }
  | { kind: "confirm"; count: number }
  | { kind: "empty" };

export function emailStep(v: Pick<LegalPolicyVersion, "emailStatus" | "emailSentCount" | "emailRecipients">, previewCount: number | null): EmailStep {
  if (v.emailStatus !== "NONE") {
    return { kind: "done", label: `${v.emailSentCount}/${v.emailRecipients ?? 0} email` };
  }
  if (previewCount === null) return { kind: "preview" };
  if (previewCount === 0) return { kind: "empty" };
  return { kind: "confirm", count: previewCount };
}

export function publishErrors(input: { changelog: string; audienceRoles: string[] }): string | null {
  if (input.changelog.trim().length < 3) return "Tóm tắt thay đổi cần ít nhất 3 ký tự.";
  if (input.audienceRoles.length === 0) return "Chọn ít nhất một nhóm người dùng.";
  return null;
}
