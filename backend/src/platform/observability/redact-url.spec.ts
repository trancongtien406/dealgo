import { describe, expect, it } from 'vitest';
import { pathWithoutQuery, redactUrl } from './redact-url.js';

describe('redactUrl', () => {
  it('leaves a URL without a query string untouched', () => {
    expect(redactUrl('/v1/food/stores')).toBe('/v1/food/stores');
    expect(redactUrl('/v1/food/stores?')).toBe('/v1/food/stores?');
  });

  it('masks the dish keyword but keeps the other params', () => {
    expect(redactUrl('/v1/food/search?q=b%C3%BAn%20b%C3%B2&limit=5&lat=16.05')).toBe(
      '/v1/food/search?q=[redacted]&limit=5&lat=16.05',
    );
  });

  it('masks the store browse keyword too', () => {
    expect(redactUrl('/v1/food/stores?search=tr%C3%A0%20s%E1%BB%AFa&page=2')).toBe(
      '/v1/food/stores?search=[redacted]&page=2',
    );
  });

  it('masks both keywords, any casing, encoded names and empty values', () => {
    expect(redactUrl('/x?Q=a&SEARCH=b&q=&search=')).toBe(
      '/x?Q=[redacted]&SEARCH=[redacted]&q=[redacted]&search=[redacted]',
    );
    expect(redactUrl('/x?q%5B%5D=a&limit=1')).toBe('/x?q%5B%5D=a&limit=1');
  });

  it('masks a keyword sent without a value', () => {
    expect(redactUrl('/x?q&page=1')).toBe('/x?q=[redacted]&page=1');
  });

  it('keeps params that merely contain the keyword name', () => {
    expect(redactUrl('/x?query=b%C3%BAn&qsort=asc')).toBe(
      '/x?query=b%C3%BAn&qsort=asc',
    );
  });
});

describe('pathWithoutQuery', () => {
  it('drops the query string and keeps the path', () => {
    expect(pathWithoutQuery('/v1/food/search?q=b%C3%BAn&limit=999')).toBe(
      '/v1/food/search',
    );
    expect(pathWithoutQuery('/v1/food/stores')).toBe('/v1/food/stores');
    expect(pathWithoutQuery('/v1/food/stores?')).toBe('/v1/food/stores');
  });
});
