/**
 * The in-app page a tapped push should open, per recipient role.
 * Paths mirror the Flutter go_router table (mobile/lib/app/router/app_router.dart). The app
 * re-checks the path against the signed-in roles and falls back to the inbox, so a stale
 * or foreign path never strands the user (Grab / Uber pattern: a tap lands on the job itself).
 */
export type PushRole = 'CUSTOMER' | 'DRIVER' | 'MERCHANT';

export type PushPathInput = {
  aggregateType: string;
  aggregateId: string;
  role: PushRole;
  status?: string;
  /** offer = a driver bid reached the customer; request = a nearby ride for a driver; chat = new message. */
  kind?: 'status' | 'offer' | 'request' | 'chat';
  /** Partner applications: which onboarding flow (DRIVER/MERCHANT). */
  partnerRole?: string;
};

const ROLE_HOME: Record<PushRole, string> = {
  CUSTOMER: '/customer',
  DRIVER: '/driver',
  MERCHANT: '/merchant',
};

/** Statuses where the job is gone for the partner; open the list instead of a dead detail page. */
const PARTNER_GONE = new Set(['CANCELLED', 'EXPIRED', 'FAILED']);

function seg(id: string): string {
  return encodeURIComponent(id);
}

export function pushPathFor(input: PushPathInput): string | null {
  const id = input.aggregateId?.trim();
  if (!id) {
    return null;
  }
  const status = input.status ?? '';
  switch (input.aggregateType) {
    case 'Ride':
      return ridePath(id, input.role, status, input.kind);
    case 'FoodOrder':
      return foodPath(id, input.role, status, input.kind);
    case 'SupportTicket':
      return `${ROLE_HOME[input.role]}/account/help/tickets/${seg(id)}`;
    case 'PartnerApplication':
      return input.partnerRole === 'MERCHANT' ? '/merchant/kyb/status' : '/driver/kyc/status';
    case 'NotificationCampaign':
      return `${ROLE_HOME[input.role]}/account/notifications`;
    default:
      return null;
  }
}

/** Job pages with a chat button; a chat push opens the conversation over them (`?chat=1`). */
const CHAT_PAGES = [
  /^\/customer\/ride\/tracking\/[^/?]+$/,
  /^\/driver\/rides\/[^/?]+\/active$/,
  /^\/customer\/food\/orders\/[^/?]+$/,
  /^\/driver\/food\/[^/?]+$/,
  /^\/merchant\/orders\/[^/?]+$/,
];

/**
 * Path for a "new message" push: the job page plus `?chat=1`, which the app reads to open
 * the chat sheet straight away (Grab / Uber: tapping a message lands in the conversation).
 * Pages without a chat (e.g. a cancelled job's list) are returned unchanged.
 */
export function chatPushPathFor(
  input: Omit<PushPathInput, 'kind'> & { channel?: 'DRIVER' | 'MERCHANT' },
): string | null {
  const { channel, ...rest } = input;
  const path = pushPathFor({ ...rest, kind: 'chat' });
  if (path && CHAT_PAGES.some((page) => page.test(path))) {
    // The customer's order page hosts both threads; `chat=shop` opens the shop one.
    const which = channel === 'MERCHANT' && input.role === 'CUSTOMER' ? 'shop' : '1';
    return `${path}?chat=${which}`;
  }
  return path;
}

function ridePath(id: string, role: PushRole, status: string, kind?: PushPathInput['kind']): string | null {
  if (role === 'DRIVER') {
    // NEGOTIATING reaches a driver only when they lost the ride (timeout / reassign).
    if (kind === 'request' || PARTNER_GONE.has(status) || status === 'NEGOTIATING') {
      return '/driver/jobs';
    }
    return `/driver/rides/${seg(id)}/active`;
  }
  if (role === 'CUSTOMER') {
    if (kind === 'offer' || status === 'NEGOTIATING') {
      return `/customer/ride/offers/${seg(id)}`;
    }
    return `/customer/ride/tracking/${seg(id)}`;
  }
  return null;
}

function foodPath(id: string, role: PushRole, status: string, kind?: PushPathInput['kind']): string | null {
  if (role === 'CUSTOMER') {
    // A declined / gone order has no live tracking page. The detail route is
    // above the shell, so the tap opens Shop (bottom nav) instead.
    if (kind !== 'chat' && (PARTNER_GONE.has(status) || status === 'REJECTED')) {
      return '/customer/shop';
    }
    return `/customer/food/orders/${seg(id)}`;
  }
  if (role === 'DRIVER') {
    if (kind === 'request') return '/driver/jobs';
    return PARTNER_GONE.has(status) && kind !== 'chat' ? '/driver/jobs' : `/driver/food/${seg(id)}`;
  }
  return PARTNER_GONE.has(status) ? '/merchant/orders' : `/merchant/orders/${seg(id)}`;
}
