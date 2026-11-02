import type { INestApplication } from '@nestjs/common';
import request from 'supertest';
import { PrismaService } from '../../src/platform/database/prisma.service.js';

/** Stores need a map pin before they can take orders (Hải Châu, Đà Nẵng). */
export const TEST_STORE_PIN = { lat: 16.0544, lng: 108.2022, addressLabel: 'Hải Châu, Đà Nẵng' } as const;

export async function pinStore(app: INestApplication, merchantToken: string): Promise<void> {
  await request(app.getHttpServer())
    .patch('/v1/food/merchant/store/location')
    .set('Authorization', `Bearer ${merchantToken}`)
    .send(TEST_STORE_PIN)
    .expect(200);
  await approveStoreItems(app, merchantToken);
}

/** FOOD-001: new dishes start PENDING; tests stand in for ops and approve the merchant's items. */
export async function approveStoreItems(app: INestApplication, merchantToken: string): Promise<void> {
  const catalog = await request(app.getHttpServer())
    .get('/v1/food/merchant/catalog')
    .set('Authorization', `Bearer ${merchantToken}`)
    .expect(200);
  const storeId = catalog.body.data.id as string;
  const db = app.get(PrismaService).db();
  if (!db) return;
  await db.foodItem.updateMany({ where: { storeId }, data: { moderationStatus: 'APPROVED' } });
}
