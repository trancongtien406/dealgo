export const MODERATION_STATUSES = [
  "PENDING",
  "APPROVED",
  "REJECTED",
  "NEEDS_REVISION",
] as const;
export type ModerationStatus = (typeof MODERATION_STATUSES)[number];

export type ModeratedProduct = {
  id: string;
  code: string;
  name: string;
  category: string;
  store: string;
  price: number;
  submittedAt: string;
  status: ModerationStatus;
  nameReady: boolean;
  imageReady: boolean;
};
