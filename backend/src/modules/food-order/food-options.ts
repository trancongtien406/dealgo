import { FoodRuleError } from './food.error.js';

/** One choice inside an option group (e.g. "Size L", "+ Trân châu"). */
export type FoodOptionView = {
  id: string;
  name: string;
  /** Added to the item price per unit; never negative. */
  priceDeltaVnd: number;
  available: boolean;
  /** Max times this option may be chosen on one line (DEC-PROD-042). */
  maxQuantity: number;
};

/** Option group on a catalog item with its selection bounds. */
export type FoodOptionGroupView = {
  id: string;
  name: string;
  /** 0 = optional group; ≥ 1 = the customer must pick at least this many. */
  minSelect: number;
  maxSelect: number;
  options: FoodOptionView[];
};

/** What an order line keeps of a chosen option (survives later menu edits). */
export type FoodLineOption = {
  optionId: string;
  groupName: string;
  name: string;
  priceDeltaVnd: number;
  /** How many of this option were chosen (DEC-PROD-042); default 1 on legacy rows. */
  quantity: number;
};

export type FoodOptionGroupInput = {
  id?: string;
  name: string;
  minSelect: number;
  maxSelect: number;
  options: {
    id?: string;
    name: string;
    priceDeltaVnd: number;
    available?: boolean;
    maxQuantity?: number;
  }[];
};

export const FOOD_OPTION_LIMITS = {
  maxGroups: 10,
  maxOptionsPerGroup: 20,
  maxDeltaVnd: 1_000_000,
  maxNameLength: 80,
  maxQuantityPerOption: 20,
} as const;

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function clampMaxQuantity(raw: number | undefined): number {
  if (raw === undefined) return 1;
  if (!Number.isInteger(raw) || raw < 1 || raw > FOOD_OPTION_LIMITS.maxQuantityPerOption) {
    throw new FoodRuleError('FOOD_OPTIONS_INVALID');
  }
  return raw;
}

/**
 * Validates a merchant's full option layout for one item and returns it with
 * stable ids: ids already on this item are kept, anything else gets a new id
 * from `newId` (so a client cannot adopt another item's option ids).
 */
export function normalizeOptionGroups(
  input: FoodOptionGroupInput[],
  existing: FoodOptionGroupView[],
  newId: () => string,
): FoodOptionGroupView[] {
  if (input.length > FOOD_OPTION_LIMITS.maxGroups) {
    throw new FoodRuleError('FOOD_OPTIONS_INVALID');
  }
  const knownGroups = new Set(existing.map((group) => group.id));
  const knownOptions = new Set(existing.flatMap((group) => group.options.map((option) => option.id)));
  const usedIds = new Set<string>();
  const groupNames = new Set<string>();
  const keep = (id: string | undefined, known: Set<string>): string => {
    if (id && UUID_RE.test(id) && known.has(id) && !usedIds.has(id)) {
      usedIds.add(id);
      return id;
    }
    const fresh = newId();
    usedIds.add(fresh);
    return fresh;
  };
  return input.map((group) => {
    const name = group.name.trim();
    const nameKey = name.toLocaleLowerCase('vi');
    if (!name || name.length > FOOD_OPTION_LIMITS.maxNameLength || groupNames.has(nameKey)) {
      throw new FoodRuleError('FOOD_OPTIONS_INVALID');
    }
    groupNames.add(nameKey);
    const count = group.options.length;
    if (count < 1 || count > FOOD_OPTION_LIMITS.maxOptionsPerGroup) {
      throw new FoodRuleError('FOOD_OPTIONS_INVALID');
    }
    const { minSelect, maxSelect } = group;
    if (
      !Number.isInteger(minSelect) ||
      !Number.isInteger(maxSelect) ||
      minSelect < 0 ||
      maxSelect < 1 ||
      minSelect > maxSelect ||
      maxSelect > count * FOOD_OPTION_LIMITS.maxQuantityPerOption
    ) {
      throw new FoodRuleError('FOOD_OPTIONS_INVALID');
    }
    const optionNames = new Set<string>();
    const options = group.options.map((option) => {
      const optionName = option.name.trim();
      const optionKey = optionName.toLocaleLowerCase('vi');
      if (
        !optionName ||
        optionName.length > FOOD_OPTION_LIMITS.maxNameLength ||
        optionNames.has(optionKey) ||
        !Number.isInteger(option.priceDeltaVnd) ||
        option.priceDeltaVnd < 0 ||
        option.priceDeltaVnd > FOOD_OPTION_LIMITS.maxDeltaVnd
      ) {
        throw new FoodRuleError('FOOD_OPTIONS_INVALID');
      }
      optionNames.add(optionKey);
      return {
        id: keep(option.id, knownOptions),
        name: optionName,
        priceDeltaVnd: option.priceDeltaVnd,
        available: option.available ?? true,
        maxQuantity: clampMaxQuantity(option.maxQuantity),
      };
    });
    // A required group must stay satisfiable with what is currently available.
    if (options.filter((option) => option.available).length < minSelect) {
      throw new FoodRuleError('FOOD_OPTIONS_INVALID');
    }
    return { id: keep(group.id, knownGroups), name, minSelect, maxSelect, options };
  });
}

