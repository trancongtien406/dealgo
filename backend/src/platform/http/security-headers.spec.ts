import { describe, it, expect } from 'vitest';
import { Test } from '@nestjs/testing';
import { Controller, Get } from '@nestjs/common';
import type { NestExpressApplication } from '@nestjs/platform-express';
import request from 'supertest';

@Controller('test-security')
class TestSecurityController {
  @Get()
  ping() {
    return { ok: true };
  }
}

describe('Security Headers', () => {
  it('applies helmet 8 security headers and removes x-powered-by', async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [TestSecurityController],
    }).compile();

    const app = moduleRef.createNestApplication<NestExpressApplication>();
    app.useSecurityHeaders({
      contentSecurityPolicy: false,
      crossOriginResourcePolicy: { policy: 'cross-origin' },
    });
    await app.init();

    const res = await request(app.getHttpServer()).get('/test-security').expect(200);

    expect(res.headers['x-content-type-options']).toBe('nosniff');
    expect(res.headers['x-frame-options']).toBe('SAMEORIGIN');
    expect(res.headers['referrer-policy']).toBe('no-referrer');
    expect(res.headers['strict-transport-security']).toBeDefined();
    expect(res.headers['x-powered-by']).toBeUndefined();

    await app.close();
  });
});
