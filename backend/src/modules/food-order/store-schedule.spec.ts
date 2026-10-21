import { normalizeSchedule, storeAvailability, vnClock, withinSchedule } from './store-schedule.js';

const weekdays = (opensAt: string, closesAt: string) =>
  [1, 2, 3, 4, 5, 6].map((weekday) => ({ weekday, opensAt, closesAt }));

describe('store schedule (DEC-PROD-027)', () => {
  // 2026-10-19 is a Monday. 03:00Z = 10:00 in Vietnam.
  const mondayTen = new Date('2026-10-19T03:00:00.000Z');

  it('reads the Vietnam clock', () => {
    expect(vnClock(mondayTen)).toEqual({ weekday: 1, minute: 600, date: '2026-10-19' });
    // 2026-10-25 17:30Z = Monday 00:30 local.
    expect(vnClock(new Date('2026-10-25T17:30:00.000Z'))).toEqual({
      weekday: 1,
      minute: 30,
      date: '2026-10-26',
    });
  });

  it('applies hours, Sunday off, closures and the last-order cut-off', () => {
    const result = normalizeSchedule({
      weekly: weekdays('07:00', '22:00'),
      closures: [{ date: '2026-10-20', note: 'Bảo trì bếp' }],
      lastOrderMinutes: 15,
    });
    if (!result.ok) throw new Error(result.problem);
    const { schedule } = result;
    expect(withinSchedule(schedule, mondayTen)).toBe(true);
    // Monday 21:50 local is inside the 15-minute cut-off.
    expect(withinSchedule(schedule, new Date('2026-10-19T14:50:00.000Z'))).toBe(false);
    expect(withinSchedule(schedule, new Date('2026-10-19T14:44:00.000Z'))).toBe(true);
    // Tuesday 10:00 is a special closed day.
    expect(withinSchedule(schedule, new Date('2026-10-20T03:00:00.000Z'))).toBe(false);
    // Sunday has no row → closed.
    expect(withinSchedule(schedule, new Date('2026-10-25T03:00:00.000Z'))).toBe(false);
  });

  it('keeps unconfigured stores open and reports pause first', () => {
    const always = { hoursConfigured: false, lastOrderMinutes: 0, hours: [], closures: [] };
    expect(storeAvailability('OPEN', null, always, mondayTen)).toEqual({
      openNow: true,
      closedReason: null,
    });
    expect(storeAvailability('PAUSED', null, always, mondayTen).closedReason).toBe('PAUSED');
  });

  it('rejects bad input', () => {
    const base = { closures: [], lastOrderMinutes: 0 };
    expect(normalizeSchedule({ ...base, weekly: [{ weekday: 1, opensAt: '07:00', closesAt: '07:00' }] }).ok).toBe(false);
    expect(normalizeSchedule({ ...base, weekly: [{ weekday: 1, opensAt: '24:00', closesAt: '07:00' }] }).ok).toBe(false);
    expect(
      normalizeSchedule({
        ...base,
        weekly: [
          { weekday: 1, opensAt: '07:00', closesAt: '22:00' },
          { weekday: 1, opensAt: '08:00', closesAt: '20:00' },
        ],
      }).ok,
    ).toBe(false);
    expect(normalizeSchedule({ weekly: [], closures: [{ date: '2026-02-30' }], lastOrderMinutes: 0 }).ok).toBe(false);
    expect(normalizeSchedule({ ...base, weekly: [{ weekday: 7, opensAt: '00:00', closesAt: '24:00' }] }).ok).toBe(true);
  });

  it('supports overnight shifts that end the next morning (DEC-PROD-029)', () => {
    const result = normalizeSchedule({
      // Friday 18:00 → Saturday 02:00; Saturday 00:00 closing means midnight, not overnight.
      weekly: [
        { weekday: 5, opensAt: '18:00', closesAt: '02:00' },
        { weekday: 6, opensAt: '10:00', closesAt: '00:00' },
      ],
      closures: [],
      lastOrderMinutes: 30,
    });
    if (!result.ok) throw new Error(result.problem);
    const { schedule } = result;
    expect(schedule.hours[1]).toEqual({ weekday: 6, opensMinute: 600, closesMinute: 1440 });
    // 2026-10-23 is a Friday. Local = Z + 7h.
    const at = (iso: string) => withinSchedule(schedule, new Date(iso));
    expect(at('2026-10-23T10:59:00.000Z')).toBe(false); // Fri 17:59
    expect(at('2026-10-23T11:00:00.000Z')).toBe(true); // Fri 18:00
    expect(at('2026-10-23T17:10:00.000Z')).toBe(true); // Sat 00:10 (spill-over)
    expect(at('2026-10-23T18:29:00.000Z')).toBe(true); // Sat 01:29
    expect(at('2026-10-23T18:30:00.000Z')).toBe(false); // Sat 01:30 = 02:00 − 30 min cut-off
    expect(at('2026-10-24T03:00:00.000Z')).toBe(true); // Sat 10:00, Saturday's own shift
    // Thursday has no row → Friday morning gets no spill-over.
    expect(at('2026-10-23T00:30:00.000Z')).toBe(false); // Fri 07:30

    const friOff = { ...schedule, closures: [{ date: '2026-10-23', note: null }] };
    expect(withinSchedule(friOff, new Date('2026-10-23T17:10:00.000Z'))).toBe(false); // shift cancelled
    const satOff = { ...schedule, closures: [{ date: '2026-10-24', note: null }] };
    expect(withinSchedule(satOff, new Date('2026-10-23T17:10:00.000Z'))).toBe(true); // Friday's shift
    expect(withinSchedule(satOff, new Date('2026-10-24T03:00:00.000Z'))).toBe(false);
  });
});
