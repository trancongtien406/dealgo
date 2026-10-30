import { OpsEventBus } from '../../platform/ops-events/ops-event-bus.js';
import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import {
  INTEGRATION_FIELDS,
  integrationError,
  IntegrationSettingsService,
  type IntegrationPatch,
} from '../../platform/integration-settings/index.js';
import type {
  IssueListQueryDto,
  PutSentrySettingsDto,
} from './system-errors.dto.js';

export const SENTRY_FETCH = Symbol('SENTRY_FETCH');
export type SentryResponse = {
  ok: boolean;
  status: number;
  headers: { get(name: string): string | null };
  json(): Promise<unknown>;
};
export type SentryFetch = (
  url: string,
  init: {
    method?: string;
    headers: Record<string, string>;
    body?: string;
    signal?: AbortSignal;
  },
) => Promise<SentryResponse>;

/** Token scopes live on the control silo; issue data on the org's region host. */
const SENTRY_CONTROL = 'https://sentry.io';
const DEFAULT_REGION = 'https://sentry.io';
const REGION = /^https:\/\/([a-z0-9-]+\.)?sentry\.io$/;
const SLUG = /^[a-z0-9][a-z0-9_-]{0,63}$/;
const MAX_PROJECTS = 10;
const TIMEOUT_MS = 8000;
/** Issue data is a little stale at worst; keeps Admin well under Sentry's per-token rate limits. */
const CACHE_TTL_MS = 30_000;
const META_TTL_MS = 10 * 60_000;
const PAGE_SIZE = 25;
const WRITE_SCOPES = ['event:write', 'event:admin'];

export const ISSUE_STATUSES = [
  'unresolved',
  'resolved',
  'ignored',
  'all',
] as const;
export const ISSUE_PERIODS = ['24h', '7d', '14d', '30d', '90d'] as const;
export const ISSUE_SORTS = ['date', 'freq', 'user'] as const;
export const ISSUE_STATUS_UPDATES = [
  'resolved',
  'ignored',
  'unresolved',
] as const;

export type SentrySettingsView = {
  canStoreSecrets: boolean;
  secretsUnreadable: boolean;
  org: string;
  region: string;
  projects: string[];
  token: { set: boolean; hint: string | null };
  /** Scopes of the stored token (null when unset or Sentry is unreachable). */
  scopes: string[] | null;
  canWrite: boolean;
  status: { configured: boolean; verified: boolean; testedAt: string | null };
  updatedAt: string | null;
};

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
  /** Event counts per bucket (24 hourly buckets for 24h, else 14 daily). */
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

type Effective = {
  org: string;
  region: string;
  projects: string[];
  token: string;
};
type Cached<T> = { at: number; value: T };

/**
 * Admin › Lỗi hệ thống: a read-mostly proxy over Sentry's issues API. The auth token is an
 * encrypted integration setting and never reaches the browser; responses are reduced to the
 * fields the page shows and cached briefly.
 */
@Injectable()
export class SystemErrorsService {
  private readonly logger = new Logger(SystemErrorsService.name);
  private readonly cache = new Map<string, Cached<unknown>>();

  constructor(
    private readonly settings: IntegrationSettingsService,
    @Inject(SENTRY_FETCH) private readonly fetcher: SentryFetch,
    @Optional() private readonly opsBus?: OpsEventBus,
  ) {}

  // ── Settings ─────────────────────────────────────────────────────────────

