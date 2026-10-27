import { HttpException, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import { PlatformSettingsService } from '../../platform/settings/platform-settings.service.js';
import type { RequestActor } from '../identity/access-auth.guard.js';
import { FoodService } from '../food-order/food.service.js';
import type { StoreItemView } from '../food-order/food.repository.js';

/** Menu photos are images only (same set as avatars). */
export const MENU_ITEM_IMAGE_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const MENU_ITEM_PUBLIC_PREFIX = '/v1/public/menu-items';
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function imageError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

/** Path stored on FoodItem.imageUrl; clients resolve against the API origin. */
export function menuItemImagePath(itemId: string, key: string): string {
  return `${MENU_ITEM_PUBLIC_PREFIX}/${itemId}/${key.slice(`menu-items/${itemId}/`.length)}`;
}

export function keyFromMenuItemImageUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${MENU_ITEM_PUBLIC_PREFIX}/`)) {
    return null;
  }
  const rest = url.slice(MENU_ITEM_PUBLIC_PREFIX.length + 1);
  const slash = rest.indexOf('/');
  if (slash < 0) return null;
  const itemId = rest.slice(0, slash);
  const file = rest.slice(slash + 1);
  if (!UUID_RE.test(itemId) || !FILE_RE.test(file)) return null;
  return `menu-items/${itemId}/${file}`;
}

/**
 * Merchant menu item photo via the shared upload port (DEC-PROD-040).
 * Limits: UPLOAD_MAX_FILE_KB / UPLOAD_ALLOWED_TYPES; orphan cleanup covers menu-items/.
 */
@Injectable()
export class MenuItemImageService {
  constructor(
    private readonly food: FoodService,
    private readonly uploads: DocumentStoreService,
    private readonly settings: PlatformSettingsService,
  ) {}

  async upload(
    actor: RequestActor,
    itemId: string,
    input: { contentBase64?: string; dataUrl?: string; contentType?: string },
  ): Promise<StoreItemView> {
    if (!UUID_RE.test(itemId)) {
      throw imageError(404, 'FOOD_ITEM_NOT_FOUND', 'Item not found');
    }
    const current = await this.ownedItem(actor, itemId);
    const payload = resolvePayload(input);
    if (!payload) {
      throw imageError(400, 'VALIDATION_ERROR', 'contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    const normalized = declared === 'image/jpg' ? 'image/jpeg' : declared;
    if (normalized && !(MENU_ITEM_IMAGE_TYPES as readonly string[]).includes(normalized)) {
      throw imageError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Menu photo must be a JPEG, PNG or WebP image');
    }
    const updated = await this.uploads.storeThen(
      `menu-items/${itemId}`,
      [{ label: 'menu-item', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!(MENU_ITEM_IMAGE_TYPES as readonly string[]).includes(ref!.contentType)) {
          throw imageError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Menu photo must be a JPEG, PNG or WebP image');
        }
        const imageUrl = menuItemImagePath(itemId, ref!.key);
        const maxImages = await this.settings.getNumber('MENU_ITEM_MAX_IMAGES');
        const existing = [...(current.imageUrls ?? [])].filter((u) => u && u !== current.imageUrl);
        const cover = current.imageUrl;
        const gallery = cover ? [cover, ...existing.filter((u) => u !== cover)] : [...existing];
        if (gallery.length >= maxImages) {
          throw imageError(400, 'MENU_IMAGE_LIMIT', `At most ${maxImages} photos per item`);
        }
        const imageUrls = [...gallery, imageUrl];
        return this.food.updateItem(actor, itemId, {
          imageUrl: imageUrls[0],
          imageUrls,
        } as import('../food-order/food.dto.js').UpdateFoodItemDto);
      },
    );
    return updated;
  }

  async clear(actor: RequestActor, itemId: string): Promise<StoreItemView> {
    if (!UUID_RE.test(itemId)) {
      throw imageError(404, 'FOOD_ITEM_NOT_FOUND', 'Item not found');
    }
    const current = await this.ownedItem(actor, itemId);
    const keys = [
      keyFromMenuItemImageUrl(current.imageUrl),
      ...((current.imageUrls ?? []).map(keyFromMenuItemImageUrl)),
    ].filter((k): k is string => !!k);
    const unique = [...new Set(keys)];
    const updated = await this.food.updateItem(actor, itemId, {
      imageUrl: null,
      imageUrls: [],
    } as import('../food-order/food.dto.js').UpdateFoodItemDto);
    if (unique.length) {
      await this.uploads.discard(unique.map((key) => ({ key })));
    }
    return updated;
  }

  /** Serves only the item's current photo; replaced or guessed keys answer 404. */
  async read(itemId: string, file: string): Promise<{ body: Buffer; contentType: string }> {
    if (!UUID_RE.test(itemId) || !FILE_RE.test(file)) {
      throw imageError(404, 'MENU_IMAGE_NOT_FOUND', 'Image not found');
    }
    const key = `menu-items/${itemId}/${file}`;
    const expected = menuItemImagePath(itemId, key);
    const urls = await this.food.findItemImageUrls(itemId);
    if (!urls.includes(expected)) {
      throw imageError(404, 'MENU_IMAGE_NOT_FOUND', 'Image not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const contentType = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
    const found = await this.uploads.read({ key, contentType });
    if (!found) {
      throw imageError(404, 'MENU_IMAGE_NOT_FOUND', 'Image not found');
    }
    return found;
  }

  private async ownedItem(actor: RequestActor, itemId: string): Promise<StoreItemView> {
    const catalog = await this.food.getMerchantCatalog(actor);
    const item = catalog.items.find((row) => row.id === itemId);
    if (!item) {
      throw imageError(404, 'FOOD_ITEM_NOT_FOUND', 'Item not found');
    }
    return item;
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
