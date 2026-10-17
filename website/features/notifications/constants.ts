export const NOTIFICATION_TABLE_COLUMNS = [
  { id: "code", label: "Mã chiến dịch" },
  { id: "title", label: "Chiến dịch & nội dung" },
  { id: "channel", label: "Kênh" },
  { id: "audience", label: "Đối tượng" },
  { id: "sentAt", label: "Thời điểm gửi" },
  { id: "status", label: "Trạng thái" },
  { id: "delivered", label: "Đã tiếp cận", align: "right" as const },
  { id: "action", label: "Thao tác" },
] as const;

export const NOTIFICATION_COLUMN_COUNT = NOTIFICATION_TABLE_COLUMNS.length;
