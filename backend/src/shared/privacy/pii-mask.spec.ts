import { describe, expect, it } from 'vitest';
import { maskEmail, maskPhone } from './pii-mask.js';

describe('pii-mask', () => {
  describe('maskPhone', () => {
    it('returns null for null, undefined, or empty string', () => {
      expect(maskPhone(null)).toBeNull();
      expect(maskPhone(undefined)).toBeNull();
      expect(maskPhone('')).toBeNull();
      expect(maskPhone('   ')).toBeNull();
    });

    it('returns raw when less than 6 digits', () => {
      expect(maskPhone('12345')).toBe('12345');
    });

    it('masks standard 10-digit Vietnamese phone numbers', () => {
      expect(maskPhone('0901234567')).toBe('0901 *** 567');
      expect(maskPhone('0987654321')).toBe('0987 *** 321');
    });

    it('handles international format with plus prefix', () => {
      expect(maskPhone('+84901234567')).toBe('+8490 *** 567');
    });

    it('cleans non-digit characters when determining validity', () => {
      expect(maskPhone('090-123-4567')).toBe('090- *** 567');
    });
  });

  describe('maskEmail', () => {
    it('returns null for null, undefined, or empty string', () => {
      expect(maskEmail(null)).toBeNull();
      expect(maskEmail(undefined)).toBeNull();
      expect(maskEmail('')).toBeNull();
    });

    it('masks standard email addresses', () => {
      expect(maskEmail('nguyen.van.a@example.com')).toBe('ng***a@example.com');
      expect(maskEmail('admin@dealgo.vn')).toBe('ad***n@dealgo.vn');
    });
  });
});
