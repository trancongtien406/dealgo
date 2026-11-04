import { describe, expect, it, vi } from 'vitest';
import { Logger } from '@nestjs/common';
import express from 'express';
import request from 'supertest';
import { createMorganMiddleware } from './morgan.js';
import { REQUEST_ID_HEADER, requestIdMiddleware } from '../http/request-id.js';

describe('createMorganMiddleware', () => {
  it('creates a morgan middleware function', () => {
    const middleware = createMorganMiddleware();
    expect(typeof middleware).toBe('function');
  });

  it('streams log messages through NestJS Logger with requestId correlation', async () => {
    const logSpy = vi.fn();
    const mockLogger = { log: logSpy } as unknown as Logger;

    const app = express();
    app.use(requestIdMiddleware);
    app.use(createMorganMiddleware(mockLogger));
    app.get('/test', (_req, res) => {
      res.status(200).send('OK');
    });

    await request(app).get('/test').set(REQUEST_ID_HEADER, 'req-custom-999');

    expect(logSpy).toHaveBeenCalled();
    const logMessage = logSpy.mock.calls[0][0];
    expect(logMessage).toContain('GET');
    expect(logMessage).toContain('/test');
    expect(logMessage).toContain('200');
    expect(logMessage).toContain('reqId=req-custom-999');
  });

  it('masks keyword query params in the logged URL', async () => {
    const logSpy = vi.fn();
    const mockLogger = { log: logSpy } as unknown as Logger;

    const app = express();
    app.use(requestIdMiddleware);
    app.use(createMorganMiddleware(mockLogger));
    app.get('/v1/food/search', (_req, res) => {
      res.status(200).send('OK');
    });

    await request(app)
      .get('/v1/food/search')
      .query({ q: 'hidden-keyword', search: 'secret-store', limit: 5 });

    const logMessage = logSpy.mock.calls[0][0];
    expect(logMessage).toContain('/v1/food/search?q=[redacted]&search=[redacted]&limit=5');
    expect(logMessage).not.toContain('hidden-keyword');
    expect(logMessage).not.toContain('secret-store');
  });

  it('skips logging for /health endpoint', async () => {
    const logSpy = vi.fn();
    const mockLogger = { log: logSpy } as unknown as Logger;

    const app = express();
    app.use(requestIdMiddleware);
    app.use(createMorganMiddleware(mockLogger));
    app.get('/health', (_req, res) => {
      res.status(200).send('OK');
    });

    await request(app).get('/health');

    expect(logSpy).not.toHaveBeenCalled();
  });
});
