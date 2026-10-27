import type { INestApplication } from '@nestjs/common';
import request from 'supertest';

/** Stores need a map pin before they can take orders (Hải Châu, Đà Nẵng). */
export const TEST_STORE_PIN = { lat: 16.0544, lng: 108.2022, addressLabel: 'Hải Châu, Đà Nẵng' } as const;

export async function pinStore(app: INestApplication, merchantToken: string): Promise<void> {
  await request(app.getHttpServer())
    .patch('/v1/food/merchant/store/location')
    .set('Authorization', `Bearer ${merchantToken}`)
    .send(TEST_STORE_PIN)
    .expect(200);
}