/**
 * Server-side selection check + price for one order line. optionIds may repeat
 * to express quantity (DEC-PROD-042). Every id must be available, each option
 * qty ≤ maxQuantity, each group sum qty within min/max.
 */
export function priceOptionSelection(
  groups: FoodOptionGroupView[],
  optionIds: readonly string[],
): { deltaVnd: number; options: FoodLineOption[] } {
  const counts = new Map<string, number>();
  for (const id of optionIds) {
    counts.set(id, (counts.get(id) ?? 0) + 1);
  }
  const matched = new Set<string>();
  const options: FoodLineOption[] = [];
  let deltaVnd = 0;
  for (const group of groups) {
    let groupQty = 0;
    for (const option of group.options) {
      const qty = counts.get(option.id) ?? 0;
      if (qty === 0) continue;
      if (!option.available || qty > option.maxQuantity) {
        throw new FoodRuleError('FOOD_OPTION_INVALID');
      }
      matched.add(option.id);
      groupQty += qty;
      deltaVnd += option.priceDeltaVnd * qty;
      options.push({
        optionId: option.id,
        groupName: group.name,
        name: option.name,
        priceDeltaVnd: option.priceDeltaVnd,
        quantity: qty,
      });
    }
    if (groupQty < group.minSelect || groupQty > group.maxSelect) {
      throw new FoodRuleError('FOOD_OPTION_INVALID');
    }
  }
  if (matched.size !== counts.size) {
    throw new FoodRuleError('FOOD_OPTION_INVALID');
  }
  return { deltaVnd, options };
}

/** Line identity: the same dish with a different choice is a separate line. */
export function lineKey(itemId: string, optionIds: readonly string[] | undefined): string {
  return `${itemId}|${[...(optionIds ?? [])].sort().join(',')}`;
}

/** Reads a stored JSON snapshot defensively (legacy rows have `[]`). */
export function parseLineOptions(value: unknown): FoodLineOption[] {
  if (!Array.isArray(value)) return [];
  return value.flatMap((row) => {
    if (!row || typeof row !== 'object') return [];
    const record = row as Record<string, unknown>;
    if (
      typeof record.optionId !== 'string' ||
      typeof record.groupName !== 'string' ||
      typeof record.name !== 'string' ||
      typeof record.priceDeltaVnd !== 'number'
    ) {
      return [];
    }
    const quantity =
      typeof record.quantity === 'number' && Number.isInteger(record.quantity) && record.quantity > 0
        ? record.quantity
        : 1;
    return [
      {
        optionId: record.optionId,
        groupName: record.groupName,
        name: record.name,
        priceDeltaVnd: record.priceDeltaVnd,
        quantity,
      },
    ];
  });
}
