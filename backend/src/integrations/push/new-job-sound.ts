/**
 * Spoken "new job" alert sounds (r26). The app bundles one file per kind:
 * iOS `Runner/<name>.caf` (APNs `aps.sound`), Android `res/raw/<name>.ogg` played by a
 * dedicated notification channel (a channel's sound is fixed once created, so the ids are
 * versioned: change the file → bump `_v1`). The app creates every channel at start-up.
 */
export type NewJobAlertKind =
  'NEW_RIDE' | 'NEW_FOOD_JOB' | 'MERCHANT_NEW_ORDER';

export type NewJobSound = {
  /** Base file name (no extension) — Android res/raw resource and Flutter asset. */
  name: string;
  /** iOS bundle file for `aps.sound`. */
  iosSound: string;
  /** Android channel that plays the custom sound. */
  androidChannelId: string;
};

export const NEW_JOB_SOUNDS: Readonly<Record<NewJobAlertKind, NewJobSound>> = {
  NEW_RIDE: {
    name: 'dealgo_new_ride',
    iosSound: 'dealgo_new_ride.caf',
    androidChannelId: 'dealgo_new_ride_v1',
  },
  NEW_FOOD_JOB: {
    name: 'dealgo_new_food_job',
    iosSound: 'dealgo_new_food_job.caf',
    androidChannelId: 'dealgo_new_food_job_v1',
  },
  MERCHANT_NEW_ORDER: {
    name: 'dealgo_merchant_new_order',
    iosSound: 'dealgo_merchant_new_order.caf',
    androidChannelId: 'dealgo_merchant_new_order_v1',
  },
};

/**
 * High-importance channel with the system default sound, used for new-job pushes when the
 * custom sound is off (admin `NEW_JOB_CUSTOM_SOUND_ENABLED` or the user's `newJobSound`).
 */
export const NEW_JOB_DEFAULT_SOUND_CHANNEL_ID = 'dealgo_new_job_default_v1';

/** How a new-job push should sound: which kind, and whether the spoken file is used. */
export type NewJobAlert = { kind: NewJobAlertKind; customSound: boolean };
