import { effectiveServiceMode, resumeAt } from './store-service-mode.js';

describe('store service mode (DEC-PROD-026)', () => {
  const now = new Date('2026-10-20T03:00:00.000Z');

  it('treats an expired busy/pause window as open', () => {
    expect(effectiveServiceMode('PAUSED', new Date('2026-10-20T02:59:59.000Z'), now)).toEqual({
      serviceMode: 'OPEN',
      serviceModeUntil: null,
    });
    expect(effectiveServiceMode('BUSY', new Date('2026-10-20T03:30:00.000Z'), now)).toEqual({
      serviceMode: 'BUSY',
      serviceModeUntil: '2026-10-20T03:30:00.000Z',
    });
    expect(effectiveServiceMode('PAUSED', null, now).serviceMode).toBe('PAUSED');
    expect(effectiveServiceMode(undefined, null, now).serviceMode).toBe('OPEN');
  });

  it('computes the auto-resume instant only for busy/pause', () => {
    expect(resumeAt('PAUSED', 60, now)?.toISOString()).toBe('2026-10-20T04:00:00.000Z');
    expect(resumeAt('OPEN', 60, now)).toBeNull();
    expect(resumeAt('BUSY', null, now)).toBeNull();
  });
});
