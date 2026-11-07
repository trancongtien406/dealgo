import type { INestApplication } from '@nestjs/common';
import { json, type RequestHandler } from 'express';
import { UPLOAD_MAX_FILE_KB_CEILING } from '../settings/platform-settings.catalog.js';

export const AVATAR_UPLOAD_PATH = '/v1/me/avatar';

/** Merchant menu item form + photo upload (POST/PATCH /v1/food/merchant/items...). */
export const MENU_ITEM_IMAGE_JSON_LIMIT = '16mb';

// UploadAvatarDto accepts up to 2,000,000 base64 characters; leave room for JSON framing.
export const AVATAR_JSON_LIMIT = '3mb';

/** Base64 length of one file at the highest UPLOAD_MAX_FILE_KB an admin can set. */
export const UPLOAD_BASE64_MAX_CHARS = Math.ceil((UPLOAD_MAX_FILE_KB_CEILING * 1024 * 4) / 3) + 4;

/** KYC/KYB submissions carry up to PARTNER_MAX_DOCUMENTS_PER_REQUEST files. */
export const PARTNER_APPLICATION_PATH = '/v1/me/partner-applications';
export const PARTNER_APPLICATION_JSON_LIMIT = '45mb';

/** Ticket create/reply carry up to SUPPORT_MAX_ATTACHMENTS files. */
export const SUPPORT_TICKET_UPLOAD_PATHS = ['/v1/support/tickets', '/v1/ops/support-tickets'];
export const SUPPORT_TICKET_JSON_LIMIT = '24mb';

/**
 * Parcel booking (item photo) and driver proof photos (pickup/deliver/returned) send the
 * image as base64 JSON; ParcelPhotoDto allows up to 12,000,000 characters.
 */
export const PARCEL_UPLOAD_PATH = '/v1/parcels';
export const PARCEL_JSON_LIMIT = '16mb';

/** Amazon SNS posts JSON with `Content-Type: text/plain`; parse it as JSON on this route only. */
export const SES_WEBHOOK_BODY_PATH = '/v1/webhooks/ses';
export const SES_WEBHOOK_JSON_LIMIT = '256kb';

/**
 * Larger JSON limits for upload routes only; every other route keeps Nest's default
 * (100kb). Must run before `app.init()`/`listen()` so it precedes the global parser,
 * which then skips bodies that are already parsed. The per-file cap is enforced by
 * DocumentStoreService from admin settings; these limits only bound memory.
 */
export function registerRouteBodyParsers(app: INestApplication): void {
  app.use(AVATAR_UPLOAD_PATH, wrap(json({ limit: AVATAR_JSON_LIMIT })));
  // Express prefix mount: covers POST /items, PATCH /items/:itemId, and POST /items/:itemId/image.
  app.use(
    '/v1/food/merchant/items',
    wrap(json({ limit: MENU_ITEM_IMAGE_JSON_LIMIT })),
  );
  app.use(
    '/v1/ops/ride-vehicle-classes/:code/image',
    wrap(json({ limit: MENU_ITEM_IMAGE_JSON_LIMIT })),
  );
  app.use(PARTNER_APPLICATION_PATH, wrap(json({ limit: PARTNER_APPLICATION_JSON_LIMIT })));
  const ticketParser = wrap(json({ limit: SUPPORT_TICKET_JSON_LIMIT }));
  for (const path of SUPPORT_TICKET_UPLOAD_PATHS) {
    app.use(path, ticketParser);
  }
  app.use(PARCEL_UPLOAD_PATH, wrap(json({ limit: PARCEL_JSON_LIMIT })));
  app.use(SES_WEBHOOK_BODY_PATH, wrap(json({ limit: SES_WEBHOOK_JSON_LIMIT, type: () => true })));
}

// Wrapped because Nest skips its global parser when a middleware named `jsonParser`
// is already mounted, which would leave other routes without JSON parsing.
function wrap(parser: RequestHandler): RequestHandler {
  return (req, res, next) => parser(req, res, next);
}
