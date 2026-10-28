import { HttpException, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { FoodService } from '../food-order/food.service.js';
import type { StoreDetail } from '../food-order/food.repository.js';

/** Store logos and covers are images only (same set as avatars and menu photos). */
export const STORE_LOGO_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;
export const STORE_LOGO_PUBLIC_PREFIX = '/v1/public/store-logos';
export const STORE_COVER_PUBLIC_PREFIX = '/v1/public/store-covers';
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;
const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type StoreImageKind = 'logo' | 'cover';

const KINDS = {
  logo: {
    dir: 'store-logos',
    prefix: STORE_LOGO_PUBLIC_PREFIX,
    label: 'store-logo',
    name: 'Store logo',
    notFound: 'STORE_LOGO_NOT_FOUND',
  },
  cover: {
    dir: 'store-covers',
    prefix: STORE_COVER_PUBLIC_PREFIX,
    label: 'store-cover',
    name: 'Store cover',
    notFound: 'STORE_COVER_NOT_FOUND',
  },
} as const;

function logoError(
  status: number,
  errorCode: string,
  message: string,
): HttpException {
  return new HttpException({ errorCode, message }, status);
}

/** Path stored on FoodStore.logoUrl / coverUrl; clients resolve against the API origin. */
export function storeLogoPath(
  storeId: string,
  key: string,
  kind: StoreImageKind = 'logo',
): string {
  const { dir, prefix } = KINDS[kind];
  return `${prefix}/${storeId}/${key.slice(`${dir}/${storeId}/`.length)}`;
}

export function keyFromStoreLogoUrl(
  url: string | null | undefined,
  kind: StoreImageKind = 'logo',
): string | null {
  const { dir, prefix } = KINDS[kind];
  if (!url?.startsWith(`${prefix}/`)) return null;
  const rest = url.slice(prefix.length + 1);
  const slash = rest.indexOf('/');
  if (slash < 0) return null;
  const storeId = rest.slice(0, slash);
  const file = rest.slice(slash + 1);
  if (!UUID_RE.test(storeId) || !FILE_RE.test(file)) return null;
  return `${dir}/${storeId}/${file}`;
}

/**
 * M030 merchant store logo and cover photo via the shared upload port (DEC-PROD-045).
 * Limits: UPLOAD_MAX_FILE_KB / UPLOAD_ALLOWED_TYPES; orphan cleanup covers store-logos/ and store-covers/.
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
    kind: StoreImageKind = 'logo',
  ): Promise<StoreDetail> {
    const config = KINDS[kind];
    const store = await this.food.ownedStoreForProfile(actor);
    const payload = resolvePayload(input);
    if (!payload) {
      throw logoError(
        400,
        'VALIDATION_ERROR',
        'contentBase64 or dataUrl is required',
      );
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    const typeError = () =>
      logoError(
        415,
        'UPLOAD_TYPE_NOT_ALLOWED',
        `${config.name} must be a JPEG, PNG or WebP image`,
      );
    if (
      normalized &&
      !(STORE_LOGO_TYPES as readonly string[]).includes(normalized)
    ) {
      throw typeError();
    }
    const previous = keyFromStoreLogoUrl(
      kind === 'logo' ? store.logoUrl : store.coverUrl,
      kind,
    );
    const updated = await this.uploads.storeThen(
      `${config.dir}/${store.id}`,
      [
        {
          label: config.label,
          contentType: payload.contentType,
          contentBase64: payload.base64,
        },
      ],
      async ([ref]) => {
        if (
          !(STORE_LOGO_TYPES as readonly string[]).includes(ref!.contentType)
        ) {
          throw typeError();
        }
        const path = storeLogoPath(store.id, ref!.key, kind);
        return kind === 'logo'
          ? this.food.setStoreLogo(actor, path)
          : this.food.setStoreCover(actor, path);
      },
    );
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return updated;
  }

  async clear(
    actor: RequestActor,
    kind: StoreImageKind = 'logo',
  ): Promise<StoreDetail> {
    const store = await this.food.ownedStoreForProfile(actor);
    const previous = keyFromStoreLogoUrl(
      kind === 'logo' ? store.logoUrl : store.coverUrl,
      kind,
    );
    const updated =
      kind === 'logo'
        ? await this.food.setStoreLogo(actor, null)
        : await this.food.setStoreCover(actor, null);
    if (previous) {
      await this.uploads.discard([{ key: previous }]);
    }
    return updated;
  }

  /** Serves only the store's current logo/cover; replaced or guessed keys answer 404. */
  async read(
    storeId: string,
    file: string,
    kind: StoreImageKind = 'logo',
  ): Promise<{ body: Buffer; contentType: string }> {
    const config = KINDS[kind];
    const missing = () =>
      logoError(404, config.notFound, `${config.name} not found`);
    if (!UUID_RE.test(storeId) || !FILE_RE.test(file)) {
      throw missing();
    }
    const key = `${config.dir}/${storeId}/${file}`;
    const current =
      kind === 'logo'
        ? await this.food.findStoreLogoUrl(storeId)
        : await this.food.findStoreCoverUrl(storeId);
    if (current !== storeLogoPath(storeId, key, kind)) {
      throw missing();
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const found = await this.uploads.read({
      key,
      contentType: ext === 'jpg' ? 'image/jpeg' : `image/${ext}`,
    });
    if (!found) {
      throw missing();
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
    return match
      ? { contentType: match[1] || input.contentType, base64: match[2]! }
      : null;
  }
  if (typeof input.contentBase64 === 'string' && input.contentBase64.trim()) {
    return {
      contentType: input.contentType,
      base64: input.contentBase64.trim(),
    };
  }
  return null;
}
