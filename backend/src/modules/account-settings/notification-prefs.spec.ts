import { describe, expect, it } from 'vitest';
import { AccountSettingsService } from './account-settings.service.js';
import { DEFAULT_NOTIFICATION_PREFS } from './notification-prefs.js';

describe('notification prefs: newJobSound (r26 "Âm báo có đơn mới")', () => {
  const svc = () => new AccountSettingsService({} as never, {} as never);

  it('defaults to on for every user', async () => {
    expect(DEFAULT_NOTIFICATION_PREFS.newJobSound).toBe(true);
    await expect(svc().getNotificationPrefs('u1')).resolves.toMatchObject({ newJobSound: true, ride: true, food: true });
  });

  it('can be turned off without touching the other toggles, and back on', async () => {
    const s = svc();
    await s.updateNotificationPrefs('u1', { chat: false });
    await expect(s.updateNotificationPrefs('u1', { newJobSound: false })).resolves.toEqual({
      ...DEFAULT_NOTIFICATION_PREFS,
      chat: false,
      newJobSound: false,
    });
    await expect(s.getNotificationPrefs('u1')).resolves.toMatchObject({ newJobSound: false, chat: false, ride: true });
    await expect(s.updateNotificationPrefs('u1', { newJobSound: true })).resolves.toMatchObject({ newJobSound: true });
  });

  it('does not change who receives a push (only the sound)', async () => {
    const s = svc();
    await s.updateNotificationPrefs('u1', { newJobSound: false });
    await expect(s.filterRecipients(['u1'], 'RIDE')).resolves.toEqual(['u1']);
  });
});
