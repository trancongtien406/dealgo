export const NEGOTIATION_SESSION_STATUSES = [
  "OPEN",
  "ACCEPTED",
  "EXPIRED",
  "LOCKED",
] as const;
export type NegotiationSessionStatus =
  (typeof NEGOTIATION_SESSION_STATUSES)[number];

export type NegotiationOffer = {
  id: string;
  driverId: string;
  amountVnd: number;
  kind: string;
  status: string;
  expiresAt: string;
};

export type NegotiationSession = {
  code: string;
  customer: string;
  route: string;
  budget: number;
  lowest: number | null;
  bids: number;
  offers: NegotiationOffer[];
  expires: string;
  expiresDate: string;
  status: NegotiationSessionStatus;
};
