export const DISPUTE_STATUSES = [
  "OPEN",
  "AWAITING_RESPONSE",
  "INVESTIGATING",
  "RESOLVED",
  "PENDING",
] as const;
export type DisputeStatus = (typeof DISPUTE_STATUSES)[number];

export const DISPUTE_PRIORITIES = ["HIGH", "MEDIUM", "LOW"] as const;
export type DisputePriority = (typeof DISPUTE_PRIORITIES)[number];

export type DisputeCase = {
  code: string;
  createdAt: string;
  type: string;
  relatedCode: string;
  reporter: string;
  summary: string;
  status: DisputeStatus;
  priority: DisputePriority;
  assignee: string;
};
