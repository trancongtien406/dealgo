import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { applyTrustProxy, parseTrustProxy } from './trust-proxy.js';

function ipApp(raw: string | undefined) {
  const app = express();
  applyTrustProxy(app, raw);
  app.get('/ip', (req, res) => {
    res.json({ ip: req.ip });
  });
  return app;
}

describe('TRUST_PROXY', () => {
  it('parses off / true / hops / subnet lists', () => {
    expect(parseTrustProxy(undefined)).toBeUndefined();
    expect(parseTrustProxy('')).toBeUndefined();
    expect(parseTrustProxy('false')).toBeUndefined();
    expect(parseTrustProxy('0')).toBeUndefined();
    expect(parseTrustProxy('true')).toBe(true);
    expect(parseTrustProxy('1')).toBe(1);
    expect(parseTrustProxy('loopback, 10.0.0.0/8')).toEqual(['loopback', '10.0.0.0/8']);
  });

  it('ignores X-Forwarded-For when unset (cannot be spoofed)', async () => {
    const res = await request(ipApp(undefined)).get('/ip').set('X-Forwarded-For', '203.0.113.9');
    expect(res.body.ip).not.toBe('203.0.113.9');
  });

  it('uses the client address from the trusted proxy hop', async () => {
    const res = await request(ipApp('1'))
      .get('/ip')
      .set('X-Forwarded-For', '198.51.100.1, 203.0.113.9');
    expect(res.body.ip).toBe('203.0.113.9');
  });
});
