import { describe, expect, it } from 'vitest';
import { normalizeVnMobile } from './phone-number.js';

describe('normalizeVnMobile', () => {
  it('accepts assigned mobile prefixes in the shapes users type', () => {
    expect(normalizeVnMobile('0901 234 567')).toBe('+84901234567');
    expect(normalizeVnMobile('901234567')).toBe('+84901234567');
    expect(normalizeVnMobile('84901234567')).toBe('+84901234567');
    expect(normalizeVnMobile('+84 901 234 567')).toBe('+84901234567');
    expect(normalizeVnMobile('0321234567')).toBe('+84321234567');
    expect(normalizeVnMobile('0551234567')).toBe('+84551234567');
    expect(normalizeVnMobile('0871234567')).toBe('+84871234567');
    expect(normalizeVnMobile('0991234567')).toBe('+84991234567');
  });

  it('rejects landlines, short numbers, and unassigned blocks', () => {
    for (const bad of [
      '',
      '12345',
      '091234567',
      '0241234567',
      '0301234567',
      '0712345678',
      '0801234567',
      '0951234567',
      '+840901234567',
      '+14155550100',
    ]) {
      expect(normalizeVnMobile(bad)).toBeNull();
    }
  });
});
