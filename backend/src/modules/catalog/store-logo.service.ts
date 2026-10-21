import { HttpException, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { FoodService } from '../food-order/food.service.js';
import type { StoreDetail } from '../food-order/food.repository.js';

/** Store logos are images only (same set as avatars and menu photos). */
export const STORE_LOGO_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const STORE_LOGO_PUBLIC_PREFIX = '/v1/public/store-logos';
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function logoError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

/** Path stored on FoodStore.logoUrl; clients resolve against the API origin. */
export function storeLogoPath(storeId: string, key: string): string {
  return `${STORE_LOGO_PUBLIC_PREFIX}/${storeId}/${key.slice(`store-logos/${storeId}/`.length)}`;
}

export function keyFromStoreLogoUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${STORE_LOGO_PUBLIC_PREFIX}/`)) return null;
  const rest = url.slice(STORE_LOGO_PUBLIC_PREFIX.length + 1);
  const slash = rest.indexOf('/');
  if (slash < 0) return null;
  const storeId = rest.slice(0, slash);
  const file = rest.slice(slash + 1);
  if (!UUID_RE.test(storeId) || !FILE_RE.test(file)) return null;
  return `store-logos/${storeId}/${file}`;
}

/**
 * M030 merchant store logo via the shared upload port (DEC-PROD-045).
 * Limits: UPLOAD_MAX_FILE_KB / UPLOAD_ALLOWED_TYPES; orphan cleanup covers store-logos/.
 */
@Injectable()
export class StoreLogoService {
  constructor(
    private readonly food: FoodService,
    private readonly uploads: DocumentStoreService,
  ) {}

  async upload(
    actor: RequestActor,
    input: { contentBase64?: string; dataUrl?: string; contentType?: string },
  ): Promise<StoreDetail> {
    const store = await this.food.ownedStoreForProfile(actor);
    const payload = resolvePayload(input);
    if (!payload) {
      throw logoError(400, 'VALIDATION_ERROR', 'contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    if (normalized && !(STORE_LOGO_TYPES as readonly string[]).includes(normalized)) {
      throw logoError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Store logo must be a JPEG, PNG or WebP image');
    }
    const previous = keyFromStoreLogoUrl(store.logoUrl);
    const updated = await this.uploads.storeThen(
      `store-logos/${store.id}`,
      [{ label: 'store-logo', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!(STORE_LOGO_TYPES as readonly string[]).includes(ref!.contentType)) {
          throw logoError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Store logo must be a JPEG, PNG or WebP image');
        }
        return this.food.setStoreLogo(actor, storeLogoPath(store.id, ref!.key));
      },
    );
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return updated;
  }

  async clear(actor: RequestActor): Promise<StoreDetail> {
    const store = await this.food.ownedStoreForProfile(actor);
    const previous = keyFromStoreLogoUrl(store.logoUrl);
    const updated = await this.food.setStoreLogo(actor, null);
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return updated;
  }

  /** Serves only the store's current logo; replaced or guessed keys answer 404. */
  async read(storeId: string, file: string): Promise<{ body: Buffer; contentType: string }> {
    if (!UUID_RE.test(storeId) || !FILE_RE.test(file)) {
      throw logoError(404, 'STORE_LOGO_NOT_FOUND', 'Logo not found');
    }
    const key = `store-logos/${storeId}/${file}`;
    if ((await this.food.findStoreLogoUrl(storeId)) !== storeLogoPath(storeId, key)) {
      throw logoError(404, 'STORE_LOGO_NOT_FOUND', 'Logo not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const found = await this.uploads.read({ key, contentType: ext === 'jpg' ? 'image/jpeg' : `image/${ext}` });
    if (!found) {
      throw logoError(404, 'STORE_LOGO_NOT_FOUND', 'Logo not found');
    }
    return found;
  }
}

function resolvePayload(input: {
  contentBase64?: string;
  dataUrl?: string;
  contentType?: string;
}): { base64: string; contentType?: string } | null {
  if (typeof input.dataUrl === 'string' && input.dataUrl.trim()) {
    const match = /^data:([^;,]+)?;base64,(.+)$/i.exec(input.dataUrl.trim());
    return match ? { contentType: match[1] || input.contentType, base64: match[2]! } : null;
  }
  if (typeof input.contentBase64 === 'string' && input.contentBase64.trim()) {
    return { contentType: input.contentType, base64: input.contentBase64.trim() };
  }
  return null;
}
