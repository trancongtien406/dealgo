import { describe, expect, it, vi } from 'vitest';
import { resolveNewJobAlert } from './new-job-alert.js';

const settings = (on: boolean) => ({ getBoolean: vi.fn().mockResolvedValue(on) });
const prefs = (newJobSound?: boolean) => ({ getNotificationPrefs: vi.fn().mockResolvedValue({ newJobSound }) });

describe('resolveNewJobAlert', () => {
  it('uses the spoken sound when the admin switch and the user toggle are on (default)', async () => {
    await expect(resolveNewJobAlert('NEW_RIDE', 'd1', { settings: settings(true), prefs: prefs(true) })).resolves.toEqual({
      kind: 'NEW_RIDE',
      customSound: true,
    });
    await expect(resolveNewJobAlert('NEW_RIDE', 'd1', { prefs: prefs(undefined) })).resolves.toEqual({
      kind: 'NEW_RIDE',
      customSound: true,
    });
    await expect(resolveNewJobAlert('NEW_FOOD_JOB', 'd1', {})).resolves.toEqual({ kind: 'NEW_FOOD_JOB', customSound: true });
  });

  it('falls back to the default sound when the user turned it off', async () => {
    await expect(
      resolveNewJobAlert('MERCHANT_NEW_ORDER', 'm1', { settings: settings(true), prefs: prefs(false) }),
    ).resolves.toEqual({ kind: 'MERCHANT_NEW_ORDER', customSound: false });
  });

  it('the admin switch off wins without reading user prefs', async () => {
    const p = prefs(true);
    const s = settings(false);
    await expect(resolveNewJobAlert('NEW_RIDE', 'd1', { settings: s, prefs: p })).resolves.toEqual({
      kind: 'NEW_RIDE',
      customSound: false,
    });
    expect(s.getBoolean).toHaveBeenCalledWith('NEW_JOB_CUSTOM_SOUND_ENABLED');
    expect(p.getNotificationPrefs).not.toHaveBeenCalled();
  });

  it('never goes silent on lookup errors', async () => {
    const broken = { getBoolean: vi.fn().mockRejectedValue(new Error('db')) };
    const brokenPrefs = { getNotificationPrefs: vi.fn().mockRejectedValue(new Error('db')) };
    await expect(resolveNewJobAlert('NEW_RIDE', 'd1', { settings: broken, prefs: brokenPrefs })).resolves.toEqual({
      kind: 'NEW_RIDE',
      customSound: true,
    });
  });
});