  async settingsView(): Promise<SentrySettingsView> {
    const values = await this.settings.values('SENTRY');
    const eff = this.toEffective(values.config, values.secrets);
    const scopes = eff ? await this.scopes(eff.token).catch(() => null) : null;
    return {
      canStoreSecrets: this.settings.canStoreSecrets(),
      secretsUnreadable: values.secretsUnreadable,
      org: values.config.org ?? '',
      region: values.config.region ?? DEFAULT_REGION,
      projects: splitProjects(values.config.projects),
      token: {
        set: Boolean(values.secrets.authToken),
        hint: maskKey(values.secrets.authToken),
      },
      scopes,
      canWrite: canWrite(scopes),
      status: {
        configured: eff !== null,
        verified:
          eff !== null && values.testedFingerprint === this.fingerprint(eff),
        testedAt: values.testedAt?.toISOString() ?? null,
      },
      updatedAt: values.updatedAt?.toISOString() ?? null,
    };
  }

  async updateSettings(
    body: PutSentrySettingsDto,
    actorUserId: string,
  ): Promise<SentrySettingsView> {
    const patch: IntegrationPatch = { config: {}, secrets: {} };
    if (body.org !== undefined) {
      const org = (body.org ?? '').trim().toLowerCase();
      if (org && !SLUG.test(org))
        throw integrationError(
          400,
          'VALIDATION_ERROR',
          'Org slug không hợp lệ',
        );
      patch.config!.org = org;
    }
    if (body.region !== undefined) {
      const region = (body.region ?? '')
        .trim()
        .replace(/\/+$/, '')
        .toLowerCase();
      if (region && !REGION.test(region)) {
        throw integrationError(
          400,
          'VALIDATION_ERROR',
          'Region phải là https://sentry.io hoặc https://<vùng>.sentry.io',
        );
      }
      patch.config!.region = region;
    }
    if (body.projects !== undefined) {
      const projects = splitProjects(body.projects ?? '');
      if (
        projects.length > MAX_PROJECTS ||
        projects.some((p) => !SLUG.test(p))
      ) {
        throw integrationError(
          400,
          'VALIDATION_ERROR',
          `Tối đa ${MAX_PROJECTS} project slug, cách nhau bằng dấu phẩy`,
        );
      }
      patch.config!.projects = projects.join(',');
    }
    if (body.authToken !== undefined) {
      const token = (body.authToken ?? '').trim();
      if (
        token &&
        !/^sntry[us]_[A-Za-z0-9+/=_-]{20,}$/.test(token) &&
        !/^[a-f0-9]{64}$/.test(token)
      ) {
        throw integrationError(
          400,
          'VALIDATION_ERROR',
          'Token Sentry không đúng định dạng (sntryu_… / sntrys_…)',
        );
      }
      patch.secrets!.authToken = token;
    }
    for (const key of Object.keys(patch.config!)) {
      if (
        !(INTEGRATION_FIELDS.SENTRY.config as readonly string[]).includes(key)
      )
        delete patch.config![key];
    }
    await this.settings.update('SENTRY', patch, actorUserId, body.reason);
    this.cache.clear();
    return this.settingsView();
  }

  /** Checks the token (scopes) and that every configured project is readable; audited. */
  async test(
    reason: string,
    actorUserId: string,
  ): Promise<{ ok: boolean; detail: string; view: SentrySettingsView }> {
    const eff = await this.effective();
    let ok = false;
    let detail: string;
    try {
      this.cache.delete(`scopes:${eff.token}`);
      const scopes = await this.scopes(eff.token);
      if (!scopes.includes('event:read')) {
        detail = 'Token thiếu quyền event:read';
      } else {
        const ids = await this.projectIds(eff, true);
        const missing = eff.projects.filter((p) => !ids.has(p));
        ok = missing.length === 0;
        detail = ok
          ? `OK · ${scopes.length} quyền${canWrite(scopes) ? ' · có quyền ghi' : ' · chỉ đọc'}`
          : `Không thấy project: ${missing.join(', ')}`;
      }
    } catch (error) {
      detail = (error as Error).message;
    }
    await this.settings.recordTest(
      'SENTRY',
      { ok, fingerprint: this.fingerprint(eff), detail },
      actorUserId,
      reason,
    );
    return { ok, detail, view: await this.settingsView() };
  }

  // ── Issues ───────────────────────────────────────────────────────────────

