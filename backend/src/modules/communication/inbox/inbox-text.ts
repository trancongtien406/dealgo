import type { InboxCategory } from './inbox.repository.js';

/**
 * Server-side copy for inbox rows (Vietnamese, the app's default locale). The row also keeps
 * `data.status` / `data.aggregateType` so the app can render its own localized text.
 */
const RIDE_TEXT: Record<string, { title: string; body: string }> = {
  ASSIGNED: { title: 'Đã có tài xế nhận chuyến', body: 'Tài xế đang chuẩn bị đến điểm đón.' },
  DRIVER_EN_ROUTE: { title: 'Tài xế đang đến', body: 'Tài xế đang trên đường đến điểm đón.' },
  DRIVER_ARRIVED: { title: 'Tài xế đã đến điểm đón', body: 'Hãy ra điểm đón và đọc mã cho tài xế.' },
  IN_TRIP: { title: 'Chuyến đi đã bắt đầu', body: 'Chúc bạn có chuyến đi an toàn.' },
  COMPLETED: { title: 'Chuyến đi hoàn thành', body: 'Cảm ơn bạn đã đi cùng DealGo.' },
  CANCELLED: { title: 'Chuyến đi đã hủy', body: 'Chuyến đi đã được hủy.' },
  EXPIRED: { title: 'Yêu cầu đặt xe đã hết hạn', body: 'Chưa có tài xế nhận chuyến. Bạn có thể đặt lại.' },
};

const FOOD_TEXT: Record<string, { title: string; body: string }> = {
  PREPARING: { title: 'Quán đang chuẩn bị món', body: 'Đơn của bạn đã được quán xác nhận.' },
  READY: { title: 'Món đã sẵn sàng', body: 'Đang tìm tài xế giao đơn của bạn.' },
  ASSIGNED: { title: 'Đã có tài xế nhận đơn', body: 'Tài xế đang đến quán lấy món.' },
  PICKED_UP: { title: 'Tài xế đã lấy món', body: 'Đơn đang trên đường giao đến bạn.' },
  DELIVERED: { title: 'Đơn đã giao thành công', body: 'Chúc bạn ngon miệng.' },
  FAILED: { title: 'Giao đơn không thành công', body: 'Đơn chưa giao được. Liên hệ hỗ trợ nếu cần.' },
  CANCELLED: { title: 'Đơn đã hủy', body: 'Đơn đồ ăn đã được hủy.' },
};

export function statusInboxText(
  aggregateType: string,
  status: string,
): { category: InboxCategory; title: string; body: string } | null {
  if (aggregateType === 'Ride') {
    const text = RIDE_TEXT[status];
    return text ? { category: 'RIDE', ...text } : null;
  }
  if (aggregateType === 'FoodOrder') {
    const text = FOOD_TEXT[status];
    return text ? { category: 'FOOD', ...text } : null;
  }
  return null;
}
