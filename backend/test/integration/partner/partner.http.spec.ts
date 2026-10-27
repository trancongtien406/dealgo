import { INestApplication } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { ThrottlerModule } from '@nestjs/throttler';
import { Test } from '@nestjs/testing';
import request from 'supertest';
import { createValidationPipe } from '../../../src/platform/http/create-validation-pipe.js';
import { HttpExceptionFilter } from '../../../src/platform/http/http-exception.filter.js';
import { ResponseInterceptor } from '../../../src/platform/http/response.interceptor.js';
import { loadEnv } from '../../../src/platform/config/env.js';
import { IDENTITY_REPOSITORY, SMS_SENDER } from '../../../src/modules/identity/identity.constants.js';
import { MemoryIdentityRepository } from '../../../src/modules/identity/identity.repository.js';
import { OpsAuthService } from '../../../src/modules/identity/ops-auth.service.js';
import { MockSmsSender } from '../../../src/integrations/sms/sms-sender.js';
import { PARTNER_REPOSITORY } from '../../../src/modules/partner/partner.constants.js';
import { PartnerModule } from '../../../src/modules/partner/partner.module.js';
import { MemoryPartnerRepository } from '../../../src/modules/partner/partner.repository.js';
import { OBJECT_STORAGE } from '../../../src/platform/storage/storage.constants.js';
import { MemoryObjectStorage } from '../../../src/integrations/object-storage/memory-object-storage.js';
import {
  TINY_JPEG_BASE64,
  TINY_PDF_BASE64,
} from '../../../src/platform/storage/testing.js';

const jpeg = (kind: string) => ({ kind, contentType: 'image/jpeg', contentBase64: TINY_JPEG_BASE64 });
const DRIVER_DOCS = ['ID_FRONT', 'ID_BACK', 'SELFIE', 'LICENSE', 'VEHICLE_REG'].map(jpeg);
const MERCHANT_DOCS = [
  { kind: 'BUSINESS_LICENSE', contentType: 'application/pdf', contentBase64: TINY_PDF_BASE64 },
  jpeg('REP_ID_FRONT'),
  jpeg('REP_ID_BACK'),
];

const OPS_EMAIL = 'ops@dealgo.test';
const OPS_PASSWORD = 'correct-horse-battery';

