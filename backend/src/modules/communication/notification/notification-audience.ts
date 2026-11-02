import type { InboxCategory } from '../inbox/inbox.repository.js';
import { statusInboxText } from '../inbox/inbox-text.js';
import type { PushRole } from './push-path.js';

/** Who took part in a ride / food order, by role (only ids; no PII). */
export type Participants = {
  customerId: string;
  driverId?: string | null;
  /** Store owner (food only). */
  merchantId?: string | null;
};

export type RoleNotification = {
  userId: string;
  /** Recipient role, used to pick the tap deep-link path (push-path.ts). */
  role?: PushRole;
  category: InboxCategory;
  title: string;
  body: string;
};

/** Last 4 letters/digits, same handover code the apps show (OPEN-011 / DEC-PROD-047). */
export function shortOrderCode(id: string): string {
  const compact = id.replace(/[^A-Za-z0-9]/g, '').toUpperCase();
  return `#${compact.slice(-4)}`;
}

/**
 * Role-aware push/inbox copy (Grab/ShopeeFood/Uber pattern: each party only hears about
 * the step that concerns them). Customer gets the status copy from inbox-text; the merchant
 * hears "new order" / cancellations; the driver hears "you were selected" / cancellations.
 */
export function notificationsFor(
  aggregateType: string,
  aggregateId: string,
  status: string,
  p: Participants,
): RoleNotification[] {
  const out: RoleNotification[] = [];
  const code = shortOrderCode(aggregateId);
  const customerText = statusInboxText(aggregateType, status);
  if (aggregateType === 'Ride') {
    if (customerText) {
      out.push({ userId: p.customerId, role: 'CUSTOMER', ...customerText });
    }
    if (p.driverId && status === 'ASSIGNED') {
      out.push({
        userId: p.driverId,
        role: 'DRIVER',
        category: 'RIDE',
        title: 'Khách đã chọn bạn',
        body: `Chuyến ${code}: hãy di chuyển đến điểm đón.`,
      });
    }
    if (p.driverId && status === 'CANCELLED') {
      out.push({ userId: p.driverId, role: 'DRIVER', category: 'RIDE', title: 'Chuyến đã bị hủy', body: `Chuyến ${code} đã được hủy.` });
    }
    return dedupe(out);
  }
  if (aggregateType === 'FoodOrder') {
    if (status === 'PLACED') {
      if (p.merchantId) {
        out.push({
          userId: p.merchantId,
          role: 'MERCHANT',
          category: 'FOOD',
          title: `Đơn mới ${code}`,
          body: 'Có đơn hàng mới đang chờ quán xác nhận.',
        });
      }
      return out;
    }
    if (customerText) {
      out.push({ userId: p.customerId, role: 'CUSTOMER', ...customerText });
    }
    if (status === 'CANCELLED') {
      for (const [id, role] of [
        [p.merchantId, 'MERCHANT'],
        [p.driverId, 'DRIVER'],
      ] as const) {
        if (id) {
          out.push({ userId: id, role, category: 'FOOD', title: `Đơn ${code} đã hủy`, body: 'Đơn hàng này đã được hủy.' });
        }
      }
    }
    if (status === 'ASSIGNED' && p.merchantId) {
      out.push({
        userId: p.merchantId,
        role: 'MERCHANT',
        category: 'FOOD',
        title: `Tài xế đang đến lấy đơn ${code}`,
        body: 'Đối chiếu mã đơn khi giao món cho tài xế.',
      });
    }
    return dedupe(out);
  }
  return out;
}

/**
 * Merchant edited a food order. PENDING asks the customer to confirm; ACCEPTED tells
 * the store to keep cooking. Decline / expiry arrive as the normal CANCELLED status push.
 */
/** Delivery-fee negotiation: a driver counter rings the customer (raises refresh drivers by socket). */
export function foodOrderFareNotifications(
  orderId: string,
  fareEvent: string,
  amountVnd: number | null,
  p: Participants,
): RoleNotification[] {
  if (fareEvent !== 'COUNTER') {
    return [];
  }
  const code = shortOrderCode(orderId);
  const amount =
    amountVnd != null ? ` ${amountVnd.toLocaleString('vi-VN')}đ` : '';
  return [
    {
      userId: p.customerId,
      role: 'CUSTOMER',
      category: 'FOOD',
      title: `Tài xế đề xuất phí giao${amount} cho đơn ${code}`,
      body: 'Mở ứng dụng để xem và chọn tài xế, hoặc tiếp tục chờ.',
    },
  ];
}

