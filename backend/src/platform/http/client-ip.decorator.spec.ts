import { describe, expect, it } from 'vitest';
import { extractClientIp } from './client-ip.decorator.js';

describe('extractClientIp', () => {
  it('returns null for empty or null requests', () => {
    expect(extractClientIp(null)).toBeNull();
    expect(extractClientIp(undefined)).toBeNull();
    expect(extractClientIp({})).toBeNull();
  });

  it('prioritizes cf-connecting-ip when present', () => {
    const ip = extractClientIp({
      headers: {
        'cf-connecting-ip': '118.69.182.10',
        'x-real-ip': '103.110.87.211',
        'x-forwarded-for': '118.69.182.10, 172.70.134.5',
      },
      ip: '103.110.87.211',
    });
    expect(ip).toBe('118.69.182.10');
  });

  it('uses x-real-ip when cf-connecting-ip is not present', () => {
    const ip = extractClientIp({
      headers: {
        'x-real-ip': '118.69.182.10',
        'x-forwarded-for': '118.69.182.10, 10.0.0.1',
      },
      ip: '10.0.0.1',
    });
    expect(ip).toBe('118.69.182.10');
  });

  it('takes the first IP from x-forwarded-for', () => {
    const ip = extractClientIp({
      headers: {
        'x-forwarded-for': '118.69.182.10, 10.0.0.1, 10.0.0.2',
      },
      ip: '10.0.0.2',
    });
    expect(ip).toBe('118.69.182.10');
  });

  it('falls back to req.ip if no headers are set', () => {
    const ip = extractClientIp({
      headers: {},
      ip: '127.0.0.1',
    });
    expect(ip).toBe('127.0.0.1');
  });

  it('strips ::ffff: IPv4-mapped IPv6 prefix', () => {
    const ip = extractClientIp({
      headers: {
        'cf-connecting-ip': '::ffff:118.69.182.10',
      },
    });
    expect(ip).toBe('118.69.182.10');
  });

  it('falls back to socket remoteAddress if headers and req.ip are empty', () => {
    const ip = extractClientIp({
      headers: {},
      socket: { remoteAddress: '192.168.1.50' },
    });
    expect(ip).toBe('192.168.1.50');
  });
});
