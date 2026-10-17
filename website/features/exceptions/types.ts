export const EXCEPTION_STATUSES = [
  "OPEN",
  "IN_PROGRESS",
  "RESOLVED",
  "ESCALATED",
] as const;

export type ExceptionStatus = (typeof EXCEPTION_STATUSES)[number];

export type ExceptionCase = {
  code: string;
  title: string;
  domain: "RIDE" | "FOOD" | "OTHER";
  status: ExceptionStatus;
  priority: "P1" | "P2" | "P3";
  openedAt: string;
  entityRef: string;
};