  async listIssues(query: IssueListQueryDto): Promise<SentryIssuePage> {
    const eff = await this.effective();
    const ids = await this.projectIds(eff);
    const projects = query.project ? [query.project] : eff.projects;
    if (query.project && !eff.projects.includes(query.project)) {
      throw integrationError(
        400,
        'VALIDATION_ERROR',
        'Project không nằm trong cấu hình',
      );
    }
    const period = query.period ?? '14d';
    const params = new URLSearchParams();
    for (const slug of projects) {
      const id = ids.get(slug);
      if (id) params.append('project', id);
    }
    if (!params.has('project')) {
      return {
        items: [],
        nextCursor: null,
        prevCursor: null,
        canWrite: false,
        projects: eff.projects,
      };
    }
    if (query.environment) params.set('environment', query.environment);
    params.set('statsPeriod', period);
    params.set('groupStatsPeriod', period === '24h' ? '24h' : '14d');
    params.set('sort', query.sort ?? 'date');
    params.set('limit', String(PAGE_SIZE));
    params.set('query', issueQuery(query.status ?? 'unresolved', query.q));
    if (query.cursor) params.set('cursor', query.cursor);

    const url = `${eff.region}/api/0/organizations/${eff.org}/issues/?${params.toString()}`;
    const { body, headers } = await this.cachedGet(eff, url);
    const links = parseLinks(headers.link);
    const scopes = await this.scopes(eff.token).catch(() => null);
    return {
      items: asArray(body).map((raw) => toSummary(raw, eff)),
      nextCursor: links.next,
      prevCursor: links.previous,
      canWrite: canWrite(scopes),
      projects: eff.projects,
    };
  }

  /** Unresolved issues in the last 14 days across configured projects (nav badge); null if unconfigured. */
  async unresolvedCount(): Promise<{ count: number | null }> {
    const eff = await this.effectiveOrNull();
    if (!eff) return { count: null };
    try {
      const ids = await this.projectIds(eff);
      const params = new URLSearchParams();
      for (const slug of eff.projects) {
        const id = ids.get(slug);
        if (id) params.append('project', id);
      }
      if (!params.has('project')) return { count: 0 };
      params.set('statsPeriod', '14d');
      params.set('query', 'is:unresolved');
      params.set('limit', '100');
      const url = `${eff.region}/api/0/organizations/${eff.org}/issues/?${params.toString()}`;
      const { body, headers } = await this.cachedGet(eff, url, 60_000);
      const hits = Number(headers.hits);
      return {
        count:
          Number.isFinite(hits) && headers.hits !== null
            ? hits
            : asArray(body).length,
      };
    } catch (error) {
      this.logger.warn(
        `Sentry unresolved count failed: ${(error as Error).message}`,
      );
      return { count: null };
    }
  }

  async issueDetail(issueId: string): Promise<SentryIssueDetail> {
    const eff = await this.effective();
    const id = issueIdOrThrow(issueId);
    const base = `${eff.region}/api/0/organizations/${eff.org}/issues/${id}/`;
    const { body } = await this.cachedGet(eff, base);
    const issue = asRecord(body);
    const summary = toSummary(issue, eff);
    if (!eff.projects.includes(summary.project)) {
      throw integrationError(
        404,
        'NOT_FOUND',
        'Không tìm thấy lỗi trong các project đã cấu hình',
      );
    }
    let latestEvent: SentryIssueDetail['latestEvent'] = null;
    try {
      latestEvent = toEvent(
        (await this.cachedGet(eff, `${base}events/latest/`)).body,
      );
    } catch (error) {
      this.logger.warn(
        `Sentry latest event for ${id} failed: ${(error as Error).message}`,
      );
    }
    const metadata = asRecord(issue.metadata);
    const scopes = await this.scopes(eff.token).catch(() => null);
    return {
      ...summary,
      metadata: { type: str(metadata.type), value: str(metadata.value) },
      latestEvent,
      canWrite: canWrite(scopes),
    };
  }

