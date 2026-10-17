export const DELIVERY_STATUSES = [
  "DELIVERING",
  "WAITING_DRIVER",
  "PICKED_UP",
  "COMPLETED",
  "FAILED",
] as const;
export type DeliveryStatus = (typeof DELIVERY_STATUSES)[number];

export type DeliveryListItem = {
  code: string;
  sender: string;
  route: string;
  cargo: string;
  fee: number;
  driver: string | null;
  status: DeliveryStatus;
  time: string;
  regionLabel?: string;
};
