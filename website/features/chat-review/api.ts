import { apiFetch } from "@/lib/api/client";
import type { ChatReviewBody } from "@/lib/api/ops-chat-review-body";
import { apiPaths } from "@/lib/api/paths";

export type ChatReviewMessage = {
  id: string;
  senderUserId: string;
  senderName: string;
  senderRole: "CUSTOMER" | "PARTNER";
  body: string;
  createdAt: string;
};

export type ChatReviewResult = {
  threadId: string | null;
  kind: "ride" | "food";
  id: string;
  retentionDays: number;
  messages: ChatReviewMessage[];
};

export async function reviewChat(body: ChatReviewBody): Promise<ChatReviewResult> {
  const envelope = await apiFetch<{ success: boolean; data: ChatReviewResult }>(
    apiPaths.opsChatReview(),
    { method: "POST", body },
  );
  return envelope.data;
}