export function foodOrderChangeNotifications(
  orderId: string,
  changeStatus: string,
  p: Participants,
): RoleNotification[] {
  const code = shortOrderCode(orderId);
  if (changeStatus === 'PENDING') {
    return [
      {
        userId: p.customerId,
        role: 'CUSTOMER',
        category: 'FOOD',
        title: `Quán đã điều chỉnh đơn ${code}`,
        body: 'Một số món đã hết hoặc thiếu phần. Mở ứng dụng để đồng ý giá mới hoặc hủy đơn miễn phí.',
      },
    ];
  }
  if (changeStatus === 'ACCEPTED' && p.merchantId) {
    return [
      {
        userId: p.merchantId,
        role: 'MERCHANT',
        category: 'FOOD',
        title: `Khách đã đồng ý điều chỉnh đơn ${code}`,
        body: 'Tiếp tục chuẩn bị đơn theo số món mới.',
      },
    ];
  }
  return [];
}

/** Partner application decided by ops. */
export function partnerStatusNotification(userId: string, role: string, status: string): RoleNotification | null {
  const who = role === 'MERCHANT' ? 'cửa hàng' : 'tài xế';
  if (status === 'APPROVED') {
    return { userId, category: 'SYSTEM', title: 'Hồ sơ đã được duyệt', body: `Hồ sơ ${who} của bạn đã được duyệt. Bạn có thể bắt đầu ngay.` };
  }
  if (status === 'REJECTED') {
    return { userId, category: 'SYSTEM', title: 'Hồ sơ chưa được duyệt', body: `Hồ sơ ${who} cần bổ sung. Mở ứng dụng để xem chi tiết.` };
  }
  return null;
}

/** Customer: a driver sent an offer / counter on a bidding ride. */
export function rideOfferReceivedNotification(customerId: string, rideId: string): RoleNotification {
  return {
    userId: customerId,
    role: 'CUSTOMER',
    category: 'RIDE',
    title: 'Có tài xế báo giá',
    body: `Chuyến ${shortOrderCode(rideId)}: mở ứng dụng để chọn tài xế.`,
  };
}

/** A new nearby ride request for a driver whose app is in the background. */
export function rideRequestNearbyNotification(
  driverId: string,
  ride: { id: string; offeredFareVnd: number; pickup: { label: string }; dropoff: { label: string } },
): RoleNotification {
  const fare = ride.offeredFareVnd.toLocaleString('vi-VN');
  return {
    userId: driverId,
    role: 'DRIVER',
    category: 'RIDE',
    title: `Cuốc xe mới gần bạn · ${fare}đ`,
    body: `${ride.pickup.label} → ${ride.dropoff.label}`,
  };
}

/** Ready food order near an online food driver (sent by the outbox relay on READY). */
export function foodRequestNearbyNotification(
  driverId: string,
  order: { id: string; deliveryFareVnd: number; storeName: string | null; dropoffLabel: string },
): RoleNotification {
  const fare = order.deliveryFareVnd.toLocaleString('vi-VN');
  return {
    userId: driverId,
    role: 'DRIVER',
    category: 'FOOD',
    title: `Đơn giao đồ ăn mới gần bạn · ${fare}đ`,
    body: `${order.storeName ?? 'Quán'} → ${order.dropoffLabel}`,
  };
}

function dedupe(list: RoleNotification[]): RoleNotification[] {
  const seen = new Set<string>();
  return list.filter((n) => (seen.has(n.userId) ? false : (seen.add(n.userId), true)));
}

/** Driver-facing reason for losing an assigned ride (inbox + push body). */
export function rideUnassignedReasonText(reasonCode: string): string {
  switch (reasonCode) {
    case 'ASSIGNED_TIMEOUT':
      return 'Bạn chưa bắt đầu đi đón trong thời gian quy định nên chuyến đã được mở lại cho tài xế khác.';
    case 'EN_ROUTE_TIMEOUT':
      return 'Bạn chưa đến điểm đón trong thời gian quy định nên chuyến đã được mở lại cho tài xế khác.';
    case 'OPS_REASSIGN':
      return 'Tổng đài đã chuyển chuyến này cho tài xế khác.';
    default:
      return 'Chuyến đã được mở lại cho tài xế khác.';
  }
}

/**
 * A ride went back to offers after its driver was dropped. The dropped driver hears why (unless
 * they dropped it themselves), and the customer hears that we are finding another driver.
 */
export function rideUnassignedNotifications(
  rideId: string,
  drop: { customerId: string; droppedDriverId: string; actor: string; reasonCode: string },
): RoleNotification[] {
  const code = shortOrderCode(rideId);
  const out: RoleNotification[] = [];
  if (drop.actor !== 'DRIVER') {
    out.push({
      userId: drop.droppedDriverId,
      role: 'DRIVER',
      category: 'RIDE',
      title: `Chuyến ${code} đã chuyển cho tài xế khác`,
      body: rideUnassignedReasonText(drop.reasonCode),
    });
  }
  out.push({
    userId: drop.customerId,
    role: 'CUSTOMER',
    category: 'RIDE',
    title: 'Đang tìm tài xế khác',
    body: `Tài xế trước không thể tiếp tục chuyến ${code}. Chuyến đã mở lại để nhận báo giá mới.`,
  });
  return out;
}
