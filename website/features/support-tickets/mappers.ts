import type { StatusTone } from "@/lib/admin-format";
import type { SearchSelectOption } from "@/components/ui/search-select";
import type {
  SupportTicket,
  SupportTicketCategory,
  SupportTicketPriority,
  SupportTicketStatus,
} from "@/features/support-tickets/types";

export const supportStatusLabel: Record<SupportTicketStatus, string> = {
  OPEN: "Mới tiếp nhận",
  IN_PROGRESS: "Đang xử lý",
  RESOLVED: "Đã giải quyết",
  CLOSED: "Đã đóng",
};

export const supportStatusTone: Record<SupportTicketStatus, StatusTone> = {
  OPEN: "danger",
  IN_PROGRESS: "food",
  RESOLVED: "success",
  CLOSED: "brand",
};

export const supportPriorityLabel: Record<SupportTicketPriority, string> = {
  LOW: "Thấp",
  NORMAL: "Bình thường",
  HIGH: "Cao",
  URGENT: "Khẩn cấp",
};

export const supportPriorityTone: Record<SupportTicketPriority, StatusTone> = {
  LOW: "brand",
  NORMAL: "delivery",
  HIGH: "food",
  URGENT: "danger",
};

export const supportCategoryLabel: Record<SupportTicketCategory, string> = {
  RIDE: "Chuyến đi",
  FOOD: "Đồ ăn",
  PAYMENT: "Thanh toán",
  ACCOUNT: "Tài khoản",
  SAFETY: "An toàn",
  OTHER: "Khác",
};

export const supportRoleLabel: Record<string, string> = {
  CUSTOMER: "Khách hàng",
  DRIVER: "Tài xế",
  MERCHANT: "Chủ quán",
  OTHER: "Khác",
};

function options<K extends string>(labels: Record<K, string>): SearchSelectOption[] {
  return (Object.keys(labels) as K[]).map((value) => ({ value, label: labels[value] }));
}

export const supportStatusOptions = options(supportStatusLabel);
export const supportPriorityOptions = options(supportPriorityLabel);
export const supportCategoryOptions = options(supportCategoryLabel);
export const supportChannelOptions: SearchSelectOption[] = [
  { value: "APP", label: "Ứng dụng" },
  { value: "WEB", label: "Website" },
];

/** Who wrote in: the app account, or the name/contact typed on the website form. */
export function requesterLine(ticket: SupportTicket): { name: string; contact: string } {
  if (ticket.requester) {
    return {
      name: ticket.requester.displayName || "Người dùng DealGo",
      contact: ticket.requester.phone ?? ticket.requester.email ?? "—",
    };
  }
  return { name: ticket.contactName || "Khách vãng lai", contact: ticket.contact ?? "—" };
}

/** The ticket's linked job as an Admin link, or the free-text code typed on the web form. */
export function relatedLink(ticket: SupportTicket): { href: string | null; label: string } | null {
  if (ticket.relatedType && ticket.relatedId) {
    const short = ticket.relatedId.replace(/-/g, "").slice(-6).toUpperCase();
    return ticket.relatedType === "RIDE"
      ? { href: `/rides/${ticket.relatedId}`, label: `Chuyến #${short}` }
      : { href: `/food-orders/${ticket.relatedId}`, label: `Đơn #${short}` };
  }
  if (ticket.externalRef) {
    return { href: null, label: ticket.externalRef };
  }
  return null;
}

const dateTime = new Intl.DateTimeFormat("vi-VN", {
  timeZone: "Asia/Ho_Chi_Minh",
  day: "2-digit",
  month: "2-digit",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
});

export function formatTicketTime(iso: string | null | undefined): string {
  if (!iso) return "—";
  const date = new Date(iso);
  return Number.isNaN(date.getTime()) ? "—" : dateTime.format(date);
}

/** Status moves Ops can make from the current status. */
export function nextStatuses(status: SupportTicketStatus): SupportTicketStatus[] {
  switch (status) {
    case "OPEN":
      return ["IN_PROGRESS", "RESOLVED", "CLOSED"];
    case "IN_PROGRESS":
      return ["RESOLVED", "CLOSED"];
    case "RESOLVED":
      return ["IN_PROGRESS", "CLOSED"];
    case "CLOSED":
      return ["IN_PROGRESS"];
  }
}

/** Same-origin BFF URL that streams one message attachment for ops staff. */
export function supportAttachmentUrl(
  ticketId: string,
  messageId: string,
  index: number,
): string {
  return `/api/ops/support-tickets/${encodeURIComponent(ticketId)}/messages/${encodeURIComponent(messageId)}/attachments/${index}`;
}
