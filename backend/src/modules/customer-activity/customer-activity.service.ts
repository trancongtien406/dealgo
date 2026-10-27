import { Injectable } from '@nestjs/common';
import { FoodService } from '../food-order/food.service.js';
import { RideService } from '../ride/ride.service.js';

export type CustomerActiveTrip =
  | { kind: 'RIDE'; id: string; status: string }
  | { kind: 'FOOD_ORDER'; id: string; status: string }
  | null;

/**
 * DEC-PROD-057: after a relaunch the customer app asks for the trip it should
 * reopen. A live ride wins over an open food order (rides are time-critical).
 */
@Injectable()
export class CustomerActivityService {
  constructor(
    private readonly rides: RideService,
    private readonly food: FoodService,
  ) {}

  async activeTrip(customerId: string): Promise<{ trip: CustomerActiveTrip }> {
    const ride = await this.rides.activeRideForCustomer(customerId);
    if (ride) {
      return { trip: { kind: 'RIDE', ...ride } };
    }
    const order = await this.food.activeOrderForCustomer(customerId);
    if (order) {
      return { trip: { kind: 'FOOD_ORDER', ...order } };
    }
    return { trip: null };
  }
}
