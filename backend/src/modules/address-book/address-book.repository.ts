import { randomUUID } from 'node:crypto';
import { ADDRESS_BOOK_LIMIT, type SavedAddressKind } from './address-book.constants.js';

export type SavedAddress = {
  id: string;
  kind: SavedAddressKind;
  label: string;
  addressLine: string;
  note: string | null;
  lat: number | null;
  lng: number | null;
  isDefault: boolean;
  createdAt: Date;
  updatedAt: Date;
};

export type SavedAddressInput = {
  kind: SavedAddressKind;
  label: string;
  addressLine: string;
  note?: string | null;
  lat?: number | null;
  lng?: number | null;
  isDefault?: boolean;
};

export type SavedAddressPatch = Partial<SavedAddressInput>;

export type AddressRuleCode =
  | 'ADDRESS_NOT_FOUND'
  | 'ADDRESS_LIMIT_REACHED'
  | 'ADDRESS_KIND_TAKEN';

export class AddressRuleError extends Error {
  constructor(readonly code: AddressRuleCode) {
    super(code);
    this.name = 'AddressRuleError';
  }
}

/**
 * Rules shared by both stores: at most ADDRESS_BOOK_LIMIT rows, one HOME and one WORK,
 * exactly one default while the book is non-empty (the first address becomes default,
 * deleting the default promotes the newest remaining one).
 */
export interface AddressBookRepository {
  list(userId: string): Promise<SavedAddress[]>;
  create(userId: string, input: SavedAddressInput): Promise<SavedAddress>;
  /** Owner-scoped; ADDRESS_NOT_FOUND for other users' rows. */
  update(userId: string, id: string, patch: SavedAddressPatch): Promise<SavedAddress>;
  remove(userId: string, id: string): Promise<void>;
}

/** Sort: default first, then newest. */
export function sortAddresses(rows: SavedAddress[]): SavedAddress[] {
  return [...rows].sort(
    (a, b) =>
      Number(b.isDefault) - Number(a.isDefault) ||
      b.createdAt.getTime() - a.createdAt.getTime(),
  );
}

export function assertKindFree(
  rows: Pick<SavedAddress, 'id' | 'kind'>[],
  kind: SavedAddressKind,
  exceptId?: string,
): void {
  if (kind === 'OTHER') {
    return;
  }
  if (rows.some((row) => row.kind === kind && row.id !== exceptId)) {
    throw new AddressRuleError('ADDRESS_KIND_TAKEN');
  }
}

export class MemoryAddressBookRepository implements AddressBookRepository {
  private readonly rows = new Map<string, SavedAddress & { userId: string }>();
  private clock = 0;

  async list(userId: string): Promise<SavedAddress[]> {
    return sortAddresses(this.owned(userId)).map(strip);
  }

  async create(userId: string, input: SavedAddressInput): Promise<SavedAddress> {
    const mine = this.owned(userId);
    if (mine.length >= ADDRESS_BOOK_LIMIT) {
      throw new AddressRuleError('ADDRESS_LIMIT_REACHED');
    }
    assertKindFree(mine, input.kind);
    const makeDefault = input.isDefault === true || mine.length === 0;
    if (makeDefault) {
      for (const row of mine) {
        row.isDefault = false;
      }
    }
    const now = this.tick();
    const row = {
      id: randomUUID(),
      userId,
      kind: input.kind,
      label: input.label,
      addressLine: input.addressLine,
      note: input.note ?? null,
      lat: input.lat ?? null,
      lng: input.lng ?? null,
      isDefault: makeDefault,
      createdAt: now,
      updatedAt: now,
    };
    this.rows.set(row.id, row);
    return strip(row);
  }

  async update(userId: string, id: string, patch: SavedAddressPatch): Promise<SavedAddress> {
    const mine = this.owned(userId);
    const row = mine.find((entry) => entry.id === id);
    if (!row) {
      throw new AddressRuleError('ADDRESS_NOT_FOUND');
    }
    if (patch.kind) {
      assertKindFree(mine, patch.kind, id);
      row.kind = patch.kind;
    }
    if (patch.label !== undefined) row.label = patch.label;
    if (patch.addressLine !== undefined) row.addressLine = patch.addressLine;
    if (patch.note !== undefined) row.note = patch.note ?? null;
    if (patch.lat !== undefined) row.lat = patch.lat ?? null;
    if (patch.lng !== undefined) row.lng = patch.lng ?? null;
    if (patch.isDefault === true) {
      for (const other of mine) {
        other.isDefault = other.id === id;
      }
    }
    row.updatedAt = this.tick();
    return strip(row);
  }

  async remove(userId: string, id: string): Promise<void> {
    const row = this.owned(userId).find((entry) => entry.id === id);
    if (!row) {
      throw new AddressRuleError('ADDRESS_NOT_FOUND');
    }
    this.rows.delete(id);
    if (row.isDefault) {
      const next = sortAddresses(this.owned(userId))[0];
      if (next) {
        (next as SavedAddress).isDefault = true;
      }
    }
  }

  private owned(userId: string) {
    return [...this.rows.values()].filter((row) => row.userId === userId);
  }

  /** Strictly increasing timestamps so "newest" is deterministic in tests. */
  private tick(): Date {
    this.clock = Math.max(this.clock + 1, Date.now());
    return new Date(this.clock);
  }
}

function strip(row: SavedAddress & { userId?: string }): SavedAddress {
  const { userId: _userId, ...rest } = row;
  return { ...rest };
}
