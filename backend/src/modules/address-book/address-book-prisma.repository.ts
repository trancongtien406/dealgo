import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { ADDRESS_BOOK_LIMIT } from './address-book.constants.js';
import {
  AddressRuleError,
  assertKindFree,
  sortAddresses,
  type AddressBookRepository,
  type SavedAddress,
  type SavedAddressInput,
  type SavedAddressPatch,
} from './address-book.repository.js';

const select = {
  id: true,
  kind: true,
  label: true,
  addressLine: true,
  note: true,
  lat: true,
  lng: true,
  isDefault: true,
  createdAt: true,
  updatedAt: true,
} as const;

export class PrismaAddressBookRepository implements AddressBookRepository {
  constructor(private readonly db: PrismaClient) {}

  async list(userId: string): Promise<SavedAddress[]> {
    return sortAddresses(await this.db.savedAddress.findMany({ where: { userId }, select }));
  }

  async create(userId: string, input: SavedAddressInput): Promise<SavedAddress> {
    return this.db.$transaction(async (tx) => {
      const mine = await this.lockBook(tx, userId);
      if (mine.length >= ADDRESS_BOOK_LIMIT) {
        throw new AddressRuleError('ADDRESS_LIMIT_REACHED');
      }
      assertKindFree(mine, input.kind);
      const makeDefault = input.isDefault === true || mine.length === 0;
      if (makeDefault) {
        await tx.savedAddress.updateMany({ where: { userId }, data: { isDefault: false } });
      }
      return tx.savedAddress.create({
        data: {
          userId,
          kind: input.kind,
          label: input.label,
          addressLine: input.addressLine,
          note: input.note ?? null,
          lat: input.lat ?? null,
          lng: input.lng ?? null,
          isDefault: makeDefault,
        },
        select,
      });
    });
  }

  async update(userId: string, id: string, patch: SavedAddressPatch): Promise<SavedAddress> {
    return this.db.$transaction(async (tx) => {
      const mine = await this.lockBook(tx, userId);
      if (!mine.some((row) => row.id === id)) {
        throw new AddressRuleError('ADDRESS_NOT_FOUND');
      }
      if (patch.kind) {
        assertKindFree(mine, patch.kind, id);
      }
      if (patch.isDefault === true) {
        await tx.savedAddress.updateMany({
          where: { userId, id: { not: id } },
          data: { isDefault: false },
        });
      }
      return tx.savedAddress.update({
        where: { id },
        data: {
          ...(patch.kind !== undefined ? { kind: patch.kind } : {}),
          ...(patch.label !== undefined ? { label: patch.label } : {}),
          ...(patch.addressLine !== undefined ? { addressLine: patch.addressLine } : {}),
          ...(patch.note !== undefined ? { note: patch.note ?? null } : {}),
          ...(patch.lat !== undefined ? { lat: patch.lat ?? null } : {}),
          ...(patch.lng !== undefined ? { lng: patch.lng ?? null } : {}),
          ...(patch.isDefault === true ? { isDefault: true } : {}),
        },
        select,
      });
    });
  }

  async remove(userId: string, id: string): Promise<void> {
    await this.db.$transaction(async (tx) => {
      const mine = await this.lockBook(tx, userId);
      const row = mine.find((entry) => entry.id === id);
      if (!row) {
        throw new AddressRuleError('ADDRESS_NOT_FOUND');
      }
      await tx.savedAddress.delete({ where: { id } });
      if (row.isDefault) {
        const next = await tx.savedAddress.findFirst({
          where: { userId },
          orderBy: { createdAt: 'desc' },
          select: { id: true },
        });
        if (next) {
          await tx.savedAddress.update({ where: { id: next.id }, data: { isDefault: true } });
        }
      }
    });
  }

  /**
   * Serializes writes to one user's book: lock the user row, then read the book.
   * Keeps the limit, HOME/WORK and single-default rules intact under concurrent requests.
   */
  private async lockBook(tx: Prisma.TransactionClient, userId: string) {
    await tx.$queryRaw`SELECT "id" FROM "users" WHERE "id" = ${userId}::uuid FOR UPDATE`;
    return tx.savedAddress.findMany({
      where: { userId },
      select: { id: true, kind: true, isDefault: true },
    });
  }
}
