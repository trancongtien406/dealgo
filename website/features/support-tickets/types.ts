export type SupportTicketStatus = "OPEN" | "IN_PROGRESS" | "RESOLVED" | "CLOSED";
export type SupportTicketPriority = "LOW" | "NORMAL" | "HIGH" | "URGENT";
export type SupportTicketCategory =
  | "RIDE"
  | "FOOD"
  | "PAYMENT"
  | "ACCOUNT"
  | "SAFETY"
  | "OTHER";
export type SupportTicketChannel = "APP" | "WEB";

export type SupportTicketMessage = {
  id: string;
  author: "REQUESTER" | "STAFF";
  authorUserId: string | null;
  body: string;
  createdAt: string;
  attachments?: SupportTicketAttachment[];
};

export type SupportTicketAttachment = {
  index: number;
  label: string | null;
  contentType: string;
  sizeBytes: number;
};

export type SupportTicket = {
  id: string;
  code: string;
  channel: SupportTicketChannel;
  category: SupportTicketCategory;
  subject: string;
  status: SupportTicketStatus;
  priority: SupportTicketPriority;
  requesterRole: string;
  requester: {
    userId: string;
    displayName: string;
    phone: string | null;
    email: string | null;
  } | null;
  contactName: string | null;
  contact: string | null;
  externalRef: string | null;
  relatedType: "RIDE" | "FOOD_ORDER" | null;
  relatedId: string | null;
  awaitingRequester: boolean;
  lastMessagePreview?: string;
  lastMessageAt: string;
  resolvedAt: string | null;
  closedAt: string | null;
  createdAt: string;
  updatedAt: string;
  messages?: SupportTicketMessage[];
};

export type SupportTicketPage = {
  items: SupportTicket[];
  total: number;
  page: number;
  limit: number;
};
