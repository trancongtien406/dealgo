import { Injectable } from '@nestjs/common';
import { PrismaService } from '../platform/database/prisma.service.js';
import { AVATAR_PUBLIC_PREFIX } from '../modules/avatar/avatar.service.js';
import { MENU_ITEM_PUBLIC_PREFIX } from '../modules/catalog/menu-item-image.service.js';
import { STORE_LOGO_PUBLIC_PREFIX } from '../modules/catalog/store-logo.service.js';

/** Storage prefixes that hold user uploads; nothing outside them is ever touched by the cleanup. */
export const UPLOAD_PREFIXES = ['partner-applications', 'support-attachments', 'avatars', 'menu-items', 'store-logos'] as const;

export const UPLOAD_REFERENCE_SOURCE = Symbol('UPLOAD_REFERENCE_SOURCE');

/** Every storage key a database record still points to. */
export interface UploadReferenceSource {
  /** Null when there is no database to ask (memory persistence): the cleanup must not run. */
  referencedKeys(): Promise<Set<string> | null>;
}

/**
 * Keys referenced by KYC/KYB documents (partner_applications.documents), ticket attachments
 * (support_ticket_messages.attachments) and current avatars (users.avatarUrl → avatars/<user>/<file>).
 * Add a branch here whenever a new table stores upload refs.
 */
@Injectable()
export class PrismaUploadReferences implements UploadReferenceSource {
  constructor(private readonly prisma: PrismaService) {}

  async referencedKeys(): Promise<Set<string> | null> {
    const db = this.prisma.db();
    if (!db) {
      return null;
    }
    const avatarPrefix = `${AVATAR_PUBLIC_PREFIX}/`;
    const menuPrefix = `${MENU_ITEM_PUBLIC_PREFIX}/`;
    const logoPrefix = `${STORE_LOGO_PUBLIC_PREFIX}/`;
    const rows = await db.$queryRaw<{ key: string | null }[]>`
      SELECT d->>'key' AS key
        FROM "partner_applications" p, jsonb_array_elements(
          CASE WHEN jsonb_typeof(p."documents") = 'array' THEN p."documents" ELSE '[]'::jsonb END) d
      UNION
      SELECT a->>'key' AS key
        FROM "support_ticket_messages" m, jsonb_array_elements(
          CASE WHEN jsonb_typeof(m."attachments") = 'array' THEN m."attachments" ELSE '[]'::jsonb END) a
      UNION
      SELECT 'avatars/' || substr(u."avatarUrl", ${avatarPrefix.length + 1}::int) AS key
        FROM "users" u
       WHERE u."avatarUrl" LIKE ${`${avatarPrefix}%`}
      UNION
      SELECT 'menu-items/' || substr(i."imageUrl", ${menuPrefix.length + 1}::int) AS key
        FROM "food_items" i
       WHERE i."imageUrl" LIKE ${`${menuPrefix}%`}
      UNION
      SELECT 'store-logos/' || substr(s."logoUrl", ${logoPrefix.length + 1}::int) AS key
        FROM "food_stores" s
       WHERE s."logoUrl" LIKE ${`${logoPrefix}%`}`;
    return new Set(rows.map((row) => row.key).filter((key): key is string => Boolean(key)));
  }
}
