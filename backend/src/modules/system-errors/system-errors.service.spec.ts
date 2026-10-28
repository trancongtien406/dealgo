import { describe, expect, it } from 'vitest';
import { IntegrationSettingsService } from '../../platform/integration-settings/integration-settings.service.js';
import { MemoryIntegrationSettingsRepository } from '../../platform/integration-settings/integration-settings.repository.js';
import {
  parseLinks,
  splitProjects,
  SystemErrorsService,
  type SentryFetch,
  type SentryResponse,
} from './system-errors.service.js';

const KEY = Buffer.alloc(32, 7).toString('base64');
const actor = '11111111-1111-1111-1111-111111111111';
const TOKEN = `sntryu_${'a'.repeat(40)}SECRET`;

type Route = {
  status?: number;
  body?: unknown;
  headers?: Record<string, string>;
};

function harness(routes: (url: string, method: string) => Route) {
  const calls: Array<{
    url: string;
    method: string;
    auth: string | undefined;
    body?: string;
  }> = [];
  const fetcher: SentryFetch = async (url, init) => {
    const method = init.method ?? 'GET';
    calls.push({
      url,
      method,
      auth: init.headers.Authorization,
      body: init.body,
    });
    const r = routes(url, method);
    const headers = Object.fromEntries(
      Object.entries(r.headers ?? {}).map(([k, v]) => [k.toLowerCase(), v]),
    );
    return {
      ok: (r.status ?? 200) < 300,
      status: r.status ?? 200,
      headers: { get: (n: string) => headers[n.toLowerCase()] ?? null },
      json: async () => r.body ?? {},
    } satisfies SentryResponse;
  };
  const settings = new IntegrationSettingsService(
    new MemoryIntegrationSettingsRepository(),
    {
      get: (name: string) =>
        name === 'SECRETS_ENCRYPTION_KEY' ? KEY : undefined,
    } as never,
  );
  return { service: new SystemErrorsService(settings, fetcher), calls };
}

const PROJECTS = [
  { id: '11', slug: 'flutter' },
  { id: '22', slug: 'dealgo-backend' },
  { id: '33', slug: 'dealgo-web' },
  { id: '44', slug: 'other' },
];
const ISSUE = {
  id: '9001',
  shortId: 'FLUTTER-1',
  title: 'StateError: boom',
  culprit: 'main.dart in run',
  level: 'error',
  status: 'unresolved',
  project: { slug: 'flutter' },
  count: '7',
  userCount: 2,
  firstSeen: '2026-10-27T10:00:00Z',
  lastSeen: '2026-10-27T11:00:00Z',
  permalink: 'https://evil.example/issues/9001/',
  stats: {
    '14d': [
      [1, 0],
      [2, 3],
      [3, 4],
    ],
  },
  metadata: { type: 'StateError', value: 'boom' },
};
const EVENT = {
  eventID: 'e1',
  dateCreated: '2026-10-27T11:00:00Z',
  platform: 'dart',
  tags: [
    { key: 'environment', value: 'production' },
    { key: 'release', value: 'app@1.0.0+1' },
  ],
  entries: [
    {
      type: 'exception',
      data: {
        values: [
          {
            type: 'StateError',
            value: 'boom',
            stacktrace: {
              frames: [
                {
                  function: 'lib',
                  filename: 'dart:async',
                  lineNo: 1,
                  inApp: false,
                },
                {
                  function: 'outer',
                  filename: 'lib/a.dart',
                  lineNo: 10,
                  inApp: true,
                },
                {
                  function: 'inner',
                  filename: 'lib/b.dart',
                  lineNo: 20,
                  colNo: 3,
                  inApp: true,
                },
              ],
            },
          },
        ],
      },
    },
  ],
};