  async updateStatus(
    issueId: string,
    status: (typeof ISSUE_STATUS_UPDATES)[number],
    reason: string,
    actorUserId: string,
  ): Promise<SentryIssueDetail> {
    const eff = await this.effective();
    const id = issueIdOrThrow(issueId);
    if (!canWrite(await this.scopes(eff.token))) {
      throw integrationError(
        403,
        'SENTRY_READ_ONLY',
        'Token Sentry chỉ có quyền đọc (cần event:write)',
      );
    }
    const before = await this.issueDetail(id);
    const res = await this.request(
      eff.token,
      `${eff.region}/api/0/organizations/${eff.org}/issues/${id}/`,
      {
        method: 'PUT',
        body: JSON.stringify({ status }),
      },
    );
    if (!res.ok) throw sentryError(res);
    await this.settings.recordAction(
      'SENTRY',
      {
        action: 'SENTRY_ISSUE_STATUS_UPDATE',
        metadata: {
          issueId: id,
          shortId: before.shortId,
          from: before.status,
          to: status,
        },
      },
      actorUserId,
      reason,
    );
    this.cache.clear();
    // Admin SSE hint: the list and nav badge re-GET (t50u follow-up).
    this.opsBus?.publish({ type: 'systemErrors', reason: 'statusChanged', at: new Date().toISOString() });
    return this.issueDetail(id);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  private async effectiveOrNull(): Promise<Effective | null> {
    const values = await this.settings.values('SENTRY');
    return this.toEffective(values.config, values.secrets);
  }

  private async effective(): Promise<Effective> {
    const eff = await this.effectiveOrNull();
    if (!eff) {
      throw integrationError(
        409,
        'SENTRY_NOT_CONFIGURED',
        'Chưa cấu hình Sentry (org, project, token)',
      );
    }
    return eff;
  }

  private toEffective(
    config: Record<string, string>,
    secrets: Record<string, string>,
  ): Effective | null {
    const projects = splitProjects(config.projects);
    if (!config.org || !secrets.authToken || projects.length === 0) return null;
    return {
      org: config.org,
      region: config.region || DEFAULT_REGION,
      projects,
      token: secrets.authToken,
    };
  }

  private fingerprint(eff: Effective): string {
    return this.settings.fingerprint([
      eff.org,
      eff.region,
      eff.projects,
      eff.token,
    ]);
  }

  private async scopes(token: string): Promise<string[]> {
    const key = `scopes:${token}`;
    const hit = this.fromCache<string[]>(key, META_TTL_MS);
    if (hit) return hit;
    const res = await this.request(token, `${SENTRY_CONTROL}/api/0/`);
    if (!res.ok) throw sentryError(res);
    const auth = asRecord(asRecord(await res.json()).auth);
    const scopes = Array.isArray(auth.scopes)
      ? auth.scopes.filter((s): s is string => typeof s === 'string')
      : [];
    this.cache.set(key, { at: Date.now(), value: scopes });
    return scopes;
  }

  private async projectIds(
    eff: Effective,
    fresh = false,
  ): Promise<Map<string, string>> {
    const key = `projects:${eff.region}:${eff.org}:${eff.token}`;
    const hit = fresh
      ? null
      : this.fromCache<Map<string, string>>(key, META_TTL_MS);
    if (hit) return hit;
    const res = await this.request(
      eff.token,
      `${eff.region}/api/0/organizations/${eff.org}/projects/?per_page=100`,
    );
    if (!res.ok) throw sentryError(res);
    const ids = new Map<string, string>();
    for (const raw of asArray(await res.json())) {
      const slug = str(raw.slug);
      const id = str(raw.id);
      if (slug && id) ids.set(slug, id);
    }
    this.cache.set(key, { at: Date.now(), value: ids });
    return ids;
  }

  /** GET with a short cache; on 429 serves the last good copy if there is one. */
  private async cachedGet(
    eff: Effective,
    url: string,
    ttl = CACHE_TTL_MS,
  ): Promise<{
    body: unknown;
    headers: { link: string | null; hits: string | null };
  }> {
    type Entry = {
      body: unknown;
      headers: { link: string | null; hits: string | null };
    };
    const key = `get:${eff.token.slice(-8)}:${url}`;
    const hit = this.fromCache<Entry>(key, ttl);
    if (hit) return hit;
    const res = await this.request(eff.token, url);
    if (!res.ok) {
      const stale =
        res.status === 429
          ? (this.cache.get(key)?.value as Entry | undefined)
          : undefined;
      if (stale) return stale;
      throw sentryError(res);
    }
    const value: Entry = {
      body: await res.json(),
      headers: {
        link: res.headers.get('link'),
        hits: res.headers.get('x-hits'),
      },
    };
    this.cache.set(key, { at: Date.now(), value });
    if (this.cache.size > 500)
      this.cache.delete(this.cache.keys().next().value!);
    return value;
  }

  private fromCache<T>(key: string, ttl: number): T | null {
    const hit = this.cache.get(key);
    return hit && Date.now() - hit.at < ttl ? (hit.value as T) : null;
  }

  private async request(
    token: string,
    url: string,
    init: { method?: string; body?: string } = {},
  ): Promise<SentryResponse> {
    try {
      return await this.fetcher(url, {
        method: init.method ?? 'GET',
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: 'application/json',
          ...(init.body ? { 'Content-Type': 'application/json' } : {}),
        },
        body: init.body,
        signal: AbortSignal.timeout(TIMEOUT_MS),
      });
    } catch (error) {
      throw integrationError(
        502,
        'SENTRY_UNREACHABLE',
        `Không kết nối được Sentry: ${(error as Error).name}`,
      );
    }
  }
}

