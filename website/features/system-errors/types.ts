/** Mirrors Nest SystemErrorsService views (v1/ops/system-errors, v1/ops/integrations/sentry). */
export const ISSUE_STATUSES = [
  "unresolved",
  "resolved",
  "ignored",
  "all",
] as const;
export const ISSUE_PERIODS = ["24h", "7d", "14d", "30d", "90d"] as const;
export const ISSUE_SORTS = ["date", "freq", "user"] as const;

export type IssueStatusFilter = (typeof ISSUE_STATUSES)[number];
export type IssuePeriod = (typeof ISSUE_PERIODS)[number];
export type IssueSort = (typeof ISSUE_SORTS)[number];
export type IssueStatusUpdate = "resolved" | "ignored" | "unresolved";

export type SentryIssueSummary = {
  id: string;
  shortId: string;
  title: string;
  culprit: string;
  level: string;
  status: string;
  project: string;
  count: number;
  userCount: number;
  firstSeen: string | null;
  lastSeen: string | null;
  permalink: string;
  trend: number[];
};

export type SentryIssuePage = {
  items: SentryIssueSummary[];
  nextCursor: string | null;
  prevCursor: string | null;
  canWrite: boolean;
  projects: string[];
};

export type SentryFrame = {
  function: string | null;
  file: string | null;
  line: number | null;
  column: number | null;
  inApp: boolean;
};

export type SentryIssueDetail = SentryIssueSummary & {
  metadata: { type: string | null; value: string | null };
  latestEvent: {
    id: string;
    dateCreated: string | null;
    environment: string | null;
    release: string | null;
    platform: string | null;
    exception: { type: string | null; value: string | null } | null;
    frames: SentryFrame[];
    tags: Array<{ key: string; value: string }>;
  } | null;
  canWrite: boolean;
};

export type SentrySettingsView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  org: string;
  region: string;
  projects: string[];
  token: { set: boolean; hint: string | null };
  scopes: string[] | null;
  canWrite: boolean;
  status: { configured: boolean; verified: boolean; testedAt: string | null };
  updatedAt: string | null;
};

export type IssueListParams = {
  project: string | null;
  environment: string | null;
  status: IssueStatusFilter;
  period: IssuePeriod;
  sort: IssueSort;
  q: string;
  cursor: string | null;
};
