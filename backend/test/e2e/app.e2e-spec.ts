import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types.js';
import { AppModule } from '../../src/app.module.js';

describe('AppController (e2e)', () => {
  let app: INestApplication<App>;

  beforeEach(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  it('/ (GET)', async () => {
    const response = await request(app.getHttpServer()).get('/').expect(200);
    expect(response.body).toMatchObject({
      success: true,
      statusCode: 200,
      message: 'OK',
      data: 'Hello World!',
    });
    expect(typeof response.body.requestId).toBe('string');
    expect(response.body.requestId.length).toBeGreaterThanOrEqual(8);
  });

  it('/health (GET) stays up when dependencies are down', async () => {
    const response = await request(app.getHttpServer()).get('/health').expect(200);

    expect(response.body).toEqual({
      status: expect.stringMatching(/^(ok|degraded)$/),
      checks: {
        database: expect.stringMatching(/^(up|down)$/),
        redis: expect.stringMatching(/^(up|down)$/),
      },
    });
    expect(response.body).not.toHaveProperty('stack');
  });

  it('/health/live (GET) reports process up', async () => {
    const response = await request(app.getHttpServer()).get('/health/live').expect(200);
    expect(response.body).toEqual({ status: 'ok' });
  });

  it('/health/ready (GET) requires database', async () => {
    const response = await request(app.getHttpServer()).get('/health/ready');
    expect([200, 503]).toContain(response.status);
    expect(response.body.checks.database).toMatch(/^(up|down)$/);
    if (response.body.checks.database === 'down') {
      expect(response.status).toBe(503);
      expect(response.body.status).toBe('not_ready');
    } else {
      expect(response.status).toBe(200);
      expect(response.body.status).toMatch(/^(ok|degraded)$/);
    }
  });

  afterEach(async () => {
    await app.close();
  });
});
