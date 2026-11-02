import { describe, expect, it } from 'vitest';
import { notificationsFor, foodOrderChangeNotifications, rideOfferReceivedNotification } from './notification-audience.js';
import { chatPushPathFor, pushPathFor } from './push-path.js';

const P = { customerId: 'c1', driverId: 'd1', merchantId: 'm1' };

describe('push tap paths', () => {
  it('ride: customer offer → offers, status → tracking; driver → active, request/cancel → jobs', () => {
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'CUSTOMER', kind: 'offer' })).toBe('/customer/ride/offers/r1');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'CUSTOMER', status: 'DRIVER_ARRIVED' })).toBe('/customer/ride/tracking/r1');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'CUSTOMER', status: 'CANCELLED' })).toBe('/customer/ride/tracking/r1');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', status: 'ASSIGNED' })).toBe('/driver/rides/r1/active');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', kind: 'request' })).toBe('/driver/jobs');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', status: 'CANCELLED' })).toBe('/driver/jobs');
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', kind: 'chat' })).toBe('/driver/rides/r1/active');
  });

  it('food: each role opens its own order page; a cancelled job sends partners to the list', () => {
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'CUSTOMER', status: 'PICKED_UP' })).toBe('/customer/food/orders/o1');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'CUSTOMER', status: 'CANCELLED' })).toBe('/customer/shop');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'CUSTOMER', status: 'REJECTED' })).toBe('/customer/shop');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'MERCHANT', status: 'PLACED' })).toBe('/merchant/orders/o1');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'MERCHANT', status: 'CANCELLED' })).toBe('/merchant/orders');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'DRIVER', status: 'ASSIGNED' })).toBe('/driver/food/o1');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'DRIVER', status: 'CANCELLED' })).toBe('/driver/jobs');
    expect(pushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'DRIVER', kind: 'request' })).toBe('/driver/jobs');
  });

  it('a chat push opens the conversation over job pages that have one', () => {
    expect(chatPushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'DRIVER', status: 'DRIVER_ARRIVED' })).toBe('/driver/rides/r1/active?chat=1');
    expect(chatPushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'CUSTOMER', status: 'IN_TRIP' })).toBe('/customer/ride/tracking/r1?chat=1');
    expect(chatPushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'CUSTOMER', status: 'PICKED_UP' })).toBe('/customer/food/orders/o1?chat=1');
    expect(chatPushPathFor({ aggregateType: 'FoodOrder', aggregateId: 'o1', role: 'DRIVER', status: 'PICKED_UP' })).toBe('/driver/food/o1?chat=1');
    // Pages without a chat sheet keep the plain path.
    expect(chatPushPathFor({ aggregateType: 'Ride', aggregateId: 'r1', role: 'CUSTOMER', status: 'NEGOTIATING' })).toBe('/customer/ride/offers/r1');
  });

  it('support, partner, campaign and unknown aggregates', () => {
    expect(pushPathFor({ aggregateType: 'SupportTicket', aggregateId: 't 1', role: 'DRIVER' })).toBe('/driver/account/help/tickets/t%201');
    expect(pushPathFor({ aggregateType: 'PartnerApplication', aggregateId: 'a1', role: 'CUSTOMER', partnerRole: 'MERCHANT' })).toBe('/merchant/kyb/status');
    expect(pushPathFor({ aggregateType: 'PartnerApplication', aggregateId: 'a1', role: 'CUSTOMER', partnerRole: 'DRIVER' })).toBe('/driver/kyc/status');
    expect(pushPathFor({ aggregateType: 'Other', aggregateId: 'x', role: 'CUSTOMER' })).toBeNull();
    expect(pushPathFor({ aggregateType: 'Ride', aggregateId: ' ', role: 'CUSTOMER' })).toBeNull();
  });

  it('every role-aware notification names its recipient role', () => {
    const all = [
      ...notificationsFor('Ride', 'r1', 'ASSIGNED', P),
      ...notificationsFor('Ride', 'r1', 'CANCELLED', P),
      ...notificationsFor('FoodOrder', 'o1', 'PLACED', P),
      ...notificationsFor('FoodOrder', 'o1', 'ASSIGNED', P),
      ...notificationsFor('FoodOrder', 'o1', 'CANCELLED', P),
      ...foodOrderChangeNotifications('o1', 'PENDING', P),
      ...foodOrderChangeNotifications('o1', 'ACCEPTED', P),
      rideOfferReceivedNotification('c1', 'r1'),
    ];
    const expected: Record<string, string> = { c1: 'CUSTOMER', d1: 'DRIVER', m1: 'MERCHANT' };
    for (const n of all) {
      expect(n.role).toBe(expected[n.userId]);
    }
  });
});
