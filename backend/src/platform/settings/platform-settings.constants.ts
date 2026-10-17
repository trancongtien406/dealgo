export const PLATFORM_SETTINGS_REPOSITORY = Symbol('PLATFORM_SETTINGS_REPOSITORY');

/** Short in-process cache so hot ride/food paths avoid a DB round-trip every request. */
export const PLATFORM_SETTINGS_CACHE_TTL_MS = 5_000;
