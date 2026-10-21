import { mapNestFaq } from "@/features/faqs/mappers";
import type {
  FaqAudience,
  FaqCategory,
  FaqRow,
  FaqStatus,
} from "@/features/faqs/types";
import { apiFetch } from "@/lib/api/client";
import { apiPaths } from "@/lib/api/paths";

export async function fetchFaqs(status?: FaqStatus): Promise<FaqRow[]> {
  const search = status ? `?status=${encodeURIComponent(status)}` : "";
  const envelope = await apiFetch<{
    success: boolean;
    data: Array<Parameters<typeof mapNestFaq>[0]>;
  }>(`${apiPaths.opsFaqs()}${search}`);
  return envelope.data.map(mapNestFaq);
}

export async function patchFaq(
  id: string,
  input: {
    question?: string;
    suggestedAnswer?: string;
    status?: FaqStatus;
    category?: FaqCategory;
    audience?: FaqAudience;
    reason: string;
  },
): Promise<FaqRow> {
  const envelope = await apiFetch<{
    success: boolean;
    data: Parameters<typeof mapNestFaq>[0];
  }>(apiPaths.opsFaq(id), {
    method: "PATCH",
    body: input,
  });
  return mapNestFaq(envelope.data);
}
