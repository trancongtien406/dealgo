export const VOICE_PORT = Symbol('VOICE_PORT');
export const VOICE_CALL_REPOSITORY = Symbol('VOICE_CALL_REPOSITORY');

export type VoiceAggregateType = 'Ride' | 'FoodOrder';

/**
 * LiveKit join token lifetime. The token only has to be valid when the app joins; LiveKit
 * refreshes the session token itself while the participant stays connected.
 */
export const VOICE_SESSION_TTL_SECONDS = 600;

/** How long the callee's phone rings before the call becomes MISSED. */
export const VOICE_CALL_RING_SECONDS = 40;

/** An ACCEPTED call older than this is closed as STALE (both apps crashed without hanging up). */
export const VOICE_CALL_MAX_SECONDS = 2 * 60 * 60;

/** Chat note left in the trip thread for a call nobody answered. */
export const VOICE_MISSED_CALL_NOTE = '📞 Cuộc gọi nhỡ';
