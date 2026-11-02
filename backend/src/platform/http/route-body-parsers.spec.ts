import {
  Body,
  Controller,
  INestApplication,
  Module,
  Post,
} from '@nestjs/common';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { HttpExceptionFilter } from './http-exception.filter.js';
import {
  AVATAR_UPLOAD_PATH,
  PARCEL_UPLOAD_PATH,
  PARTNER_APPLICATION_PATH,
  registerRouteBodyParsers,
} from './route-body-parsers.js';

@Controller()
class EchoController {
  @Post(AVATAR_UPLOAD_PATH.slice(1))
  avatar(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }

  @Post(PARTNER_APPLICATION_PATH.slice(1))
  partner(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }

  @Post('v1/support/tickets/:id/messages')
  ticketReply(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }

  @Post('v1/public/support/tickets')
  publicTicket(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }

  @Post('v1/parcels/:id/pickup')
  parcelPickup(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }

  @Post('v1/other')
  other(@Body() body: { data?: string }) {
    return { length: body.data?.length ?? 0 };
  }
}

@Module({ controllers: [EchoController] })
class EchoModule {}

describe('registerRouteBodyParsers', () => {
  let app: INestApplication;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      imports: [EchoModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalFilters(new HttpExceptionFilter());
    registerRouteBodyParsers(app);
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('accepts a 2,000,000 character base64 avatar body', async () => {
    const data = 'A'.repeat(2_000_000);
    const response = await request(app.getHttpServer())
      .post(AVATAR_UPLOAD_PATH)
      .send({ data })
      .expect(201);
    expect(response.body).toEqual({ length: 2_000_000 });
  });

  it('accepts a camera-sized parcel proof photo (regression: 413 on pickup photo)', async () => {
    const data = 'A'.repeat(4_000_000);
    const response = await request(app.getHttpServer())
      .post(`${PARCEL_UPLOAD_PATH}/ride-1/pickup`)
      .send({ data })
      .expect(201);
    expect(response.body).toEqual({ length: 4_000_000 });
  });

  it('accepts multi-file document bodies on upload routes only', async () => {
    const data = 'A'.repeat(6_000_000);
    await request(app.getHttpServer()).post(PARTNER_APPLICATION_PATH).send({ data }).expect(201);
    await request(app.getHttpServer())
      .post('/v1/support/tickets/abc/messages')
      .send({ data })
      .expect(201);
    await request(app.getHttpServer())
      .post('/v1/public/support/tickets')
      .send({ data: 'A'.repeat(200_000) })
      .expect(413);
  });

  it('keeps the default limit on other routes', async () => {
    const tooLarge = await request(app.getHttpServer())
      .post('/v1/other')
      .send({ data: 'A'.repeat(200_000) })
      .expect(413);
    expect(tooLarge.body.errorCode).toBe('PAYLOAD_TOO_LARGE');
    const small = await request(app.getHttpServer())
      .post('/v1/other')
      .send({ data: 'abc' })
      .expect(201);
    expect(small.body).toEqual({ length: 3 });
  });

  it('rejects avatar bodies above the route limit with 413', async () => {
    await request(app.getHttpServer())
      .post(AVATAR_UPLOAD_PATH)
      .send({ data: 'A'.repeat(3_200_000) })
      .expect(413);
  });

  it('answers malformed JSON with 400 instead of 500', async () => {
    const malformed = await request(app.getHttpServer())
      .post('/v1/other')
      .set('Content-Type', 'application/json')
      .send('{"data":')
      .expect(400);
    expect(malformed.body.errorCode).toBe('BAD_REQUEST');
  });
});
