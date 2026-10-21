import { describe, expect, it } from 'vitest';
import {
  lineKey,
  normalizeOptionGroups,
  parseLineOptions,
  priceOptionSelection,
  type FoodOptionGroupView,
} from './food-options.js';

let seq = 0;
const newId = () => `00000000-0000-4000-8000-${String(++seq).padStart(12, '0')}`;

const groups: FoodOptionGroupView[] = [
  {
    id: 'g-size',
    name: 'Size',
    minSelect: 1,
    maxSelect: 1,
    options: [
      { id: 'o-m', name: 'M', priceDeltaVnd: 0, available: true, maxQuantity: 1 },
      { id: 'o-l', name: 'L', priceDeltaVnd: 8000, available: true, maxQuantity: 1 },
    ],
  },
  {
    id: 'g-top',
    name: 'Topping',
    minSelect: 0,
    maxSelect: 2,
    options: [
      { id: 'o-pearl', name: 'Trân châu', priceDeltaVnd: 5000, available: true, maxQuantity: 1 },
      { id: 'o-jelly', name: 'Thạch', priceDeltaVnd: 4000, available: true, maxQuantity: 1 },
      { id: 'o-egg', name: 'Trứng', priceDeltaVnd: 6000, available: false, maxQuantity: 1 },
    ],
  },
];

describe('priceOptionSelection', () => {
  it('prices and snapshots a valid choice', () => {
    const priced = priceOptionSelection(groups, ['o-l', 'o-pearl', 'o-jelly']);
    expect(priced.deltaVnd).toBe(17000);
    expect(priced.options.map((o) => `${o.groupName}:${o.name}`)).toEqual([
      'Size:L',
      'Topping:Trân châu',
      'Topping:Thạch',
    ]);
  });

  it('rejects missing required, too many, unavailable, foreign and duplicate ids', () => {
    for (const ids of [
      [],
      ['o-m', 'o-l'],
      ['o-m', 'o-pearl', 'o-jelly', 'o-egg'],
      ['o-m', 'o-egg'],
      ['o-m', 'other-item-option'],
      ['o-m', 'o-m'],
    ]) {
      expect(() => priceOptionSelection(groups, ids), ids.join(',')).toThrow(
        expect.objectContaining({ code: 'FOOD_OPTION_INVALID' }),
      );
    }
  });

  it('items without groups take no options', () => {
    expect(priceOptionSelection([], []).deltaVnd).toBe(0);
    expect(() => priceOptionSelection([], ['o-m'])).toThrow();
  });

  it('rejects qty over maxQuantity and prices multiples', () => {
    const sized = [
      {
        id: 'g-top',
        name: 'Topping',
        minSelect: 0,
        maxSelect: 4,
        options: [
          { id: 'o-pearl', name: 'Trân châu', priceDeltaVnd: 5000, available: true, maxQuantity: 2 },
        ],
      },
    ];
    expect(() => priceOptionSelection(sized, ['o-pearl', 'o-pearl', 'o-pearl'])).toThrow();
    const priced = priceOptionSelection(sized, ['o-pearl', 'o-pearl']);
    expect(priced.deltaVnd).toBe(10000);
    expect(priced.options[0]?.quantity).toBe(2);
  });
});

describe('normalizeOptionGroups', () => {
  it('keeps ids already on the item and mints new ones otherwise', () => {
    const out = normalizeOptionGroups(
      [
        {
          id: 'g-size',
          name: ' Size ',
          minSelect: 1,
          maxSelect: 1,
          options: [
            { id: 'o-m', name: 'M', priceDeltaVnd: 0 },
            { id: '11111111-1111-4111-8111-111111111111', name: 'XL', priceDeltaVnd: 12000 },
          ],
        },
      ],
      [
        {
          ...groups[0],
          id: '22222222-2222-4222-8222-222222222222',
          options: [{ ...groups[0].options[0], id: '33333333-3333-4333-8333-333333333333' }],
        },
      ],
      newId,
    );
    expect(out[0].name).toBe('Size');
    // Neither 'g-size' nor the foreign uuid belongs to the existing item -> fresh ids.
    expect(out[0].id).not.toBe('g-size');
    expect(out[0].options[1].id).not.toBe('11111111-1111-4111-8111-111111111111');
    const kept = normalizeOptionGroups(
      [{ id: out[0].id, name: 'Size', minSelect: 1, maxSelect: 1, options: [{ id: out[0].options[0].id, name: 'M', priceDeltaVnd: 0 }] }],
      out,
      newId,
    );
    expect(kept[0].id).toBe(out[0].id);
    expect(kept[0].options[0].id).toBe(out[0].options[0].id);
  });

  it('rejects bad bounds, duplicate names, negative deltas and unsatisfiable groups', () => {
    const base = { name: 'Size', minSelect: 1, maxSelect: 1, options: [{ name: 'M', priceDeltaVnd: 0 }] };
    for (const bad of [
      [{ ...base, minSelect: 2, maxSelect: 1 }],
      [{ ...base, maxSelect: 0 }],
      [{ ...base, maxSelect: 99 }],
      [{ ...base, options: [] }],
      [{ ...base, options: [{ name: 'M', priceDeltaVnd: 0 }, { name: 'm', priceDeltaVnd: 0 }], maxSelect: 2 }],
      [{ ...base, options: [{ name: 'M', priceDeltaVnd: -1 }] }],
      [{ ...base, options: [{ name: 'M', priceDeltaVnd: 0, available: false, maxQuantity: 1 }] }],
      [base, { ...base, name: 'size' }],
    ]) {
      expect(() => normalizeOptionGroups(bad, [], newId)).toThrow(
        expect.objectContaining({ code: 'FOOD_OPTIONS_INVALID' }),
      );
    }
  });
});

describe('line helpers', () => {
  it('lineKey ignores option order; parseLineOptions drops junk', () => {
    expect(lineKey('i', ['b', 'a'])).toBe(lineKey('i', ['a', 'b']));
    expect(lineKey('i', [])).not.toBe(lineKey('i', ['a']));
    expect(parseLineOptions(null)).toEqual([]);
    expect(
      parseLineOptions([{ optionId: 'o', groupName: 'g', name: 'n', priceDeltaVnd: 1 }, { bad: true }]),

    ).toHaveLength(1);
  });
});
