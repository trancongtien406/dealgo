import type { INestApplication } from '@nestjs/common';
import { AvatarModule } from '../../../src/modules/avatar/avatar.module.js';
import { OBJECT_STORAGE } from '../../../src/platform/storage/storage.constants.js';
import type { MemoryObjectStorage } from '../../../src/integrations/object-storage/memory-object-storage.js';
import { TINY_JPEG_BASE64, TINY_PDF_BASE64, TINY_PNG_BASE64 } from '../../../src/platform/storage/testing.js';
import { createTestApp } from '../../support/app-harness.js';

describe('avatar upload http (DEC-PROD-021)', () => {
  let harness: Awaited<ReturnType<typeof createTestApp>>;
  let app: INestApplication;

  beforeAll(async () => {
    harness = await createTestApp([AvatarModule]);
    app = harness.app;
  });

  afterAll(async () => {
    await app.close();
  });

  it('stores the image, serves only the current avatar and removes the replaced file', async () => {
    const user = await harness.login();
    const storage = app.get<MemoryObjectStorage>(OBJECT_STORAGE);

    const first = await harness
      .http()
      .post('/v1/me/avatar')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ contentBase64: TINY_JPEG_BASE64, contentType: 'image/jpeg' })
      .expect(200);
    const firstUrl = first.body.data.avatarUrl as string;
    expect(firstUrl).toMatch(new RegExp(`^/v1/public/avatars/${user.userId}/[0-9a-f-]{36}\\.jpg$`));

    const served = await harness.http().get(firstUrl).expect(200);
    expect(served.headers['content-type']).toContain('image/jpeg');
    expect(served.headers['cache-control']).toContain('public');
    expect(Buffer.from(served.body).equals(Buffer.from(TINY_JPEG_BASE64, 'base64'))).toBe(true);

    const second = await harness
      .http()
      .post('/v1/me/avatar')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ dataUrl: `data:image/png;base64,${TINY_PNG_BASE64}` })
      .expect(200);
    expect(second.body.data.avatarUrl).toMatch(/\.png$/);
    await harness.http().get(firstUrl).expect(404);
    expect(storage.has(firstUrl.replace('/v1/public/avatars/', 'avatars/'))).toBe(false);
    await harness.http().get(second.body.data.avatarUrl).expect(200);

    const pdf = await harness
      .http()
      .post('/v1/me/avatar')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ contentBase64: TINY_PDF_BASE64 });
    expect(pdf.status).toBe(415);
    const sizeBefore = storage.size;
    const lying = await harness
      .http()
      .post('/v1/me/avatar')
      .set('Authorization', `Bearer ${user.token}`)
      .send({ contentBase64: TINY_PDF_BASE64, contentType: 'image/png' });
    expect(lying.status).toBe(415);
    expect(storage.size).toBe(sizeBefore);

    await harness.http().get(`/v1/public/avatars/${user.userId}/../../etc`).expect(404);
    await harness.http().post('/v1/me/avatar').send({ contentBase64: TINY_JPEG_BASE64 }).expect(401);
  });
});
