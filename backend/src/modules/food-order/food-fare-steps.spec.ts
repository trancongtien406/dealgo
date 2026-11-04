import { describe, expect, it } from 'vitest';
import { clampToFoodFareSteps } from './food.service.js';

const MIN = 5_000;
const MAX = 100_000;
const STEP = 1_000;

describe('clampToFoodFareSteps', () => {
  it('rounds a distance quote up to the whole fare step', () => {
    expect(clampToFoodFareSteps(12_340, MIN, MAX, STEP)).toBe(13_000);
    expect(clampToFoodFareSteps(0, MIN, MAX, STEP)).toBe(MIN);
    expect(clampToFoodFareSteps(150_000, MIN, MAX, STEP)).toBe(MAX);
  });

  it('keeps an amount that is already on the grid', () => {
    expect(clampToFoodFareSteps(15_000, MIN, MAX, STEP)).toBe(15_000);
  });

  it('never steps past a maximum that is not on the grid', () => {
    expect(clampToFoodFareSteps(22_000, MIN, 22_500, STEP)).toBe(22_000);
  });

  it('follows the configured step', () => {
    expect(clampToFoodFareSteps(12_300, MIN, MAX, 500)).toBe(12_500);
  });
});