describe('partner application http', () => {
  let app: INestApplication;
  let identity: MemoryIdentityRepository;
  let partners: MemoryPartnerRepository;
  let sms: MockSmsSender;
  let storage: MemoryObjectStorage;
  let phoneSerial = 700;

  beforeAll(async () => {
    identity = new MemoryIdentityRepository();
    partners = new MemoryPartnerRepository();
    sms = new MockSmsSender('test');
    storage = new MemoryObjectStorage();

    const moduleRef = await Test.createTestingModule({
      imports: [
        ConfigModule.forRoot({
          isGlobal: true,
          ignoreEnvFile: true,
          validate: () =>
            loadEnv({
              NODE_ENV: 'test',
              JWT_ACCESS_SECRET: 'test-access-secret',
              JWT_ACCESS_TTL_SECONDS: '900',
              SMS_PROVIDER: 'mock',
              KYC_STORAGE_PROVIDER: 'mock',
              OTP_THROTTLE_LIMIT: '1000',
              OTP_PHONE_LIMIT: '1000',
            }),
        }),
        ThrottlerModule.forRoot([{ ttl: 60_000, limit: 1000 }]),
        PartnerModule,
      ],
    })
      .overrideProvider(SMS_SENDER)
      .useValue(sms)
      .overrideProvider(IDENTITY_REPOSITORY)
      .useValue(identity)
      .overrideProvider(PARTNER_REPOSITORY)
      .useValue(partners)
      .overrideProvider(OBJECT_STORAGE)
      .useValue(storage)
      .compile();

    app = moduleRef.createNestApplication();
    app.useGlobalPipes(createValidationPipe());
    app.useGlobalFilters(new HttpExceptionFilter());
    app.useGlobalInterceptors(new ResponseInterceptor(app.get(Reflector)));
    await app.init();
    await app.get(OpsAuthService).ensureOperator(OPS_EMAIL, OPS_PASSWORD, 'test');
  });

  afterAll(async () => {
    await app.close();
  });

  it('submits KYC, lists for ops, approves to ACTIVE grant, rejects to SUSPENDED', async () => {
    const driver = await login('+84907' + String(phoneSerial++).padStart(5, '0'));
    const submitted = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${driver.token}`)
      .send({
        role: 'DRIVER',
        metadata: { fullName: 'Nguyen Van A', licenseNumber: 'B2-123', vehicleClassCode: 'MOTORBIKE' },
        documents: DRIVER_DOCS,
      })
      .expect(200);

    expect(submitted.body.data).toMatchObject({
      role: 'DRIVER',
      status: 'SUBMITTED',
      metadata: { fullName: 'Nguyen Van A', licenseNumber: 'B2-123' },
    });
    expect(submitted.body.data.documents).toHaveLength(5);
    expect(submitted.body.data.documents[0]).toMatchObject({
      index: 0,
      kind: 'ID_FRONT',
      contentType: 'image/jpeg',
      hasFile: true,
    });
    expect(storage.size).toBe(5);

    const mine = await request(app.getHttpServer())
      .get('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${driver.token}`)
      .expect(200);
    expect(mine.body.data.applications).toHaveLength(1);

    const ops = await opsLogin();
    const queue = await request(app.getHttpServer())
      .get('/v1/ops/partner-applications')
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(queue.body.data.applications.some((row: { id: string }) => row.id === submitted.body.data.id)).toBe(
      true,
    );

    const single = await request(app.getHttpServer())
      .get(`/v1/ops/partner-applications/${submitted.body.data.id}`)
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(single.body.data.id).toBe(submitted.body.data.id);

    const file = await request(app.getHttpServer())
      .get(`/v1/ops/partner-applications/${submitted.body.data.id}/documents/3`)
      .set('Authorization', `Bearer ${ops.token}`)
      .buffer(true)
      .parse((res, done) => {
        const chunks: Buffer[] = [];
        res.on('data', (chunk: Buffer) => chunks.push(chunk));
        res.on('end', () => done(null, Buffer.concat(chunks)));
      })
      .expect(200);
    expect(file.headers['content-type']).toBe('image/jpeg');
    expect((file.body as Buffer).toString('base64')).toBe(TINY_JPEG_BASE64);
    await request(app.getHttpServer())
      .get(`/v1/ops/partner-applications/${submitted.body.data.id}/documents/9`)
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(404);
    await request(app.getHttpServer())
      .get(`/v1/ops/partner-applications/${submitted.body.data.id}/documents/0`)
      .set('Authorization', `Bearer ${driver.token}`)
      .expect((res) => expect([401, 403]).toContain(res.status));

    const approved = await request(app.getHttpServer())
      .post(`/v1/ops/partner-applications/${submitted.body.data.id}/approve`)
      .set('Authorization', `Bearer ${ops.token}`)
      .expect(200);
    expect(approved.body.data.status).toBe('APPROVED');
    expect(approved.body.data.reviewedBy).toBeTruthy();
    expect(approved.body.data.reviewedAt).toBeTruthy();

    const grants = await identity.listGrants(driver.userId);
    expect(grants.find((grant) => grant.role === 'DRIVER')?.status).toBe('ACTIVE');

    const merchant = await login('+84907' + String(phoneSerial++).padStart(5, '0'));
    const merchantApp = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ role: 'MERCHANT', metadata: { shopName: 'Bun Bo', shopLat: 16.06, shopLng: 108.22 }, documents: MERCHANT_DOCS })
      .expect(200);

    const rejected = await request(app.getHttpServer())
      .post(`/v1/ops/partner-applications/${merchantApp.body.data.id}/reject`)
      .set('Authorization', `Bearer ${ops.token}`)
      .send({
        reason: 'Incomplete KYB documents',
        issues: [{ section: 'STOREFRONT', note: 'Add a storefront photo' }],
      })
      .expect(200);
    expect(rejected.body.data).toMatchObject({
      status: 'REJECTED',
      reason: 'Incomplete KYB documents',
      issues: [{ section: 'STOREFRONT', note: 'Add a storefront photo' }],
    });
    const mineRejected = await request(app.getHttpServer())
      .get('/v1/me/partner-applications/merchant')
      .set('Authorization', `Bearer ${merchant.token}`)
      .expect(200);
    expect(mineRejected.body.data.issues).toEqual([
      { section: 'STOREFRONT', note: 'Add a storefront photo' },
    ]);
    const resubmitted = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${merchant.token}`)
      .send({ role: 'MERCHANT', metadata: { shopName: 'Bun Bo', shopLat: 16.06, shopLng: 108.22 }, documents: [jpeg('STOREFRONT')] })
      .expect(200);
    expect(resubmitted.body.data.documents.map((doc: { kind: string }) => doc.kind)).toEqual([
      'BUSINESS_LICENSE',
      'REP_ID_FRONT',
      'REP_ID_BACK',
      'STOREFRONT',
    ]);
    const merchantGrants = await identity.listGrants(merchant.userId);
    expect(merchantGrants.find((grant) => grant.role === 'MERCHANT')?.status).toBe('SUSPENDED');
  });

  it('validates documents on submit', async () => {
    const user = await login('+84907' + String(phoneSerial++).padStart(5, '0'));
    const missing = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ role: 'DRIVER', metadata: { vehicleClassCode: 'MOTORBIKE' }, documents: DRIVER_DOCS.slice(0, 2) })
      .expect(400);
    expect(missing.body.errorCode).toBe('PARTNER_DOCUMENTS_REQUIRED');
    expect(missing.body.details.missing).toEqual(['SELFIE', 'LICENSE', 'VEHICLE_REG']);
    await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ role: 'DRIVER', metadata: { vehicleClassCode: 'MOTORBIKE' }, documents: [{ kind: 'PASSPORT', contentBase64: TINY_JPEG_BASE64 }] })
      .expect(400);
    const wrongBytes = await request(app.getHttpServer())
      .post('/v1/me/partner-applications')
      .set('Authorization', `Bearer ${user.token}`)
      .send({
        role: 'DRIVER',
        metadata: { vehicleClassCode: 'MOTORBIKE' },
        documents: DRIVER_DOCS.map((doc, i) =>
          i === 0 ? { ...doc, contentBase64: Buffer.from('<svg></svg>').toString('base64') } : doc,
        ),
      })
      .expect(415);
    expect(wrongBytes.body.errorCode).toBe('UPLOAD_TYPE_NOT_ALLOWED');
  });

  async function login(phone: string): Promise<{ token: string; userId: string }> {
    const created = await request(app.getHttpServer())
      .post('/v1/auth/phone/challenges')
      .send({ phone })
      .expect(200);
    const code = sms.sent.at(-1)?.code;
    const verified = await request(app.getHttpServer())
      .post(`/v1/auth/phone/challenges/${created.body.data.challengeId}/verify`)
      .send({ code })
      .expect(200);
    return {
      token: verified.body.data.accessToken as string,
      userId: verified.body.data.user.id as string,
    };
  }

  async function opsLogin(): Promise<{ token: string }> {
    const response = await request(app.getHttpServer())
      .post('/v1/ops/sessions')
      .send({ email: OPS_EMAIL, password: OPS_PASSWORD })
      .expect(200);
    return { token: response.body.data.accessToken as string };
  }
});