function sentryError(res: SentryResponse) {
  if (res.status === 429) {
    const retry = Number(res.headers.get('retry-after'));
    const seconds = Number.isFinite(retry) && retry > 0 ? Math.ceil(retry) : 60;
    return integrationError(
      503,
      'SENTRY_RATE_LIMITED',
      `Sentry đang giới hạn tần suất, thử lại sau ${seconds} giây`,
    );
  }
  if (res.status === 401 || res.status === 403) {
    return integrationError(
      502,
      'SENTRY_AUTH_FAILED',
      `Sentry từ chối token (HTTP ${res.status})`,
    );
  }
  if (res.status === 404)
    return integrationError(
      404,
      'NOT_FOUND',
      'Sentry không tìm thấy dữ liệu (org/project/issue)',
    );
  return integrationError(
    502,
    'SENTRY_UPSTREAM_ERROR',
    `Sentry trả lỗi HTTP ${res.status}`,
  );
}

function issueQuery(
  status: (typeof ISSUE_STATUSES)[number],
  q?: string,
): string {
  const parts = status === 'all' ? [] : [`is:${status}`];
  const text = (q ?? '').replace(/[\r\n]+/g, ' ').trim();
  if (text) parts.push(text);
  return parts.join(' ');
}

function issueIdOrThrow(id: string): string {
  if (!/^\d{1,20}$/.test(id))
    throw integrationError(400, 'VALIDATION_ERROR', 'Mã lỗi không hợp lệ');
  return id;
}

export function canWrite(scopes: string[] | null): boolean {
  return Boolean(scopes?.some((s) => WRITE_SCOPES.includes(s)));
}

export function splitProjects(raw: string | undefined): string[] {
  return [
    ...new Set(
      (raw ?? '')
        .split(',')
        .map((p) => p.trim().toLowerCase())
        .filter(Boolean),
    ),
  ];
}

