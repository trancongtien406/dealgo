import {
  buildHourlyTrendBuckets,
  buildMonitorQueue,
  deriveSystemAlerts,
  mergeAreaDemand,
  mergeRecentActivityItems,
  mergeCountRowsByName,
  normalizeShortAreaLabel,
  withShare,
} from './ops-overview.enrichment.js';

describe('ops-overview enrichment helpers', () => {
  it('normalizes short area labels from pickup/dropoff text', () => {
    expect(normalizeShortAreaLabel('Quận 1, TP.HCM')).toBe('Quận 1');
    expect(normalizeShortAreaLabel('  Hải Châu  ')).toBe('Hải Châu');
    expect(normalizeShortAreaLabel('')).toBe('Khác');
    expect(normalizeShortAreaLabel(null)).toBe('Khác');
    expect(normalizeShortAreaLabel('Perf pickup 1022')).toBe(
      'Khu vực thử nghiệm',
    );
  });

  it('merges rows that collapse to the same display name', () => {
    expect(
      mergeCountRowsByName([
        { name: 'Khu vực thử nghiệm', count: 2 },
        { name: 'Khu vực thử nghiệm', count: 3 },
        { name: 'Hải Châu', count: 1 },
      ]),
    ).toEqual([
      { name: 'Khu vực thử nghiệm', count: 5 },
      { name: 'Hải Châu', count: 1 },
    ]);
  });

  it('mergeAreaDemand collapses Perf labels via normalizeShortAreaLabel', () => {
    expect(
      mergeAreaDemand(
        [
          { name: 'Perf pickup 1', count: 2 },
          { name: 'Perf pickup 2', count: 3 },
        ],
        [{ name: 'Hải Châu', count: 1 }],
        5,
      ),
    ).toEqual([
      { name: 'Khu vực thử nghiệm', demand: 5 },
      { name: 'Hải Châu', demand: 1 },
    ]);
  });

  it('computes share 0-100 from counts after merging duplicates', () => {
    expect(
      withShare([
        { name: 'A', count: 2 },
        { name: 'A', count: 1 },
        { name: 'B', count: 1 },
      ]),
    ).toEqual([
      { name: 'A', count: 3, share: 75 },
      { name: 'B', count: 1, share: 25 },
    ]);
  });

  it('fills 24 local hour buckets with ride/food/negotiating counts', () => {
    const now = new Date('2026-10-15T12:30:00.000Z'); // 19:30 +07
    const buckets = buildHourlyTrendBuckets(
      now,
      [{ hourKey: '2026-10-15T19:00+07:00', cnt: 5n }],
      [{ hourKey: '2026-10-15T19:00+07:00', cnt: 2 }],
      [{ hourKey: '2026-10-15T18:00+07:00', cnt: 1n }],
    );

    expect(buckets).toHaveLength(24);
    expect(buckets[0]?.hour).toBe('2026-10-14T20:00+07:00');
    expect(buckets[23]).toEqual({
      hour: '2026-10-15T19:00+07:00',
      rides: 5,
      foodOrders: 2,
      negotiating: 0,
    });
    expect(buckets[22]).toEqual({
      hour: '2026-10-15T18:00+07:00',
      rides: 0,
      foodOrders: 0,
      negotiating: 1,
    });
  });

  it('merges recent activity by at DESC with limit', () => {
    const items = mergeRecentActivityItems(
      [
        {
          kind: 'food',
          title: 'older',
          detail: 'x',
          at: '2026-10-15T10:00:00.000Z',
        },
        {
          kind: 'ride',
          title: 'newer',
          detail: 'y',
          at: '2026-10-15T11:00:00.000Z',
        },
        {
          kind: 'exception',
          title: 'mid',
          detail: 'z',
          at: '2026-10-15T10:30:00.000Z',
        },
      ],
      2,
    );
    expect(items.map((i) => i.title)).toEqual(['newer', 'mid']);
  });

  it('builds monitor queue and derived system alerts without payment noise', () => {
    expect(
      buildMonitorQueue({
        ridesNegotiating: 3,
        foodReady: 4,
        foodInFlight: 5,
        exceptionsOpen: 1,
      }),
    ).toEqual([
      {
        key: 'negotiating',
        label: 'Đang thương lượng',
        count: 3,
        priority: 'priority',
      },
      {
        key: 'food_ready',
        label: 'Đồ ăn sẵn sàng',
        count: 4,
        priority: 'high',
      },
      {
        key: 'food_in_flight',
        label: 'Đồ ăn đang giao',
        count: 5,
        priority: 'normal',
      },
      {
        key: 'exceptions',
        label: 'Ngoại lệ mở',
        count: 1,
        priority: 'high',
      },
    ]);

    const alerts = deriveSystemAlerts({
      exceptionsOpen: 2,
      driversOnline: 0,
      foodReady: 25,
      ridesNegotiating: 0,
      ridesOpen: 4,
    });
    expect(alerts.map((a) => a.code)).toEqual([
      'exceptions_open',
      'drivers_online_zero',
      'food_ready_high',
    ]);
    expect(alerts.every((a) => !a.code.includes('payment'))).toBe(true);

    expect(
      deriveSystemAlerts({
        exceptionsOpen: 0,
        driversOnline: 3,
        foodReady: 1,
        ridesNegotiating: 0,
        ridesOpen: 1,
      })[0]?.code,
    ).toBe('ops_nominal');
  });

  it('merges open ride/food area demand into top districts', () => {
    expect(
      mergeAreaDemand(
        [
          { name: 'Hải Châu, Đà Nẵng', count: 3 },
          { name: 'Thanh Khê', count: 1 },
        ],
        [{ name: 'Hải Châu', count: 2 }],
        2,
      ),
    ).toEqual([
      { name: 'Hải Châu', demand: 5 },
      { name: 'Thanh Khê', demand: 1 },
    ]);
  });
});
