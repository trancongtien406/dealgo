import { HttpException, Inject, Injectable } from '@nestjs/common';
import { DocumentStoreService } from '../../platform/storage/document-store.service.js';
import { IDENTITY_REPOSITORY } from '../identity/identity.constants.js';
import type { IdentityRepository } from '../identity/identity.repository.js';

/** Avatars are images only, whatever UPLOAD_ALLOWED_TYPES also permits (e.g. PDF). */
export const AVATAR_TYPES = ['image/jpeg', 'image/png', 'image/webp'] as const;
export const AVATAR_PUBLIC_PREFIX = '/v1/public/avatars';
const FILE_RE = /^[0-9a-f-]{36}\.(jpg|png|webp)$/;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function avatarError(status: number, errorCode: string, message: string): HttpException {
  return new HttpException({ errorCode, message }, status);
}

/** Path stored in User.avatarUrl; clients resolve it against the API origin. */
export function avatarPath(key: string): string {
  return `${AVATAR_PUBLIC_PREFIX}/${key.slice('avatars/'.length)}`;
}

export function keyFromAvatarUrl(url: string | null | undefined): string | null {
  if (!url?.startsWith(`${AVATAR_PUBLIC_PREFIX}/`)) {
    return null;
  }
  return `avatars/${url.slice(AVATAR_PUBLIC_PREFIX.length + 1)}`;
}

/**
 * Avatar upload through the shared storage port (DEC-PROD-021), replacing the mock://
 * placeholder. The previous avatar object is removed once the profile points at the new one.
 */
@Injectable()
export class AvatarService {
  constructor(
    @Inject(IDENTITY_REPOSITORY) private readonly identity: IdentityRepository,
    private readonly uploads: DocumentStoreService,
  ) {}

  async upload(
    userId: string,
    input: { contentBase64?: string; dataUrl?: string; contentType?: string },
  ): Promise<{ avatarUrl: string }> {
    const user = await this.identity.findUserById(userId);
    if (!user) {
      throw avatarError(401, 'UNAUTHORIZED', 'Authentication required');
    }
    const previous = keyFromAvatarUrl(user.avatarUrl);
    const payload = resolveAvatarPayload(input);
    if (!payload) {
      throw avatarError(400, 'VALIDATION_ERROR', 'Avatar contentBase64 or dataUrl is required');
    }
    const declared = payload.contentType?.toLowerCase();
    if (declared && !(AVATAR_TYPES as readonly string[]).includes(declared === 'image/jpg' ? 'image/jpeg' : declared)) {
      throw avatarError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Avatar must be a JPEG, PNG or WebP image');
    }
    const avatarUrl = await this.uploads.storePublicThen(
      `avatars/${userId}`,
      [{ label: 'avatar', contentType: payload.contentType, contentBase64: payload.base64 }],
      async ([ref]) => {
        if (!(AVATAR_TYPES as readonly string[]).includes(ref!.contentType)) {
          throw avatarError(415, 'UPLOAD_TYPE_NOT_ALLOWED', 'Avatar must be a JPEG, PNG or WebP image');
        }
        const url = avatarPath(ref!.key);
        await this.identity.updateUserProfile(userId, { avatarUrl: url });
        return url;
      },
    );
    if (previous && previous !== keyFromAvatarUrl(avatarUrl)) {
      await this.uploads.discard([{ key: previous }]);
    }
    return { avatarUrl };
  }

  /** Serves only a user's current avatar; replaced or guessed keys answer 404. */
  async read(
    userId: string,
    file: string,
    width: number | null = null,
  ): Promise<{ body: Buffer; contentType: string }> {
    if (!UUID_RE.test(userId) || !FILE_RE.test(file)) {
      throw avatarError(404, 'AVATAR_NOT_FOUND', 'Avatar not found');
    }
    const key = `avatars/${userId}/${file}`;
    const user = await this.identity.findUserById(userId);
    if (!user || user.avatarUrl !== avatarPath(key)) {
      throw avatarError(404, 'AVATAR_NOT_FOUND', 'Avatar not found');
    }
    const ext = file.slice(file.lastIndexOf('.') + 1);
    const contentType = ext === 'jpg' ? 'image/jpeg' : `image/${ext}`;
    const found = await this.uploads.readDisplayImage({ key, contentType }, width);
    if (!found) {
      throw avatarError(404, 'AVATAR_NOT_FOUND', 'Avatar not found');
    }
    return found;
  }
}

function resolveAvatarPayload(input: {
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
