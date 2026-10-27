import type { NewJobAlert, NewJobAlertKind } from '../../../integrations/push/new-job-sound.js';

type BooleanSettings = { getBoolean(key: 'NEW_JOB_CUSTOM_SOUND_ENABLED'): Promise<boolean> };
type PrefsReader = { getNotificationPrefs(userId: string): Promise<{ newJobSound?: boolean }> };

/**
 * Whether one recipient's new-job push uses the spoken DealGo sound: the admin switch
 * NEW_JOB_CUSTOM_SOUND_ENABLED and the user's `newJobSound` toggle must both be on.
 * Either off → `customSound: false` (default sound, still the high-importance channel).
 * Lookup errors fall back to the custom sound so a new job is never silent.
 */
export async function resolveNewJobAlert(
  kind: NewJobAlertKind,
  userId: string,
  deps: { settings?: BooleanSettings; prefs?: PrefsReader },
): Promise<NewJobAlert> {
  let platformOn = true;
  if (deps.settings) {
    try {
      platformOn = (await deps.settings.getBoolean('NEW_JOB_CUSTOM_SOUND_ENABLED')) !== false;
    } catch {
      platformOn = true;
    }
  }
  if (!platformOn) {
    return { kind, customSound: false };
  }
  let userOn = true;
  if (deps.prefs) {
    try {
      userOn = (await deps.prefs.getNotificationPrefs(userId)).newJobSound !== false;
    } catch {
      userOn = true;
    }
  }
  return { kind, customSound: userOn };
}
