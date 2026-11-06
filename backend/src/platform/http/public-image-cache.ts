/**
 * Cache policy for public photos served by the API.
 *
 * Every uploaded file gets its own UUID name and a replaced photo gets a new
 * name, so a public photo URL never changes its bytes. That makes a one-year
 * immutable cache safe and keeps CDN edges warm instead of re-fetching the
 * object from storage every day.
 */
export const PUBLIC_IMAGE_CACHE_CONTROL =
  'public, max-age=31536000, immutable';
