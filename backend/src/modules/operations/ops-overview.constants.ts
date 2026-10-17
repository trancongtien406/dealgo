/** Calendar-day boundary for “today” KPIs (Vietnam, no DST). */
export const OPS_KPI_TODAY_TIMEZONE = 'Asia/Ho_Chi_Minh' as const;

/** Fixed offset for Asia/Ho_Chi_Minh (no daylight saving). */
export const OPS_KPI_TODAY_UTC_OFFSET_HOURS = 7;

export const RIDE_OPEN_STATUSES = [
  'NEGOTIATING',
  'ASSIGNED',
  'DRIVER_EN_ROUTE',
  'DRIVER_ARRIVED',
  'IN_TRIP',
] as const;

export const FOOD_IN_FLIGHT_STATUSES = [
  'PLACED',
  'PREPARING',
  'READY',
  'ASSIGNED',
  'PICKED_UP',
] as const;
