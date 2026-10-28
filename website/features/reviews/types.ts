export type StoreReview = {
  id: string;
  storeId: string;
  storeName: string;
  stars: number;
  tags: string[];
  comment: string | null;
  merchantReply: string | null;
  repliedAt: string | null;
  createdAt: string;
  hidden: boolean;
  hiddenAt: string | null;
  hiddenReason: string | null;
};

export type ReviewVisibilityFilter = "VISIBLE" | "HIDDEN";