function defaultRoutes(scopes = ['event:read', 'org:read', 'project:read']) {
  return (url: string, method: string): Route => {
    if (url === 'https://sentry.io/api/0/')
      return { body: { auth: { scopes } } };
    if (url.includes('/projects/')) return { body: PROJECTS };
    if (url.includes('/events/latest/')) return { body: EVENT };
    if (/\/issues\/9001\/$/.test(url))
      return { body: method === 'PUT' ? { status: 'resolved' } : ISSUE };
    if (url.includes('/issues/?')) {
      return {
        body: [ISSUE],
        headers: {
          'X-Hits': '3',
          Link:
            '<https://us.sentry.io/x>; rel="previous"; results="false"; cursor="0:0:1", ' +
            '<https://us.sentry.io/x>; rel="next"; results="true"; cursor="1700000000000:0:0"',
        },
      };
    }
    return { status: 404 };
  };
}

async function configured(routes = defaultRoutes()) {
  const h = harness(routes);
  await h.service.updateSettings(
    {
      reason: 'setup',
      org: 'tiendev',
      region: 'https://us.sentry.io/',
      projects: 'flutter, dealgo-backend,dealgo-web',
      authToken: TOKEN,
    },
    actor,
  );
  return h;
}

describe('SystemErrorsService settings', () => {
  it('validates region, slugs and token format', async () => {
    const { service } = harness(defaultRoutes());
    await expect(
      service.updateSettings(
        { reason: 'x x', region: 'https://evil.example' },
        actor,
      ),
    ).rejects.toMatchObject({
      status: 400,
    });
    await expect(
      service.updateSettings({ reason: 'x x', projects: 'Bad Slug' }, actor),
    ).rejects.toMatchObject({ status: 400 });
    await expect(
      service.updateSettings({ reason: 'x x', authToken: 'nope' }, actor),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('stores the token encrypted and only exposes set + last 4', async () => {
    const { service } = await configured();
    const view = await service.settingsView();
    expect(view).toMatchObject({
      org: 'tiendev',
      region: 'https://us.sentry.io',
      projects: ['flutter', 'dealgo-backend', 'dealgo-web'],
      token: { set: true, hint: '…CRET' },
      canWrite: false,
      status: { configured: true, verified: false },
    });
    expect(JSON.stringify(view)).not.toContain(TOKEN);
  });

  it('test passes when all projects are visible, fails naming the missing ones', async () => {
    const ok = await configured();
    const pass = await ok.service.test('check', actor);
    expect(pass).toMatchObject({
      ok: true,
      view: { status: { verified: true } },
    });
    expect(pass.detail).toContain('chỉ đọc');

    const missing = await configured((url, m) =>
      url.includes('/projects/')
        ? { body: PROJECTS.slice(0, 1) }
        : defaultRoutes()(url, m),
    );
    const fail = await missing.service.test('check', actor);
    expect(fail.ok).toBe(false);
    expect(fail.detail).toContain('dealgo-backend');
  });

  it('409 when not configured; count is null', async () => {
    const { service } = harness(defaultRoutes());
    await expect(service.listIssues({})).rejects.toMatchObject({ status: 409 });
    await expect(service.unresolvedCount()).resolves.toEqual({ count: null });
  });
});

describe('SystemErrorsService issues', () => {
  it('maps issues, project ids, filters and cursors; bearer token stays server-side', async () => {
    const { service, calls } = await configured();
    const page = await service.listIssues({
      project: 'flutter',
      status: 'unresolved',
      period: '7d',
      sort: 'freq',
      q: 'boom',
      environment: 'production',
    });
    const url = new URL(calls.find((c) => c.url.includes('/issues/?'))!.url);
    expect(url.origin).toBe('https://us.sentry.io');
    expect(url.searchParams.getAll('project')).toEqual(['11']);
    expect(url.searchParams.get('query')).toBe('is:unresolved boom');
    expect(url.searchParams.get('sort')).toBe('freq');
    expect(url.searchParams.get('statsPeriod')).toBe('7d');
    expect(url.searchParams.get('environment')).toBe('production');
    expect(page.nextCursor).toBe('1700000000000:0:0');
    expect(page.prevCursor).toBeNull();
    expect(page.items[0]).toMatchObject({
      shortId: 'FLUTTER-1',
      count: 7,
      userCount: 2,
      project: 'flutter',
      trend: [0, 3, 4],
      permalink: 'https://tiendev.sentry.io/issues/9001/',
    });
    expect(page.canWrite).toBe(false);
    expect(JSON.stringify(page)).not.toContain(TOKEN);
    expect(calls.every((c) => c.auth === `Bearer ${TOKEN}`)).toBe(true);
  });

  it('all projects by default; rejects a project outside the config', async () => {
    const { service, calls } = await configured();
    await service.listIssues({});
    const url = new URL(calls.find((c) => c.url.includes('/issues/?'))!.url);
    expect(url.searchParams.getAll('project')).toEqual(['11', '22', '33']);
    await expect(
      service.listIssues({ project: 'other' }),
    ).rejects.toMatchObject({ status: 400 });
  });

  it('serves the cached copy within 30 s and the stale copy on 429, else 503', async () => {
    let limited = false;
    const { service, calls } = await configured((url, m) =>
      limited && url.includes('/issues/?')
        ? { status: 429, headers: { 'Retry-After': '12' } }
        : defaultRoutes()(url, m),
    );
    await service.listIssues({});
    await service.listIssues({});
    expect(calls.filter((c) => c.url.includes('/issues/?'))).toHaveLength(1);

    limited = true;
    await expect(service.listIssues({ sort: 'user' })).rejects.toMatchObject({
      status: 503,
      errorCode: 'SENTRY_RATE_LIMITED',
    });
    const realNow = Date.now;
    Date.now = () => realNow() + 60_000;
    try {
      const stale = await service.listIssues({});
      expect(stale.items).toHaveLength(1);
    } finally {
      Date.now = realNow;
    }
  });

  it('maps auth failures and unreachable Sentry', async () => {
    const denied = await configured((url, m) =>
      url.includes('/issues/?') ? { status: 401 } : defaultRoutes()(url, m),
    );
    await expect(denied.service.listIssues({})).rejects.toMatchObject({
      status: 502,
      errorCode: 'SENTRY_AUTH_FAILED',
    });
    expect(await denied.service.unresolvedCount()).toEqual({ count: null });
  });

  it('count uses X-Hits', async () => {
    const { service } = await configured();
    expect(await service.unresolvedCount()).toEqual({ count: 3 });
  });

  it('detail: in-app frames most recent first, tags, env, release', async () => {
    const { service } = await configured();
    const detail = await service.issueDetail('9001');
    expect(detail.latestEvent).toMatchObject({
      environment: 'production',
      release: 'app@1.0.0+1',
      exception: { type: 'StateError', value: 'boom' },
    });
    expect(detail.latestEvent!.frames.map((f) => f.function)).toEqual([
      'inner',
      'outer',
    ]);
    expect(detail.metadata).toEqual({ type: 'StateError', value: 'boom' });
    await expect(service.issueDetail('../x')).rejects.toMatchObject({
      status: 400,
    });
  });

  it('detail of an issue outside the configured projects is 404', async () => {
    const { service } = await configured((url, m) =>
      /\/issues\/9001\/$/.test(url)
        ? { body: { ...ISSUE, project: { slug: 'other' } } }
        : defaultRoutes()(url, m),
    );
    await expect(service.issueDetail('9001')).rejects.toMatchObject({
      status: 404,
    });
  });

  it('status change: 403 with a read-only token, PUT + audit with write scope', async () => {
    const ro = await configured();
    await expect(
      ro.service.updateStatus('9001', 'resolved', 'fixed', actor),
    ).rejects.toMatchObject({
      status: 403,
      errorCode: 'SENTRY_READ_ONLY',
    });
    expect(ro.calls.some((c) => c.method === 'PUT')).toBe(false);

    const rw = await configured(defaultRoutes(['event:read', 'event:write']));
    await rw.service.updateStatus('9001', 'resolved', 'fixed', actor);
    const put = rw.calls.find((c) => c.method === 'PUT')!;
    expect(put.body).toBe('{"status":"resolved"}');
  });
});

describe('helpers', () => {
  it('parseLinks keeps only cursors with results', () => {
    expect(parseLinks(null)).toEqual({ next: null, previous: null });
    expect(
      parseLinks('<u>; rel="next"; results="false"; cursor="1:1:0"'),
    ).toEqual({ next: null, previous: null });
  });
  it('splitProjects trims, lowercases and dedupes', () => {
    expect(splitProjects(' A, b ,a,, ')).toEqual(['a', 'b']);
  });
});