export function parseLinks(header: string | null): {
  next: string | null;
  previous: string | null;
} {
  const out = { next: null as string | null, previous: null as string | null };
  for (const part of (header ?? '').split(',')) {
    const rel = /rel="(next|previous)"/.exec(part)?.[1] as
      'next' | 'previous' | undefined;
    const results = /results="(true|false)"/.exec(part)?.[1];
    const cursor = /cursor="([^"]+)"/.exec(part)?.[1];
    if (rel && results === 'true' && cursor) out[rel] = cursor;
  }
  return out;
}

function toSummary(
  raw: Record<string, unknown>,
  eff: Effective,
): SentryIssueSummary {
  const project = asRecord(raw.project);
  const stats = asRecord(raw.stats);
  const series = (stats['24h'] ?? stats['14d']) as unknown;
  const shortId = str(raw.shortId) ?? '';
  const id = str(raw.id) ?? '';
  return {
    id,
    shortId,
    title: str(raw.title) ?? '(không tiêu đề)',
    culprit: str(raw.culprit) ?? '',
    level: str(raw.level) ?? 'error',
    status: str(raw.status) ?? 'unresolved',
    project: str(project.slug) ?? '',
    count: Number(raw.count ?? 0) || 0,
    userCount: Number(raw.userCount ?? 0) || 0,
    firstSeen: str(raw.firstSeen),
    lastSeen: str(raw.lastSeen),
    permalink: safePermalink(str(raw.permalink), eff, id),
    trend: Array.isArray(series)
      ? series.map((point) =>
          Array.isArray(point) ? Number(point[1]) || 0 : 0,
        )
      : [],
  };
}

/** Only links into the org on sentry.io; otherwise rebuild the canonical issue URL. */
function safePermalink(
  link: string | null,
  eff: Effective,
  id: string,
): string {
  if (link && /^https:\/\/([a-z0-9-]+\.)?sentry\.io\//.test(link)) return link;
  return `https://${eff.org}.sentry.io/issues/${id}/`;
}

function toEvent(raw: unknown): NonNullable<SentryIssueDetail['latestEvent']> {
  const event = asRecord(raw);
  const entries = Array.isArray(event.entries)
    ? event.entries.map(asRecord)
    : [];
  const exception = entries.find((e) => e.type === 'exception');
  const values = asArray(asRecord(exception?.data).values);
  const last = values.at(-1);
  const frames = asArray(asRecord(last?.stacktrace).frames)
    .map((f) => ({
      function: str(f.function),
      file: str(f.filename) ?? str(f.absPath) ?? str(f.module),
      line: typeof f.lineNo === 'number' ? f.lineNo : null,
      column: typeof f.colNo === 'number' ? f.colNo : null,
      inApp: f.inApp === true,
    }))
    .reverse();
  const inApp = frames.filter((f) => f.inApp);
  const tags = asArray(event.tags)
    .map((t) => ({ key: str(t.key) ?? '', value: str(t.value) ?? '' }))
    .filter((t) => t.key)
    .slice(0, 40);
  const tag = (key: string) => tags.find((t) => t.key === key)?.value ?? null;
  return {
    id: str(event.eventID) ?? str(event.id) ?? '',
    dateCreated: str(event.dateCreated),
    environment: tag('environment'),
    release: tag('release') ?? str(asRecord(event.release).version),
    platform: str(event.platform),
    exception: last ? { type: str(last.type), value: str(last.value) } : null,
    frames: (inApp.length ? inApp : frames).slice(0, 8),
    tags,
  };
}

function maskKey(key: string | undefined): string | null {
  if (!key) return null;
  return key.length > 8 ? `…${key.slice(-4)}` : '…';
}

function asRecord(value: unknown): Record<string, unknown> {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

function asArray(value: unknown): Array<Record<string, unknown>> {
  return Array.isArray(value) ? value.map(asRecord) : [];
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value
    ? value
    : typeof value === 'number'
      ? String(value)
      : null;
}
