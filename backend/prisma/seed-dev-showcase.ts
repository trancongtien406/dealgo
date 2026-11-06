/**
 * DEV-only comprehensive showcase seed. Idempotent: safe to re-run as often as needed.
 *
 *  1. Cleans up leftover E2E / perf-scale test garbage (stores, users, orders, rides, promos)
 *     from the local dev database while preserving real operator/dev accounts (`tien@gmail.com`,
 *     `ops@localhost`, `minh@dealgo.vn`, `appreview@...`, `@seed.dealgo.local`).
 *  2. Uploads & links ObjectStorage images for all 9 `FoodCategory` rows.
 *  3. Uploads & links ObjectStorage images for all 3 `RideVehicleClass` rows (`MOTORBIKE`, `CAR_4`, `CAR_7`).
 *  4. Uploads & activates `HomeBanner` rows for Customer (`ALL`, `RIDE`, `FOOD`), Driver, and Merchant.
 *  5. Seeds 18 complete Vietnamese `FoodStore`s across all 9 categories in both Đà Nẵng (`DN`)
 *     and TP.HCM (`HCM`), with logos, covers, descriptions, 24/7 hours, menu categories,
 *     100% image-backed menu items, option groups, store vouchers, delivered orders, and reviews.
 *  6. Seeds avatars, saved addresses, place search history, notifications, completed rides,
 *     and delivered food orders for `tien@gmail.com` and demo accounts.
 *
 * Fares are never hard-coded as production claims: ride fares come from `ride_vehicle_classes`
 * (DRAFT / ADMIN_EDITABLE, OPEN-003) and delivery fares from `FOOD_*` platform settings.
 */
import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client.js';
import { createObjectStorage } from '../src/platform/storage/storage.module.js';
import {
  PUBLIC_IMAGE_VARIANT_WIDTHS,
  imageVariantKey,
  toPublicWebp,
  toVariantWebp,
} from '../src/platform/storage/image-variants.js';
import { avatarPath } from '../src/modules/avatar/avatar.service.js';
import { menuItemImagePath } from '../src/modules/catalog/menu-item-image.service.js';
import { storeLogoPath } from '../src/modules/catalog/store-logo.service.js';
import { foodCategoryImagePath } from '../src/modules/food-category/food-category.js';
import { homeBannerImagePath } from '../src/modules/home-banner/home-banner.js';
import { rideVehicleClassImagePath } from '../src/modules/ride-vehicle/ride-vehicle-class-image.js';
import { quoteVehicleClassFare } from '../src/modules/ride-vehicle/ride-vehicle-class.js';
import { haversineKm } from '../src/shared/geo/haversine.js';

const BATCH02_DIR = resolve(process.cwd(), '../design/assets/batch02/png');
const BATCH01_DIR = resolve(process.cwd(), '../design/assets/batch01/png');
const MOBILE_IMG_DIR = resolve(process.cwd(), '../mobile/assets/images');
const DAY_MS = 86_400_000;

function loadDotEnv(): void {
  const envFile = resolve(process.cwd(), '.env');
  if (!existsSync(envFile)) return;
  for (const raw of readFileSync(envFile, 'utf8').split('\n')) {
    const line = raw.trim();
    if (!line || line.startsWith('#')) continue;
    const eq = line.indexOf('=');
    if (eq <= 0) continue;
    const key = line.slice(0, eq).trim();
    if (process.env[key] !== undefined) continue;
    let value = line.slice(eq + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    process.env[key] = value;
  }
}

/** Deterministic RFC 4122 v5-shaped UUID so re-runs reuse the same IDs and object keys. */
export function stableUuid(...parts: string[]): string {
  const h = createHash('sha1')
    .update(['dev-showcase-v2', ...parts].join('|'))
    .digest('hex')
    .slice(0, 32)
    .split('');
  h[12] = '5';
  h[16] = ((parseInt(h[16]!, 16) & 0x3) | 0x8).toString(16);
  const x = h.join('');
  return `${x.slice(0, 8)}-${x.slice(8, 12)}-${x.slice(12, 16)}-${x.slice(16, 20)}-${x.slice(20, 32)}`;
}

export function assertDevDatabase(url: string, nodeEnv: string | undefined): void {
  if (nodeEnv === 'production') {
    throw new Error('seed-dev-showcase refuses NODE_ENV=production');
  }
  const host = (() => {
    try {
      return new URL(url).hostname;
    } catch {
      return '';
    }
  })();
  if (!['localhost', '127.0.0.1', 'postgres', '::1'].includes(host)) {
    throw new Error('seed-dev-showcase only runs against a local DEV database');
  }
}

type DishSpec = {
  section: string;
  name: string;
  priceVnd: number;
  originalPriceVnd?: number;
  prepMinutes: number;
  soldCount: number;
  image: string;
  description: string;
  fresh?: boolean;
};

type ShowcaseStoreSpec = {
  key: string;
  matchName?: string;
  ownerEmail: string;
  ownerPhone: string;
  ownerName: string;
  name: string;
  category:
    | 'pho'
    | 'noodles'
    | 'rice'
    | 'banh_mi'
    | 'tea'
    | 'cafe'
    | 'fast_food'
    | 'snack'
    | 'mart';
  region: 'DN' | 'HCM';
  lat: number;
  lng: number;
  addressLabel: string;
  description: string;
  logo: string;
  cover: string;
  minOrderVnd: number;
  defaultPrepMinutes: number;
  voucher: {
    code: string;
    name: string;
    discountType: 'PERCENTAGE' | 'FIXED_AMOUNT';
    discountValue: number;
    maxDiscountAmount: number | null;
    minOrderAmount: number;
  };
  items: DishSpec[];
};

const CATEGORY_IMAGES: Record<string, { file: string; fallback: string }> = {
  pho: { file: 'food_pho_bo.png', fallback: 'food_bun_bo_hue.png' },
  noodles: { file: 'food_mi_quang.png', fallback: 'food_mi_quang.png' },
  rice: { file: 'food_grilled_rice.png', fallback: 'food_grilled_rice.png' },
  banh_mi: { file: 'food_banh_mi.png', fallback: 'food_banh_mi.png' },
  tea: { file: 'food_tra_sua.png', fallback: 'food_tra_sua.png' },
  cafe: { file: 'food_coffee.png', fallback: 'food_coffee.png' },
  fast_food: { file: 'food_fast_food_burger.png', fallback: 'food_pizza.png' },
  snack: { file: 'food_snack_platter.png', fallback: 'food_seafood.png' },
  mart: { file: 'food_fresh_grocery.png', fallback: 'store_supermarket.png' },
};

const VEHICLE_IMAGES: Record<string, { file: string; fallback: string }> = {
  MOTORBIKE: { file: 'vehicle_scooter_green.png', fallback: 'vehicle_motorbike.png' },
  CAR_4: { file: 'vehicle_car_4.png', fallback: 'vehicle_scooter_white.png' },
  CAR_7: { file: 'vehicle_car_7.png', fallback: 'vehicle_scooter_red.png' },
};

const SHOWCASE_STORES: ShowcaseStoreSpec[] = [
  // ==================== ĐÀ NẴNG (DN) — All 9 Categories ====================
  {
    key: 'dn-pho-hanoi',
    ownerEmail: 'merchant.phodn@seed.dealgo.local',
    ownerPhone: '+84907110011',
    ownerName: 'Phở Bò Gia Truyền Hà Nội',
    name: 'Phở Bò Gia Truyền — Hải Châu',
    category: 'pho',
    region: 'DN',
    lat: 16.0685,
    lng: 108.2215,
    addressLabel: '58 Nguyễn Chí Thanh, Hải Châu, Đà Nẵng',
    description:
      'Phở bò chuẩn vị Hà Nội xưa: nước dùng ninh xương ống 16 tiếng cùng thảo quả, quế chi và gừng nướng thơm lừng.',
    logo: 'store_noodle_shop.png',
    cover: 'food_pho_bo.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 10,
    voucher: {
      code: 'PHODN15K',
      name: 'Giảm 15.000đ cho đơn từ 60.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 15_000,
      maxDiscountAmount: null,
      minOrderAmount: 60_000,
    },
    items: [
      {
        section: 'Phở bò truyền thống',
        name: 'Phở bò tái nạm đặc biệt',
        priceVnd: 55_000,
        originalPriceVnd: 65_000,
        prepMinutes: 10,
        soldCount: 485,
        image: 'food_pho_bo.png',
        description: 'Thịt bò tái mềm ngọt, nạm gầu giòn béo, bánh phở mềm mượt.',
        fresh: true,
      },
      {
        section: 'Phở bò truyền thống',
        name: 'Phở bò tái lăn Hà Nội',
        priceVnd: 50_000,
        prepMinutes: 10,
        soldCount: 312,
        image: 'food_bun_bo_hue.png',
        description: 'Thịt bò xào lửa lớn dậy mùi tỏi phi, nước dùng béo đậm.',
      },
      {
        section: 'Phở bò truyền thống',
        name: 'Phở bắp bò gân giòn',
        priceVnd: 60_000,
        prepMinutes: 12,
        soldCount: 228,
        image: 'food_bun_bo_special.png',
        description: 'Bắp hoa bò giòn sần sật kèm gân bò hầm mềm.',
      },
      {
        section: 'Món ăn kèm',
        name: 'Quẩy giòn & Trứng chần (2 quả)',
        priceVnd: 15_000,
        prepMinutes: 3,
        soldCount: 390,
        image: 'food_pastries_flan.png',
        description: 'Quẩy nóng giòn ăn kèm trứng gà ta chần nước phở béo ngậy.',
      },
      {
        section: 'Đồ uống',
        name: 'Trà đá hoa nhài',
        priceVnd: 10_000,
        prepMinutes: 2,
        soldCount: 510,
        image: 'food_fruit_tea.png',
        description: 'Trà xanh ướp hoa nhài thanh mát.',
      },
    ],
  },
  {
    key: 'dn-mi-quang-ba-mua',
    matchName: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng',
    ownerEmail: 'merchant.miquang@seed.dealgo.local',
    ownerPhone: '+84907110001',
    ownerName: 'Mì Quảng Bà Mua',
    name: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng',
    category: 'noodles',
    region: 'DN',
    lat: 16.0678,
    lng: 108.2208,
    addressLabel: '19 Trần Bình Trọng, Quận Hải Châu, Đà Nẵng',
    description:
      'Đặc sản Mì Quảng xứ Quảng trứ danh: sợi mì gạo dẻo thơm, nhân gà ta, tôm thịt, ếch đồng đậm đà kèm bánh tráng nướng mè.',
    logo: 'store_noodle_shop.png',
    cover: 'food_mi_quang.png',
    minOrderVnd: 25_000,
    defaultPrepMinutes: 12,
    voucher: {
      code: 'BAMUA10',
      name: 'Giảm 10% tối đa 25.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 10,
      maxDiscountAmount: 25_000,
      minOrderAmount: 50_000,
    },
    items: [
      {
        section: 'Mì Quảng',
        name: 'Mì Quảng gà ta',
        priceVnd: 50_000,
        prepMinutes: 12,
        soldCount: 464,
        image: 'food_mi_quang.png',
        description: 'Mì Quảng gà ta xé, nước nhân nghệ thơm và đậu phộng rang.',
      },
      {
        section: 'Mì Quảng',
        name: 'Mì Quảng tôm thịt',
        priceVnd: 55_000,
        originalPriceVnd: 65_000,
        prepMinutes: 12,
        soldCount: 508,
        image: 'food_seafood.png',
        description: 'Tôm đất tươi, thịt ba chỉ rim, trứng cút và bánh tráng nướng giòn.',
      },
      {
        section: 'Mì Quảng',
        name: 'Mì Quảng ếch đồng',
        priceVnd: 60_000,
        prepMinutes: 15,
        soldCount: 228,
        image: 'food_bun_home.png',
        description: 'Ếch đồng om sả nghệ đậm vị miền Trung, ăn kèm rau sống 9 vị.',
      },
      {
        section: 'Món ăn kèm',
        name: 'Bánh tráng nướng mè',
        priceVnd: 15_000,
        prepMinutes: 4,
        soldCount: 382,
        image: 'food_snack_platter.png',
        description: 'Bánh tráng Đại Lộc nướng than giòn rụm, thơm mùi mè đen.',
      },
      {
        section: 'Nước uống',
        name: 'Nước mía sầu riêng',
        priceVnd: 20_000,
        prepMinutes: 4,
        soldCount: 246,
        image: 'food_fruit_tea.png',
        description: 'Nước mía ép tươi kết hợp cơm sầu riêng béo thơm.',
      },
    ],
  },
  {
    key: 'dn-com-nha-lam',
    matchName: 'Quán Cơm Nhà Làm — Hải Châu',
    ownerEmail: 'merchant.comnhalam@seed.dealgo.local',
    ownerPhone: '+84909990011',
    ownerName: 'Quán Cơm Nhà Làm',
    name: 'Quán Cơm Nhà Làm — Hải Châu',
    category: 'rice',
    region: 'DN',
    lat: 16.0662,
    lng: 108.2238,
    addressLabel: '120 Bạch Đằng, Hải Châu, Đà Nẵng',
    description:
      'Cơm nhà ấm cúng bên bờ sông Hàn: cơm gà xối mỡ giòn rụm, cơm sườn nướng mật ong và canh rau nấu mới mỗi ngày.',
    logo: 'food_grilled_rice.png',
    cover: 'food_grilled_meat.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 12,
    voucher: {
      code: 'COMNHA12K',
      name: 'Giảm 12.000đ cho đơn từ 50.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 12_000,
      maxDiscountAmount: null,
      minOrderAmount: 50_000,
    },
    items: [
      {
        section: 'Cơm đĩa đặc sắc',
        name: 'Cơm gà xối mỡ giòn da',
        priceVnd: 45_000,
        originalPriceVnd: 55_000,
        prepMinutes: 12,
        soldCount: 430,
        image: 'food_grilled_meat.png',
        description: 'Đùi gà góc tư xối mỡ giòn rụm, cơm chiên nghệ hạt tơi, đồ chua.',
      },
      {
        section: 'Cơm đĩa đặc sắc',
        name: 'Cơm tấm sườn nướng mật ong',
        priceVnd: 50_000,
        prepMinutes: 12,
        soldCount: 385,
        image: 'food_grilled_rice.png',
        description: 'Sườn cốt lết ướp mật ong nướng than hoa, bì thính, chả trứng.',
      },
      {
        section: 'Bún & Bánh mì',
        name: 'Bún thịt nướng nem lụi',
        priceVnd: 42_000,
        prepMinutes: 10,
        soldCount: 290,
        image: 'food_bun_home.png',
        description: 'Thịt nướng than thơm lừng, nem lụi Huế, nước lèo đậu phộng.',
      },
      {
        section: 'Bún & Bánh mì',
        name: 'Bánh mì thịt nướng đặc biệt',
        priceVnd: 28_000,
        prepMinutes: 6,
        soldCount: 215,
        image: 'food_banh_mi.png',
        description: 'Pate gan nhà làm, thịt nướng, chả bò Đà Nẵng, rau dưa.',
      },
      {
        section: 'Đồ uống',
        name: 'Trà đào cam sả mát lạnh',
        priceVnd: 25_000,
        prepMinutes: 4,
        soldCount: 310,
        image: 'food_fruit_tea.png',
        description: 'Trà đào miếng giòn ngọt, cam vàng và sả tươi.',
      },
    ],
  },
  {
    key: 'dn-banh-mi-ba-lan',
    ownerEmail: 'merchant.banhmidn@seed.dealgo.local',
    ownerPhone: '+84907110012',
    ownerName: 'Bánh Mì Bà Lan Đà Nẵng',
    name: 'Tiệm Bánh Mì Bà Lan — Trưng Nữ Vương',
    category: 'banh_mi',
    region: 'DN',
    lat: 16.0645,
    lng: 108.221,
    addressLabel: '62 Trưng Nữ Vương, Hải Châu, Đà Nẵng',
    description:
      'Tiệm bánh mì truyền thống hơn 30 năm tại Đà Nẵng: ổ bánh mì nóng giòn, pate béo mịn, chả bò nguyên chất và thịt nguội tự làm.',
    logo: 'food_banh_mi.png',
    cover: 'food_banh_mi.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 6,
    voucher: {
      code: 'BALAN10K',
      name: 'Giảm 10.000đ cho đơn từ 45.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 10_000,
      maxDiscountAmount: null,
      minOrderAmount: 45_000,
    },
    items: [
      {
        section: 'Bánh mì truyền thống',
        name: 'Bánh mì thập cẩm chả bò đặc biệt',
        priceVnd: 32_000,
        originalPriceVnd: 38_000,
        prepMinutes: 5,
        soldCount: 640,
        image: 'food_banh_mi.png',
        description: 'Đầy ắp chả bò Đà Nẵng, thịt nguội, chả heo, pate gan và bơ trứng.',
        fresh: true,
      },
      {
        section: 'Bánh mì truyền thống',
        name: 'Bánh mì gà xé sốt bơ trứng',
        priceVnd: 28_000,
        prepMinutes: 5,
        soldCount: 425,
        image: 'food_grilled_meat.png',
        description: 'Thịt gà ta xé phay, sốt bơ trứng béo ngậy, dưa leo và hành ngò.',
      },
      {
        section: 'Bánh mì truyền thống',
        name: 'Bánh mì ốp la 2 trứng pate',
        priceVnd: 25_000,
        prepMinutes: 6,
        soldCount: 318,
        image: 'food_pastries_flan.png',
        description: 'Hai trứng gà ốp la lòng đào kèm pate nóng và xì dầu ớt.',
      },
      {
        section: 'Đồ uống buổi sáng',
        name: 'Cà phê phin sữa đá đậm vị',
        priceVnd: 20_000,
        prepMinutes: 4,
        soldCount: 490,
        image: 'food_coffee.png',
        description: 'Cà phê Robusta Buôn Ma Thuột pha phin truyền thống.',
      },
    ],
  },
  {
    key: 'dn-tra-sua-gongcha',
    ownerEmail: 'merchant.trasuadn@seed.dealgo.local',
    ownerPhone: '+84907110013',
    ownerName: 'Trà Sữa Bạch Đằng',
    name: 'Trà Sữa & Kem Cheese — Bạch Đằng',
    category: 'tea',
    region: 'DN',
    lat: 16.0695,
    lng: 108.2242,
    addressLabel: '30 Bạch Đằng, Hải Châu, Đà Nẵng',
    description:
      'Trà sữa ủ lá trà nguyên bản Đài Loan, lớp kem milkfoam mặn béo và trân châu hoàng kim nấu mới mỗi 3 tiếng.',
    logo: 'store_coffee_shop.png',
    cover: 'food_tra_sua.png',
    minOrderVnd: 30_000,
    defaultPrepMinutes: 8,
    voucher: {
      code: 'TRASUADN15',
      name: 'Giảm 15% tối đa 30.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 15,
      maxDiscountAmount: 30_000,
      minOrderAmount: 60_000,
    },
    items: [
      {
        section: 'Trà sữa kem cheese',
        name: 'Trà sữa trân châu đường đen kem trứng',
        priceVnd: 48_000,
        originalPriceVnd: 58_000,
        prepMinutes: 8,
        soldCount: 720,
        image: 'food_tra_sua.png',
        description: 'Sữa tươi thanh trùng, trân châu đường đen nấu ấm và kem trứng khè.',
        fresh: true,
      },
      {
        section: 'Trà sữa kem cheese',
        name: 'Trà Ô Long kem milkfoam mặn',
        priceVnd: 45_000,
        prepMinutes: 7,
        soldCount: 510,
        image: 'food_coffee.png',
        description: 'Trà Ô Long cao sơn thanh khiết phủ lớp kem phô mai mặn béo.',
      },
      {
        section: 'Trà trái cây tươi',
        name: 'Trà đào cam sả nhiệt đới',
        priceVnd: 45_000,
        prepMinutes: 6,
        soldCount: 615,
        image: 'food_fruit_tea.png',
        description: 'Trà lài ủ lạnh kết hợp đào miếng giòn, cam vàng và hạt chia.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh sừng bò bơ Pháp & Flan',
        priceVnd: 35_000,
        prepMinutes: 4,
        soldCount: 280,
        image: 'food_pastries_flan.png',
        description: 'Croissant ngàn lớp thơm bơ Pháp ăn kèm bánh flan caramel.',
      },
    ],
  },
  {
    key: 'dn-cong-caphe',
    ownerEmail: 'merchant.cafedn@seed.dealgo.local',
    ownerPhone: '+84907110014',
    ownerName: 'Cộng Cà Phê Đà Nẵng',
    name: 'Cộng Cà Phê — Bạch Đằng Đà Nẵng',
    category: 'cafe',
    region: 'DN',
    lat: 16.0702,
    lng: 108.2244,
    addressLabel: '96 Bạch Đằng, Hải Châu, Đà Nẵng',
    description:
      'Không gian cà phê ven sông Hàn với món Cà phê cốt dừa đá xay đặc trưng, bạc xỉu và trà cam quế ấm áp.',
    logo: 'food_coffee.png',
    cover: 'food_coffee.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 7,
    voucher: {
      code: 'CAFEDN10K',
      name: 'Giảm 10.000đ cho đơn từ 50.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 10_000,
      maxDiscountAmount: null,
      minOrderAmount: 50_000,
    },
    items: [
      {
        section: 'Cà phê cốt dừa',
        name: 'Cà phê cốt dừa đá xay',
        priceVnd: 49_000,
        originalPriceVnd: 55_000,
        prepMinutes: 6,
        soldCount: 680,
        image: 'food_coffee.png',
        description: 'Cốt dừa béo ngậy xay mịn cùng đá tuyết, rưới cà phê phin đậm đà.',
      },
      {
        section: 'Cà phê cốt dừa',
        name: 'Bạc xỉu kem muối biển',
        priceVnd: 45_000,
        prepMinutes: 6,
        soldCount: 440,
        image: 'food_tra_sua.png',
        description: 'Sữa đặc sánh quyện cà phê phin và lớp kem muối mặn dịu.',
      },
      {
        section: 'Trà & Bánh',
        name: 'Trà cam quế mật ong đá',
        priceVnd: 45_000,
        prepMinutes: 5,
        soldCount: 315,
        image: 'food_fruit_tea.png',
        description: 'Trà đen ủ quế thanh, cam tươi và mật ong rừng.',
      },
      {
        section: 'Trà & Bánh',
        name: 'Bánh sừng bò chấm sữa đặc',
        priceVnd: 32_000,
        prepMinutes: 4,
        soldCount: 295,
        image: 'food_pastries_flan.png',
        description: 'Bánh sừng bò nướng nóng giòn chấm sữa đặc Ông Thọ.',
      },
    ],
  },
  {
    key: 'dn-fastfood-crispy',
    ownerEmail: 'merchant.fastfooddn@seed.dealgo.local',
    ownerPhone: '+84907110015',
    ownerName: 'Gà Rán & Burger Crispy',
    name: 'Gà Rán & Burger Crispy — Cầu Rồng',
    category: 'fast_food',
    region: 'DN',
    lat: 16.0615,
    lng: 108.2265,
    addressLabel: '15 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
    description:
      'Gà rán giòn cay chuẩn Hàn Quốc, burger gà giòn phô mai tan chảy và pizza đế tươi nướng lò củi nóng hổi.',
    logo: 'food_fast_food_burger.png',
    cover: 'food_fast_food_burger.png',
    minOrderVnd: 35_000,
    defaultPrepMinutes: 14,
    voucher: {
      code: 'CRISPY20K',
      name: 'Giảm 20.000đ cho đơn từ 99.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 20_000,
      maxDiscountAmount: null,
      minOrderAmount: 99_000,
    },
    items: [
      {
        section: 'Combo Burger & Gà rán',
        name: 'Combo Burger Gà Giòn + Khoai tây + Coca',
        priceVnd: 69_000,
        originalPriceVnd: 85_000,
        prepMinutes: 12,
        soldCount: 540,
        image: 'food_fast_food_burger.png',
        description: '1 Burger gà giòn sốt cay, 1 phần khoai tây chiên vừa và 1 ly nước ngọt.',
        fresh: true,
      },
      {
        section: 'Combo Burger & Gà rán',
        name: 'Pizza Hải Sản Phô Mai Kéo Sợi (Cỡ M)',
        priceVnd: 119_000,
        originalPriceVnd: 145_000,
        prepMinutes: 16,
        soldCount: 380,
        image: 'food_pizza.png',
        description: 'Tôm, mực tươi, ớt chuông và phô mai Mozzarella ngập tràn.',
      },
      {
        section: 'Combo Burger & Gà rán',
        name: 'Gà rán sốt bơ tỏi Hàn Quốc (3 miếng)',
        priceVnd: 79_000,
        prepMinutes: 14,
        soldCount: 410,
        image: 'food_grilled_meat.png',
        description: 'Ba miếng gà rán vỏ giòn rụm áo sốt bơ tỏi thơm ngọt.',
      },
      {
        section: 'Món ăn nhẹ',
        name: 'Mẹt khoai tây lắc phô mai & gà viên',
        priceVnd: 45_000,
        prepMinutes: 8,
        soldCount: 325,
        image: 'food_snack_platter.png',
        description: 'Khoai tây múi cau lắc phô mai kèm gà popcorn giòn tan.',
      },
    ],
  },
  {
    key: 'dn-snack-chocon',
    ownerEmail: 'merchant.snackdn@seed.dealgo.local',
    ownerPhone: '+84907110016',
    ownerName: 'Ăn Vặt Chợ Cồn Đà Nẵng',
    name: 'Thiên Đường Ăn Vặt Chợ Cồn — Hải Châu',
    category: 'snack',
    region: 'DN',
    lat: 16.069,
    lng: 108.2145,
    addressLabel: '290 Ông Ích Khiêm, Hải Châu, Đà Nẵng',
    description:
      'Tụ điểm ăn vặt Đà Thành: mẹt cá viên chiên nước mắm, nem chua rán, ốc hút cay nồng và bánh flan rau câu dừa.',
    logo: 'food_snack_platter.png',
    cover: 'food_snack_platter.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 10,
    voucher: {
      code: 'ANVATDN10',
      name: 'Giảm 10% tối đa 20.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 10,
      maxDiscountAmount: 20_000,
      minOrderAmount: 40_000,
    },
    items: [
      {
        section: 'Mẹt ăn vặt',
        name: 'Mẹt ăn vặt thập cẩm 7 món sốt mắm tỏi',
        priceVnd: 65_000,
        originalPriceVnd: 79_000,
        prepMinutes: 10,
        soldCount: 620,
        image: 'food_snack_platter.png',
        description: 'Nem chua rán, cá viên, bò viên, hồ lô, chả ram tôm, khoai tây và đậu bắp.',
        fresh: true,
      },
      {
        section: 'Mẹt ăn vặt',
        name: 'Hải sản & Ốc hút xào sả ớt Đà Nẵng',
        priceVnd: 55_000,
        prepMinutes: 12,
        soldCount: 410,
        image: 'food_seafood.png',
        description: 'Ốc hút và nghêu xào sả ớt cay thơm, chấm bánh tráng.',
      },
      {
        section: 'Tráng miệng & Trà',
        name: 'Combo 2 Bánh flan caramel & kem dừa',
        priceVnd: 28_000,
        prepMinutes: 3,
        soldCount: 495,
        image: 'food_pastries_flan.png',
        description: 'Bánh flan trứng sữa mềm mịn rưới cà phê và cốt dừa.',
      },
      {
        section: 'Tráng miệng & Trà',
        name: 'Trà tắc xí muội khổng lồ',
        priceVnd: 20_000,
        prepMinutes: 3,
        soldCount: 580,
        image: 'food_fruit_tea.png',
        description: 'Ly 700ml trà tắc xí muội chua ngọt giải nhiệt tức thì.',
      },
    ],
  },
  {
    key: 'dn-mart-fresh',
    ownerEmail: 'merchant.martdn@seed.dealgo.local',
    ownerPhone: '+84907110017',
    ownerName: 'DealGo Fresh Mart Đà Nẵng',
    name: 'DealGo Fresh Mart — Hoàng Diệu',
    category: 'mart',
    region: 'DN',
    lat: 16.063,
    lng: 108.2195,
    addressLabel: '112 Hoàng Diệu, Hải Châu, Đà Nẵng',
    description:
      'Siêu thị thực phẩm tươi sống giao nhanh trong 20 phút: trái cây nhập khẩu, rau củ Đà Lạt VietGAP, sữa tươi và đồ uống.',
    logo: 'store_supermarket.png',
    cover: 'food_fresh_grocery.png',
    minOrderVnd: 40_000,
    defaultPrepMinutes: 8,
    voucher: {
      code: 'FRESHDN25K',
      name: 'Giảm 25.000đ cho đơn siêu thị từ 120.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 25_000,
      maxDiscountAmount: null,
      minOrderAmount: 120_000,
    },
    items: [
      {
        section: 'Trái cây & Rau củ VietGAP',
        name: 'Giỏ trái cây nhiệt đới tươi trong ngày (1.5kg)',
        priceVnd: 89_000,
        originalPriceVnd: 105_000,
        prepMinutes: 6,
        soldCount: 340,
        image: 'food_fresh_grocery.png',
        description: 'Cam vàng, táo Envy, xoài cát Hòa Lộc và chuối Laba tuyển chọn.',
        fresh: true,
      },
      {
        section: 'Trái cây & Rau củ VietGAP',
        name: 'Combo rau củ nấu canh & salad Đà Lạt',
        priceVnd: 45_000,
        prepMinutes: 5,
        soldCount: 275,
        image: 'food_fresh_grocery.png',
        description: 'Xà lách thủy canh, cà chua bi, bông cải xanh và cà rốt baby.',
      },
      {
        section: 'Thực phẩm chế biến sẵn',
        name: 'Hải sản tươi làm sạch đóng khay (500g)',
        priceVnd: 95_000,
        prepMinutes: 8,
        soldCount: 190,
        image: 'food_seafood.png',
        description: 'Tôm sú và mực ống tươi đánh bắt trong ngày, bảo quản lạnh chuẩn.',
      },
      {
        section: 'Bánh tươi & Sữa',
        name: 'Set bánh Croissant bơ & Sữa tươi thanh trùng',
        priceVnd: 55_000,
        prepMinutes: 4,
        soldCount: 230,
        image: 'food_pastries_flan.png',
        description: '2 bánh sừng bò nướng mới kèm 1 chai sữa tươi thanh trùng 500ml.',
      },
    ],
  },

  // ==================== TP. HỒ CHÍ MINH (HCM) — All 9 Categories ====================
  {
    key: 'hcm-bun-bo-nguyen-hue',
    matchName: 'Bún Bò Huế — Nguyễn Huệ',
    ownerEmail: 'merchant.bunbo@seed.dealgo.local',
    ownerPhone: '+84901110001',
    ownerName: 'Bún Bò Huế Gia Truyền',
    name: 'Bún Bò Huế — Nguyễn Huệ',
    category: 'pho',
    region: 'HCM',
    lat: 10.7738,
    lng: 106.7035,
    addressLabel: 'Đường Nguyễn Huệ, Quận 1, TP.HCM',
    description:
      'Hương vị cố đô giữa lòng Quận 1: nước dùng hầm xương bò 12 tiếng thơm nồng sả Huế, bắp bò hoa, giò heo và chả cua tươi.',
    logo: 'food_bun_bo_hue.png',
    cover: 'food_bun_bo_special.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 12,
    voucher: {
      code: 'BUNBO15K',
      name: 'Giảm 15.000đ cho đơn từ 65.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 15_000,
      maxDiscountAmount: null,
      minOrderAmount: 65_000,
    },
    items: [
      {
        section: 'Bún bò & Phở',
        name: 'Bún bò đặc biệt',
        priceVnd: 60_000,
        originalPriceVnd: 70_000,
        prepMinutes: 12,
        soldCount: 512,
        image: 'food_bun_bo_special.png',
        description: 'Nước dùng hầm xương 12 tiếng, bắp bò, giò heo và chả cua.',
      },
      {
        section: 'Bún bò & Phở',
        name: 'Bún bò tái chín',
        priceVnd: 55_000,
        prepMinutes: 10,
        soldCount: 368,
        image: 'food_bun_bo_hue.png',
        description: 'Thịt bò tái mềm, gân bò giòn sần sật, nước dùng đậm.',
      },
      {
        section: 'Bún bò & Phở',
        name: 'Bún bò giò heo',
        priceVnd: 65_000,
        prepMinutes: 12,
        soldCount: 286,
        image: 'food_pho_bo.png',
        description: 'Giò heo hầm mềm rục, béo ngậy vị sả và mắm ruốc.',
      },
      {
        section: 'Món thêm',
        name: 'Chả cua hấp',
        priceVnd: 35_000,
        prepMinutes: 8,
        soldCount: 196,
        image: 'food_seafood.png',
        description: 'Chả cua hấp chín tới, ăn kèm nước mắm gừng.',
      },
      {
        section: 'Món thêm',
        name: 'Chả ram tôm',
        priceVnd: 30_000,
        prepMinutes: 8,
        soldCount: 174,
        image: 'food_snack_platter.png',
        description: 'Chả ram chiên giòn, nhân tôm thịt, chấm tương ớt.',
      },
      {
        section: 'Nước uống',
        name: 'Trà tắc mát lạnh',
        priceVnd: 25_000,
        prepMinutes: 4,
        soldCount: 340,
        image: 'food_fruit_tea.png',
        description: 'Trà tắc pha tay, chua ngọt vừa, đá nhiều.',
      },
      {
        section: 'Nước uống',
        name: 'Nước mía lau',
        priceVnd: 20_000,
        prepMinutes: 3,
        soldCount: 232,
        image: 'food_fruit_tea.png',
        description: 'Nước mía ép tay, thêm lá dứa thơm dịu.',
      },
    ],
  },
  {
    key: 'hcm-bun-thit-nuong-ben-thanh',
    ownerEmail: 'merchant.noodleshcm@seed.dealgo.local',
    ownerPhone: '+84901110021',
    ownerName: 'Bún Thịt Nướng Bến Thành',
    name: 'Bún Thịt Nướng & Mì Quảng — Bến Thành',
    category: 'noodles',
    region: 'HCM',
    lat: 10.7725,
    lng: 106.698,
    addressLabel: '45 Lê Thánh Tôn, Quận 1, TP.HCM',
    description:
      'Bún thịt nướng chả giò kiểu Sài Gòn xưa và Mì Quảng tôm thịt đậm đà, rau sống tươi sạch kèm nước mắm kẹo chua ngọt.',
    logo: 'store_noodle_shop.png',
    cover: 'food_bun_home.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 10,
    voucher: {
      code: 'BUNSG10',
      name: 'Giảm 10% tối đa 20.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 10,
      maxDiscountAmount: 20_000,
      minOrderAmount: 50_000,
    },
    items: [
      {
        section: 'Bún & Mì đặc sắc',
        name: 'Bún thịt nướng chả giò đặc biệt',
        priceVnd: 55_000,
        originalPriceVnd: 65_000,
        prepMinutes: 10,
        soldCount: 470,
        image: 'food_bun_home.png',
        description: 'Thịt heo nướng sả, chả giò rế giòn rụm, nem nướng và đậu phộng.',
        fresh: true,
      },
      {
        section: 'Bún & Mì đặc sắc',
        name: 'Mì Quảng tôm thịt sườn non',
        priceVnd: 58_000,
        prepMinutes: 12,
        soldCount: 315,
        image: 'food_mi_quang.png',
        description: 'Sợi mì Quảng vàng óng, tôm rim, sườn non mềm và bánh đa nướng.',
      },
      {
        section: 'Món thêm & Đồ uống',
        name: 'Chả giò tôm thịt (4 cuốn)',
        priceVnd: 32_000,
        prepMinutes: 6,
        soldCount: 220,
        image: 'food_snack_platter.png',
        description: 'Chả giò chiên vàng giòn nhân tôm thịt nấm mèo.',
      },
      {
        section: 'Món thêm & Đồ uống',
        name: 'Trà đào hạt chia',
        priceVnd: 25_000,
        prepMinutes: 3,
        soldCount: 295,
        image: 'food_fruit_tea.png',
        description: 'Trà đào thanh mát kèm hạt chia tốt cho sức khỏe.',
      },
    ],
  },
  {
    key: 'hcm-com-tam-ba-ghien',
    matchName: 'Cơm Tấm Ba Ghiền — Quận 1',
    ownerEmail: 'merchant.comtam@seed.dealgo.local',
    ownerPhone: '+84905110001',
    ownerName: 'Cơm Tấm Ba Ghiền',
    name: 'Cơm Tấm Ba Ghiền — Quận 1',
    category: 'rice',
    region: 'HCM',
    lat: 10.7769,
    lng: 106.7009,
    addressLabel: '84 Đặng Văn Ngữ, Quận 1, TP.HCM',
    description:
      'Cơm tấm sườn nướng trứ danh Sài Gòn: miếng sườn cốt lết dày nướng than thơm phức, bì thính, chả trứng hấp và mỡ hành tóp mỡ.',
    logo: 'food_grilled_rice.png',
    cover: 'food_grilled_rice.png',
    minOrderVnd: 30_000,
    defaultPrepMinutes: 12,
    voucher: {
      code: 'BAGHIEN15K',
      name: 'Giảm 15.000đ cho đơn từ 70.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 15_000,
      maxDiscountAmount: null,
      minOrderAmount: 70_000,
    },
    items: [
      {
        section: 'Cơm tấm',
        name: 'Cơm sườn bì chả đặc biệt',
        priceVnd: 65_000,
        originalPriceVnd: 75_000,
        prepMinutes: 12,
        soldCount: 586,
        image: 'food_grilled_rice.png',
        description: 'Sườn nướng than, bì, chả trứng và nước mắm chua ngọt.',
      },
      {
        section: 'Cơm tấm',
        name: 'Cơm sườn ốp la',
        priceVnd: 55_000,
        prepMinutes: 10,
        soldCount: 342,
        image: 'food_grilled_meat.png',
        description: 'Sườn nướng kèm trứng ốp la và đồ chua.',
      },
      {
        section: 'Cơm tấm',
        name: 'Cơm tấm chay',
        priceVnd: 45_000,
        prepMinutes: 10,
        soldCount: 168,
        image: 'food_fresh_grocery.png',
        description: 'Sườn chay kho tiêu, bì chay và dưa leo.',
      },
      {
        section: 'Món thêm',
        name: 'Trứng ốp la',
        priceVnd: 10_000,
        prepMinutes: 3,
        soldCount: 254,
        image: 'food_pastries_flan.png',
        description: 'Một trứng gà ốp la lòng đào.',
      },
      {
        section: 'Món thêm',
        name: 'Canh rong biển thịt bằm',
        priceVnd: 20_000,
        prepMinutes: 6,
        soldCount: 226,
        image: 'food_pho_bo.png',
        description: 'Canh rong biển nấu thịt bằm, vị thanh nhẹ.',
      },
      {
        section: 'Nước uống',
        name: 'Trà đá giải nhiệt',
        priceVnd: 5_000,
        prepMinutes: 2,
        soldCount: 507,
        image: 'food_fruit_tea.png',
        description: 'Ly trà đá mát lạnh.',
      },
      {
        section: 'Nước uống',
        name: 'Sữa đậu nành',
        priceVnd: 15_000,
        prepMinutes: 2,
        soldCount: 188,
        image: 'food_tra_sua.png',
        description: 'Sữa đậu nành nấu mỗi sáng, ít ngọt.',
      },
    ],
  },
  {
    key: 'hcm-banh-mi-huynh-hoa',
    ownerEmail: 'merchant.banhmihcm@seed.dealgo.local',
    ownerPhone: '+84901110022',
    ownerName: 'Bánh Mì Sài Gòn Đặc Biệt',
    name: 'Bánh Mì Huynh Hoa — Lê Thị Riêng',
    category: 'banh_mi',
    region: 'HCM',
    lat: 10.7712,
    lng: 106.6932,
    addressLabel: '26 Lê Thị Riêng, Quận 1, TP.HCM',
    description:
      'Ổ bánh mì thập cẩm nặng tay nổi tiếng Sài Gòn: 6 lớp thịt nguội, chả lụa, dăm bông, chà bông heo, pate gan và bơ tươi.',
    logo: 'food_banh_mi.png',
    cover: 'food_banh_mi.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 7,
    voucher: {
      code: 'BMHH12K',
      name: 'Giảm 12.000đ cho đơn từ 60.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 12_000,
      maxDiscountAmount: null,
      minOrderAmount: 60_000,
    },
    items: [
      {
        section: 'Bánh mì Sài Gòn',
        name: 'Bánh mì thập cẩm đặc biệt Sài Gòn',
        priceVnd: 58_000,
        originalPriceVnd: 65_000,
        prepMinutes: 6,
        soldCount: 810,
        image: 'food_banh_mi.png',
        description: 'Ổ lớn đầy ắp chả lụa, thịt nguội, chà bông, pate và rau dưa để riêng.',
        fresh: true,
      },
      {
        section: 'Bánh mì Sài Gòn',
        name: 'Bánh mì heo quay da giòn',
        priceVnd: 42_000,
        prepMinutes: 6,
        soldCount: 465,
        image: 'food_grilled_meat.png',
        description: 'Thịt heo quay da nổ giòn rụm, nước sốt đậm đà và đồ chua.',
      },
      {
        section: 'Đồ uống',
        name: 'Cà phê sữa đá Sài Gòn',
        priceVnd: 25_000,
        prepMinutes: 3,
        soldCount: 520,
        image: 'food_coffee.png',
        description: 'Cà phê vợt Sài Gòn pha sữa đặc thơm béo.',
      },
    ],
  },
  {
    key: 'hcm-phuc-long-thao-dien',
    matchName: 'Trà Sữa Phúc Long — Thảo Điền',
    ownerEmail: 'merchant.phuclong@seed.dealgo.local',
    ownerPhone: '+84906110001',
    ownerName: 'Trà Sữa Phúc Long',
    name: 'Trà Sữa Phúc Long — Thảo Điền',
    category: 'tea',
    region: 'HCM',
    lat: 10.8032,
    lng: 106.7328,
    addressLabel: 'Thảo Điền, TP. Thủ Đức, TP.HCM',
    description:
      'Thương hiệu trà và trà sữa đậm vị từ cao nguyên Bảo Lộc: Trà đào cam sả, Trà sữa Phúc Long truyền thống và Trà ô long sữa.',
    logo: 'store_coffee_shop.png',
    cover: 'food_tra_sua.png',
    minOrderVnd: 35_000,
    defaultPrepMinutes: 10,
    voucher: {
      code: 'PHUCLONG15',
      name: 'Giảm 15% tối đa 25.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 15,
      maxDiscountAmount: 25_000,
      minOrderAmount: 70_000,
    },
    items: [
      {
        section: 'Trà sữa',
        name: 'Trà sữa Phúc Long truyền thống',
        priceVnd: 50_000,
        prepMinutes: 8,
        soldCount: 712,
        image: 'food_tra_sua.png',
        description: 'Trà đen ủ mới, sữa béo, trân châu dai mềm.',
      },
      {
        section: 'Trà sữa',
        name: 'Trà sữa ô long',
        priceVnd: 55_000,
        prepMinutes: 8,
        soldCount: 424,
        image: 'food_coffee.png',
        description: 'Ô long rang nhẹ, sữa tươi, thạch trắng.',
      },
      {
        section: 'Trà trái cây',
        name: 'Trà đào đá xay',
        priceVnd: 60_000,
        originalPriceVnd: 68_000,
        prepMinutes: 9,
        soldCount: 386,
        image: 'food_fruit_tea.png',
        description: 'Trà đào xay đá, topping miếng đào ngâm.',
      },
      {
        section: 'Trà trái cây',
        name: 'Trà lài sen vàng',
        priceVnd: 55_000,
        prepMinutes: 8,
        soldCount: 252,
        image: 'food_fruit_tea.png',
        description: 'Trà lài ướp sen, hậu vị thanh mát.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh sừng bò nướng',
        priceVnd: 35_000,
        prepMinutes: 5,
        soldCount: 194,
        image: 'food_pastries_flan.png',
        description: 'Bánh sừng bò bơ Pháp, nướng giòn mỗi sáng.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh flan phô mai',
        priceVnd: 30_000,
        prepMinutes: 3,
        soldCount: 236,
        image: 'food_pastries_flan.png',
        description: 'Flan phô mai béo mịn, caramel cháy nhẹ.',
      },
    ],
  },
  {
    key: 'hcm-ca-phe-sai-gon-bitexco',
    matchName: 'Cà Phê Sài Gòn — Bitexco',
    ownerEmail: 'merchant.coffee@seed.dealgo.local',
    ownerPhone: '+84904000001',
    ownerName: 'Cà Phê Sài Gòn',
    name: 'Cà Phê Sài Gòn — Bitexco',
    category: 'cafe',
    region: 'HCM',
    lat: 10.7717,
    lng: 106.7043,
    addressLabel: 'Tòa Bitexco, Hải Triều, Quận 1, TP.HCM',
    description:
      'Cà phê rang mộc nguyên chất giữa trung tâm tài chính Quận 1: Cà phê sữa đá, Cà phê muối, Cold Brew ủ lạnh 18 giờ và bánh nướng.',
    logo: 'food_coffee.png',
    cover: 'food_coffee.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 6,
    voucher: {
      code: 'CAFESG10K',
      name: 'Giảm 10.000đ cho đơn từ 50.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 10_000,
      maxDiscountAmount: null,
      minOrderAmount: 50_000,
    },
    items: [
      {
        section: 'Cà phê',
        name: 'Cà phê sữa đá',
        priceVnd: 35_000,
        prepMinutes: 5,
        soldCount: 624,
        image: 'food_coffee.png',
        description: 'Robusta rang mộc, sữa đặc, đá viên lớn.',
      },
      {
        section: 'Cà phê',
        name: 'Cà phê muối',
        priceVnd: 45_000,
        prepMinutes: 6,
        soldCount: 418,
        image: 'food_tra_sua.png',
        description: 'Cà phê phin, kem muối béo mặn, lớp cà phê đậm.',
      },
      {
        section: 'Cà phê',
        name: 'Bạc xỉu ba tầng',
        priceVnd: 40_000,
        originalPriceVnd: 48_000,
        prepMinutes: 6,
        soldCount: 387,
        image: 'food_coffee.png',
        description: 'Ba lớp sữa - cà phê - bọt sữa mịn.',
      },
      {
        section: 'Cold brew',
        name: 'Cold brew cam sả',
        priceVnd: 55_000,
        prepMinutes: 4,
        soldCount: 248,
        image: 'food_fruit_tea.png',
        description: 'Cold brew ủ lạnh 18 giờ, cam vàng và sả tươi.',
      },
      {
        section: 'Cold brew',
        name: 'Cold brew nước dừa',
        priceVnd: 55_000,
        prepMinutes: 4,
        soldCount: 232,
        image: 'food_fruit_tea.png',
        description: 'Cold brew nguyên chất kết hợp nước dừa xiêm.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh mì ốp la xúc xích',
        priceVnd: 45_000,
        prepMinutes: 8,
        soldCount: 310,
        image: 'food_banh_mi.png',
        description: 'Bánh mì nướng giòn, 2 trứng ốp la và xúc xích.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh sừng bò bơ',
        priceVnd: 35_000,
        prepMinutes: 3,
        soldCount: 218,
        image: 'food_pastries_flan.png',
        description: 'Croissant bơ Pháp, vỏ giòn nhiều lớp.',
      },
      {
        section: 'Bánh ngọt',
        name: 'Bánh flan trứng',
        priceVnd: 25_000,
        prepMinutes: 2,
        soldCount: 196,
        image: 'food_pastries_flan.png',
        description: 'Flan trứng mềm mịn, caramel đắng nhẹ.',
      },
    ],
  },
  {
    key: 'hcm-burger-pizza-artisan',
    ownerEmail: 'merchant.fastfoodhcm@seed.dealgo.local',
    ownerPhone: '+84901110023',
    ownerName: 'Burger & Pizza Artisan',
    name: 'Burger & Pizza Artisan — Nguyễn Trãi',
    category: 'fast_food',
    region: 'HCM',
    lat: 10.7695,
    lng: 106.6915,
    addressLabel: '128 Nguyễn Trãi, Quận 1, TP.HCM',
    description:
      'Burger bò Mỹ nướng lửa hồng, gà rán giòn cay và Pizza phô mai tươi nướng lò thủ công chuẩn vị Âu Mỹ.',
    logo: 'food_fast_food_burger.png',
    cover: 'food_fast_food_burger.png',
    minOrderVnd: 40_000,
    defaultPrepMinutes: 14,
    voucher: {
      code: 'ARTISAN25K',
      name: 'Giảm 25.000đ cho đơn từ 110.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 25_000,
      maxDiscountAmount: null,
      minOrderAmount: 110_000,
    },
    items: [
      {
        section: 'Burger & Pizza',
        name: 'Combo Burger Gà Giòn Phô Mai + Khoai Tây',
        priceVnd: 75_000,
        originalPriceVnd: 92_000,
        prepMinutes: 12,
        soldCount: 495,
        image: 'food_fast_food_burger.png',
        description: 'Burger ức gà giòn nguyên miếng, phô mai Cheddar, khoai tây chiên và Coca.',
        fresh: true,
      },
      {
        section: 'Burger & Pizza',
        name: 'Pizza Pepperoni & Phô Mai Mozzarella',
        priceVnd: 125_000,
        prepMinutes: 15,
        soldCount: 360,
        image: 'food_pizza.png',
        description: 'Đế bánh men tươi giòn xốp, xúc xích Pepperoni cay nhẹ và phô mai kéo sợi.',
      },
      {
        section: 'Gà rán',
        name: 'Cánh gà nướng mật ong BBQ (6 miếng)',
        priceVnd: 69_000,
        prepMinutes: 12,
        soldCount: 310,
        image: 'food_grilled_meat.png',
        description: 'Cánh gà ướp sốt BBQ mật ong nướng vàng óng.',
      },
    ],
  },
  {
    key: 'hcm-snack-ho-con-rua',
    ownerEmail: 'merchant.snackhcm@seed.dealgo.local',
    ownerPhone: '+84901110024',
    ownerName: 'Bếp Ăn Vặt Hồ Con Rùa',
    name: 'Bếp Ăn Vặt Sài Gòn — Hồ Con Rùa',
    category: 'snack',
    region: 'HCM',
    lat: 10.7826,
    lng: 106.6959,
    addressLabel: 'Công trường Quốc Tế, Quận 3, TP.HCM',
    description:
      'Thiên đường ăn vặt Hồ Con Rùa: bánh tráng trộn, mẹt xiên que chiên giòn sốt bơ tỏi, bắp xào tép và trà trái cây.',
    logo: 'food_snack_platter.png',
    cover: 'food_snack_platter.png',
    minOrderVnd: 0,
    defaultPrepMinutes: 9,
    voucher: {
      code: 'ANVATSG10',
      name: 'Giảm 10% tối đa 20.000đ',
      discountType: 'PERCENTAGE',
      discountValue: 10,
      maxDiscountAmount: 20_000,
      minOrderAmount: 45_000,
    },
    items: [
      {
        section: 'Mẹt chiên & Ăn vặt',
        name: 'Mẹt xiên que chiên bơ tỏi Sài Gòn (8 món)',
        priceVnd: 69_000,
        originalPriceVnd: 85_000,
        prepMinutes: 9,
        soldCount: 645,
        image: 'food_snack_platter.png',
        description: 'Cá viên, bò viên, tôm cuộn khoai tây, phô mai que, xúc xích và đồ chua.',
        fresh: true,
      },
      {
        section: 'Mẹt chiên & Ăn vặt',
        name: 'Hải sản xào bơ tỏi chấm bánh mì',
        priceVnd: 59_000,
        prepMinutes: 10,
        soldCount: 380,
        image: 'food_seafood.png',
        description: 'Tôm, mực và nghêu xào sốt bơ tỏi béo thơm kèm bánh mì giòn.',
      },
      {
        section: 'Đồ ngọt & Trà',
        name: 'Trà đào cam sả nhiệt đới (Size L)',
        priceVnd: 32_000,
        prepMinutes: 4,
        soldCount: 510,
        image: 'food_fruit_tea.png',
        description: 'Trà đào tươi mát lạnh kèm 4 miếng đào giòn.',
      },
    ],
  },
  {
    key: 'hcm-coop-fresh-mart',
    ownerEmail: 'merchant.marthcm@seed.dealgo.local',
    ownerPhone: '+84901110025',
    ownerName: 'Sài Gòn Fresh Mart',
    name: 'Sài Gòn Fresh Mart — Quận 1',
    category: 'mart',
    region: 'HCM',
    lat: 10.7752,
    lng: 106.7018,
    addressLabel: '168 Nguyễn Đình Chiểu, Quận 1, TP.HCM',
    description:
      'Đi chợ hộ siêu tốc Quận 1: rau củ hữu cơ, trái cây tươi nhập khẩu, thịt cá sơ chế sạch và sữa tươi mỗi ngày.',
    logo: 'store_supermarket.png',
    cover: 'food_fresh_grocery.png',
    minOrderVnd: 50_000,
    defaultPrepMinutes: 10,
    voucher: {
      code: 'MARTSG30K',
      name: 'Giảm 30.000đ cho đơn siêu thị từ 150.000đ',
      discountType: 'FIXED_AMOUNT',
      discountValue: 30_000,
      maxDiscountAmount: null,
      minOrderAmount: 150_000,
    },
    items: [
      {
        section: 'Trái cây & Rau hữu cơ',
        name: 'Box Trái Cây Tươi Vitamin C (1.5kg)',
        priceVnd: 95_000,
        originalPriceVnd: 115_000,
        prepMinutes: 6,
        soldCount: 410,
        image: 'food_fresh_grocery.png',
        description: 'Cam Úc, táo đỏ, kiwi vàng và nho xanh không hạt tươi ngọt.',
        fresh: true,
      },
      {
        section: 'Trái cây & Rau hữu cơ',
        name: 'Combo Rau Sạch Đà Lạt Trong Ngày (1kg)',
        priceVnd: 49_000,
        prepMinutes: 5,
        soldCount: 330,
        image: 'food_fresh_grocery.png',
        description: 'Cải ngọt, xà lách, cà chua, dưa leo và hành ngò chuẩn VietGAP.',
      },
      {
        section: 'Hải sản & Bánh sữa',
        name: 'Khay Tôm Sú & Mực Ống Tươi Sạch (500g)',
        priceVnd: 99_000,
        prepMinutes: 8,
        soldCount: 215,
        image: 'food_seafood.png',
        description: 'Làm sạch sẵn, đóng khay hút chân không tiện lợi.',
      },
    ],
  },
];

const DRIVERS = [
  {
    phone: '+84908880001',
    name: 'Nguyễn Văn Hùng',
    cls: 'MOTORBIKE',
    vehicle: 'Honda Vision 110cc',
    plate: '43-D1 123.45',
    lat: 16.0678,
    lng: 108.2208,
    region: 'DN',
  },
  {
    phone: '+84908880002',
    name: 'Phạm Minh Tuấn',
    cls: 'MOTORBIKE',
    vehicle: 'Yamaha Exciter 155',
    plate: '43-E1 567.89',
    lat: 16.0605,
    lng: 108.2241,
    region: 'DN',
  },
  {
    phone: '+84908880003',
    name: 'Trần Quốc Việt',
    cls: 'CAR_4',
    vehicle: 'Toyota Vios (4 chỗ)',
    plate: '43A-678.90',
    lat: 16.0712,
    lng: 108.2179,
    region: 'DN',
  },
  {
    phone: '+84908880004',
    name: 'Lê Hoàng Nam',
    cls: 'CAR_7',
    vehicle: 'Mitsubishi Xpander (7 chỗ)',
    plate: '43A-246.80',
    lat: 16.0551,
    lng: 108.2163,
    region: 'DN',
  },
  {
    phone: '+84908880005',
    name: 'Đặng Quốc Khánh',
    cls: 'CAR_4',
    vehicle: 'Hyundai Accent (4 chỗ)',
    plate: '51K-345.67',
    lat: 10.7745,
    lng: 106.7015,
    region: 'HCM',
  },
  {
    phone: '+84908880006',
    name: 'Võ Thành Đạt',
    cls: 'CAR_7',
    vehicle: 'Toyota Innova Cross (7 chỗ)',
    plate: '51K-889.99',
    lat: 10.772,
    lng: 106.6985,
    region: 'HCM',
  },
] as const;

const CUSTOMER_PHONE = '+84909990101';

const REVIEW_TEMPLATES = [
  {
    stars: 5,
    tags: ['TASTY_FOOD', 'WELL_PACKED', 'ON_TIME'],
    comment: 'Đồ ăn rất ngon, nóng hổi và đóng gói cực kỳ cẩn thận. Sẽ ủng hộ quán dài lâu!',
    reply: 'Cảm ơn bạn rất nhiều! Quán rất vui vì bạn hài lòng, hẹn gặp lại bạn ở đơn sau nhé.',
  },
  {
    stars: 5,
    tags: ['TASTY_FOOD', 'FRIENDLY'],
    comment: 'Chuẩn vị, phần ăn đầy đặn, anh tài xế giao hàng siêu nhiệt tình và đúng giờ.',
    reply: null,
  },
  {
    stars: 4,
    tags: ['TASTY_FOOD', 'WELL_PACKED'],
    comment: 'Món ăn vừa miệng, nguyên liệu tươi ngon. Đóng gói sạch sẽ.',
    reply: 'Dạ quán cảm ơn góp ý của bạn ạ!',
  },
] as const;

function resolveAssetPath(file: string, fallback?: string): string {
  const candidates = [
    resolve(BATCH02_DIR, file),
    resolve(BATCH01_DIR, file),
    resolve(MOBILE_IMG_DIR, file),
    ...(fallback
      ? [
          resolve(BATCH02_DIR, fallback),
          resolve(BATCH01_DIR, fallback),
          resolve(MOBILE_IMG_DIR, fallback),
        ]
      : []),
  ];
  const found = candidates.find((p) => existsSync(p));
  if (!found) {
    throw new Error(`Missing seed asset file: ${file} (tried ${candidates.join(', ')})`);
  }
  return found;
}

async function ensureUserByPhoneOrEmail(
  db: PrismaClient,
  input: { phone?: string; email?: string; displayName: string },
): Promise<string> {
  const now = new Date();
  if (input.email) {
    const byEmail = await db.user.findUnique({ where: { email: input.email } });
    if (byEmail) {
      await db.user.update({
        where: { id: byEmail.id },
        data: {
          displayName: input.displayName,
          emailVerifiedAt: byEmail.emailVerifiedAt ?? now,
          ...(input.phone && !byEmail.phone ? { phone: input.phone, phoneVerifiedAt: now } : {}),
        },
      });
      return byEmail.id;
    }
  }
  if (input.phone) {
    const byPhone = await db.user.findUnique({ where: { phone: input.phone } });
    if (byPhone) {
      await db.user.update({
        where: { id: byPhone.id },
        data: {
          displayName: input.displayName,
          phoneVerifiedAt: byPhone.phoneVerifiedAt ?? now,
          ...(input.email && !byPhone.email ? { email: input.email, emailVerifiedAt: now } : {}),
        },
      });
      return byPhone.id;
    }
  }
  const created = await db.user.create({
    data: {
      email: input.email ?? null,
      phone: input.phone ?? null,
      displayName: input.displayName,
      emailVerifiedAt: input.email ? now : null,
      phoneVerifiedAt: input.phone ? now : null,
    },
  });
  return created.id;
}

async function cleanupTestPollution(
  db: PrismaClient,
  keepStoreIds: ReadonlySet<string>,
  keepUserEmails: ReadonlySet<string>,
  keepUserPhones: ReadonlySet<string>,
): Promise<{ removedStores: number; removedUsers: number; removedPromos: number }> {
  // 1. Identify garbage stores (any store not in keepStoreIds and not DealGo Demo Đà Nẵng)
  const allStores = await db.foodStore.findMany({
    select: { id: true, name: true, ownerId: true },
  });
  const garbageStoreIds = allStores
    .filter((s) => !keepStoreIds.has(s.id) && s.name !== 'DealGo Demo Đà Nẵng')
    .map((s) => s.id);

  if (garbageStoreIds.length > 0) {
    const garbageOrders = await db.foodOrder.findMany({
      where: { storeId: { in: garbageStoreIds } },
      select: { id: true },
    });
    const orderIds = garbageOrders.map((o) => o.id);
    if (orderIds.length > 0) {
      await db.serviceRating.deleteMany({
        where: { subjectType: 'FOOD_ORDER', subjectId: { in: orderIds } },
      });
      await db.promotionRedemption.deleteMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: orderIds } },
      });
      await db.jobEarning.deleteMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: orderIds } },
      });
      await db.paymentSelection.deleteMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: orderIds } },
      });
      const intents = await db.paymentIntent.findMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: orderIds } },
        select: { id: true },
      });
      if (intents.length > 0) {
        await db.paymentRefund.deleteMany({
          where: { paymentIntentId: { in: intents.map((i) => i.id) } },
        });
        await db.paymentIntent.deleteMany({
          where: { id: { in: intents.map((i) => i.id) } },
        });
      }
      await db.foodOrder.deleteMany({ where: { id: { in: orderIds } } });
    }
    const storePromos = await db.promotion.findMany({
      where: { storeId: { in: garbageStoreIds } },
      select: { id: true },
    });
    if (storePromos.length > 0) {
      await db.promotionRedemption.deleteMany({
        where: { promotionId: { in: storePromos.map((p) => p.id) } },
      });
      await db.promotion.deleteMany({
        where: { id: { in: storePromos.map((p) => p.id) } },
      });
    }
    await db.serviceRating.deleteMany({
      where: { storeId: { in: garbageStoreIds } },
    });
    await db.foodStore.deleteMany({
      where: { id: { in: garbageStoreIds } },
    });
  }

  // 2. Clean up E2E test promotions (keep real platform & store codes)
  const keepPromoCodes = new Set([
    'DEALGO20K',
    'DEALGOFOOD15',
    'DEALGORIDE30',
    'HOAN30K',
    'CUOITUAN50',
    'DEMODN10',
    'DEMODN15K',
    'DEMODN20',
    ...SHOWCASE_STORES.map((s) => s.voucher.code),
  ]);
  const garbagePromos = await db.promotion.findMany({
    where: {
      code: { notIn: [...keepPromoCodes] },
      OR: [{ storeId: null }, { storeId: { notIn: [...keepStoreIds] } }],
    },
    select: { id: true },
  });
  if (garbagePromos.length > 0) {
    const promoIds = garbagePromos.map((p) => p.id);
    await db.promotionRedemption.deleteMany({
      where: { promotionId: { in: promoIds } },
    });
    await db.promotion.deleteMany({
      where: { id: { in: promoIds } },
    });
  }

  // 3. Clean up perf/E2E test users that have no kept stores and are not in keep sets
  const keptStoreOwners = new Set(
    (await db.foodStore.findMany({ select: { ownerId: true } })).map((s) => s.ownerId),
  );
  const allUsers = await db.user.findMany({
    select: { id: true, email: true, phone: true },
  });
  const garbageUserIds = allUsers
    .filter((u) => {
      if (keptStoreOwners.has(u.id)) return false;
      if (u.email && keepUserEmails.has(u.email.toLowerCase())) return false;
      if (u.email && u.email.startsWith('appreview-customer-')) return false;
      if (u.email && u.email.endsWith('@seed.dealgo.local')) return false;
      if (u.phone && keepUserPhones.has(u.phone)) return false;
      return true;
    })
    .map((u) => u.id);

  if (garbageUserIds.length > 0) {
    // Delete rides and food orders involving garbage users first
    const gRides = await db.ride.findMany({
      where: {
        OR: [
          { customerId: { in: garbageUserIds } },
          { assignedDriverId: { in: garbageUserIds } },
        ],
      },
      select: { id: true },
    });
    if (gRides.length > 0) {
      const rIds = gRides.map((r) => r.id);
      await db.ride.updateMany({
        where: { id: { in: rIds } },
        data: { selectedOfferId: null },
      });
      await db.serviceRating.deleteMany({
        where: { subjectType: 'RIDE', subjectId: { in: rIds } },
      });
      await db.customerRating.deleteMany({
        where: { rideId: { in: rIds } },
      });
      await db.promotionRedemption.deleteMany({
        where: { entityType: 'RIDE', entityId: { in: rIds } },
      });
      await db.jobEarning.deleteMany({
        where: { entityType: 'RIDE', entityId: { in: rIds } },
      });
      await db.rideSelection.deleteMany({
        where: { rideId: { in: rIds } },
      });
      await db.rideOffer.deleteMany({
        where: { rideId: { in: rIds } },
      });
      await db.ride.deleteMany({
        where: { id: { in: rIds } },
      });
    }
    await db.rideOffer.deleteMany({
      where: { driverId: { in: garbageUserIds } },
    });
    await db.rideSelection.deleteMany({
      where: { customerId: { in: garbageUserIds } },
    });
    const gOrders = await db.foodOrder.findMany({
      where: {
        OR: [
          { customerId: { in: garbageUserIds } },
          { assignedDriverId: { in: garbageUserIds } },
        ],
      },
      select: { id: true },
    });
    if (gOrders.length > 0) {
      const oIds = gOrders.map((o) => o.id);
      await db.serviceRating.deleteMany({
        where: { subjectType: 'FOOD_ORDER', subjectId: { in: oIds } },
      });
      await db.promotionRedemption.deleteMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: oIds } },
      });
      await db.jobEarning.deleteMany({
        where: { entityType: 'FOOD_ORDER', entityId: { in: oIds } },
      });
      await db.foodOrder.deleteMany({
        where: { id: { in: oIds } },
      });
    }
    await db.chatMessage.deleteMany({
      where: { senderUserId: { in: garbageUserIds } },
    });
    await db.jobEarning.deleteMany({
      where: { driverId: { in: garbageUserIds } },
    });
    await db.driverFeeSettlement.deleteMany({
      where: {
        OR: [
          { driverId: { in: garbageUserIds } },
          { actorUserId: { in: garbageUserIds } },
        ],
      },
    });
    await db.driverCreditApplication.deleteMany({
      where: { driverId: { in: garbageUserIds } },
    });
    await db.driverTopUp.deleteMany({
      where: { driverId: { in: garbageUserIds } },
    });
    await db.opsAuditLog.deleteMany({
      where: { actorUserId: { in: garbageUserIds } },
    });
    await db.promotionRedemption.deleteMany({
      where: { userId: { in: garbageUserIds } },
    });
    await db.user.deleteMany({
      where: { id: { in: garbageUserIds } },
    });
  }

  return {
    removedStores: garbageStoreIds.length,
    removedUsers: garbageUserIds.length,
    removedPromos: garbagePromos.length,
  };
}

async function main(): Promise<void> {
  loadDotEnv();
  const url = process.env.DATABASE_URL?.trim() || 'postgresql://localhost:5432/dealgo';
  assertDevDatabase(url, process.env.NODE_ENV);
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: url }) });
  const storage = createObjectStorage(process.env as any);
  const counts = {
    categories: 0,
    vehicles: 0,
    banners: 0,
    stores: 0,
    logos: 0,
    covers: 0,
    itemImages: 0,
    vouchers: 0,
    avatars: 0,
    uploaded: 0,
    drivers: 0,
    rides: 0,
    foodOrders: 0,
    ratings: 0,
  };
  const storedKeys = new Map<string, string>();

  async function put(key: string, file: string, fallback?: string): Promise<string> {
    const known = storedKeys.get(key);
    if (known) return known;
    const webpKey = key.replace(/\.(png|jpe?g)$/i, '.webp');
    const existing = await storage.get(webpKey).catch(() => null);
    if (existing) {
      storedKeys.set(key, webpKey);
      return webpKey;
    }
    const fullPath = resolveAssetPath(file, fallback);
    const source = readFileSync(fullPath);
    const normalized = await toPublicWebp(source);
    const storedKey = normalized ? webpKey : key;
    const contentType = normalized
      ? 'image/webp'
      : fullPath.endsWith('.jpg') || fullPath.endsWith('.jpeg')
        ? 'image/jpeg'
        : 'image/png';
    await storage.put(storedKey, normalized?.body ?? source, contentType);
    if (normalized) {
      for (const width of PUBLIC_IMAGE_VARIANT_WIDTHS) {
        if (normalized.width <= width) continue;
        const variantKey = imageVariantKey(storedKey, width);
        const variant = variantKey ? await toVariantWebp(normalized.body, width) : null;
        if (variantKey && variant) {
          await storage.put(variantKey, variant, 'image/webp');
        }
      }
    }
    counts.uploaded += 1;
    storedKeys.set(key, storedKey);
    return storedKey;
  }

  try {
    const now = new Date();

    // -------------------------------------------------------------------------
    // 1. Food Categories (all 9 with square artwork in ObjectStorage)
    // -------------------------------------------------------------------------
    const categoryDefaults = [
      { code: 'pho', nameVi: 'Phở', nameEn: 'Pho', icon: 'soup', tone: 'orange', sortOrder: 0 },
      { code: 'noodles', nameVi: 'Bún, mì', nameEn: 'Noodles', icon: 'cooking-pot', tone: 'amber', sortOrder: 10 },
      { code: 'rice', nameVi: 'Cơm', nameEn: 'Rice', icon: 'utensils', tone: 'red', sortOrder: 20 },
      { code: 'banh_mi', nameVi: 'Bánh mì', nameEn: 'Banh mi', icon: 'sandwich', tone: 'brown', sortOrder: 30 },
      { code: 'tea', nameVi: 'Trà sữa', nameEn: 'Milk tea', icon: 'cup-soda', tone: 'pink', sortOrder: 40 },
      { code: 'cafe', nameVi: 'Cà phê', nameEn: 'Coffee', icon: 'coffee', tone: 'blue', sortOrder: 50 },
      { code: 'fast_food', nameVi: 'Ăn nhanh', nameEn: 'Fast food', icon: 'hamburger', tone: 'green', sortOrder: 60 },
      { code: 'snack', nameVi: 'Ăn vặt', nameEn: 'Snacks', icon: 'popcorn', tone: 'purple', sortOrder: 70 },
      { code: 'mart', nameVi: 'Siêu thị', nameEn: 'Grocery', icon: 'shopping-cart', tone: 'indigo', sortOrder: 80 },
    ] as const;

    for (const cat of categoryDefaults) {
      const spec = CATEGORY_IMAGES[cat.code]!;
      const fileUuid = stableUuid('food-category-img', cat.code, spec.file);
      const key = `food-categories/${cat.code}/${fileUuid}.png`;
      const storedKey = await put(key, spec.file, spec.fallback);
      const imageUrl = foodCategoryImagePath(cat.code, storedKey);
      await db.foodCategory.upsert({
        where: { code: cat.code },
        create: { ...cat, imageUrl, active: true },
        update: {
          nameVi: cat.nameVi,
          nameEn: cat.nameEn,
          icon: cat.icon,
          tone: cat.tone,
          sortOrder: cat.sortOrder,
          imageUrl,
          active: true,
        },
      });
      counts.categories += 1;
    }

    // -------------------------------------------------------------------------
    // 2. Ride Vehicle Classes (MOTORBIKE, CAR_4, CAR_7 with artwork in ObjectStorage)
    // -------------------------------------------------------------------------
    for (const [code, spec] of Object.entries(VEHICLE_IMAGES)) {
      const vc = await db.rideVehicleClass.findUnique({ where: { code } });
      if (!vc) continue;
      const fileUuid = stableUuid('vehicle-class-img', code, spec.file);
      const key = `ride-vehicle-classes/${code}/${fileUuid}.png`;
      const storedKey = await put(key, spec.file, spec.fallback);
      const imageUrl = rideVehicleClassImagePath(code, storedKey);
      await db.rideVehicleClass.update({
        where: { code },
        data: { imageUrl, enabled: true, parcelEnabled: true },
      });
      counts.vehicles += 1;
    }

    // -------------------------------------------------------------------------
    // 3. Home Banners (active & backed by ObjectStorage for Customer/Driver/Merchant)
    // -------------------------------------------------------------------------
    const bannerSpecs = [
      {
        id: '779a8898-3414-463f-a09c-5b9a9eef986e',
        file: 'banner_ride_dealgo.png',
        fallback: 'banner_ride_dealgo.png',
        ctaUrl: '/customer/book',
        audiences: ['CUSTOMER'] as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[],
        service: 'RIDE' as const,
        sortOrder: 0,
      },
      {
        id: '5b83bb66-a362-4a36-9812-c1a66ed69a0a',
        file: 'banner_food_dealgo.png',
        fallback: 'banner_food_dealgo.png',
        ctaUrl: '/customer/shop',
        audiences: ['CUSTOMER'] as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[],
        service: 'FOOD' as const,
        sortOrder: 10,
      },
      {
        id: '1341e246-1efd-4e61-ad61-52bda6ded683',
        file: 'banner_promo_dealgo.png',
        fallback: 'banner_promo_dealgo.png',
        ctaUrl: '/customer/account/vouchers',
        audiences: ['CUSTOMER'] as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[],
        service: 'ALL' as const,
        sortOrder: 20,
      },
      {
        id: stableUuid('home-banner', 'driver-main'),
        file: 'banner_driver_dealgo.png',
        fallback: 'banner_driver_dealgo.png',
        ctaUrl: '/driver/earnings',
        audiences: ['DRIVER'] as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[],
        service: 'ALL' as const,
        sortOrder: 30,
      },
      {
        id: stableUuid('home-banner', 'merchant-main'),
        file: 'banner_merchant_dealgo.png',
        fallback: 'banner_merchant_dealgo.png',
        ctaUrl: '/merchant/orders',
        audiences: ['MERCHANT'] as ('CUSTOMER' | 'DRIVER' | 'MERCHANT')[],
        service: 'FOOD' as const,
        sortOrder: 40,
      },
    ];

    for (const b of bannerSpecs) {
      const fileUuid = stableUuid('banner-img', b.id, b.file);
      const key = `home-banners/${b.id}/${fileUuid}.png`;
      const storedKey = await put(key, b.file, b.fallback);
      const imageUrl = homeBannerImagePath(b.id, storedKey);
      await db.homeBanner.upsert({
        where: { id: b.id },
        create: {
          id: b.id,
          imageUrl,
          ctaUrl: b.ctaUrl,
          audiences: b.audiences,
          service: b.service,
          regionCode: null,
          startsAt: null,
          endsAt: null,
          sortOrder: b.sortOrder,
          active: true,
        },
        update: {
          imageUrl,
          ctaUrl: b.ctaUrl,
          audiences: b.audiences,
          service: b.service,
          regionCode: null,
          startsAt: null,
          endsAt: null,
          sortOrder: b.sortOrder,
          active: true,
        },
      });
      counts.banners += 1;
    }

    // Also ensure DealGo Demo Đà Nẵng (if present from seed:app-review) has its images in ObjectStorage
    const appReviewStore = await db.foodStore.findFirst({
      where: { name: 'DealGo Demo Đà Nẵng' },
      include: { items: true },
    });
    if (appReviewStore) {
      const logoKey = `store-logos/${appReviewStore.id}/${stableUuid('logo', appReviewStore.id, 'store_noodle_shop.png')}.png`;
      const coverKey = `store-covers/${appReviewStore.id}/${stableUuid('cover', appReviewStore.id, 'hero_food_clean.png')}.png`;
      const storedLogoKey = await put(logoKey, 'store_noodle_shop.png');
      const storedCoverKey = await put(coverKey, 'hero_food_clean.png');
      await db.foodStore.update({
        where: { id: appReviewStore.id },
        data: {
          logoUrl: storeLogoPath(appReviewStore.id, storedLogoKey, 'logo'),
          coverUrl: storeLogoPath(appReviewStore.id, storedCoverKey, 'cover'),
        },
      });
      for (const it of appReviewStore.items) {
        const img = it.name.toLowerCase().includes('cà phê')
          ? 'food_coffee.png'
          : it.name.toLowerCase().includes('trà sữa')
            ? 'food_tra_sua.png'
            : it.name.toLowerCase().includes('bánh mì')
              ? 'food_banh_mi.png'
              : it.name.toLowerCase().includes('cơm')
                ? 'food_grilled_meat.png'
                : it.name.toLowerCase().includes('bún bò')
                  ? 'food_bun_bo_special.png'
                  : 'food_mi_quang.png';
        const iKey = `menu-items/${it.id}/${stableUuid('item', it.id, img)}.png`;
        const storedIKey = await put(iKey, img);
        const iPath = menuItemImagePath(it.id, storedIKey);
        await db.foodItem.update({
          where: { id: it.id },
          data: { imageUrl: iPath, imageUrls: [iPath], moderationStatus: 'APPROVED', available: true },
        });
      }
    }

    // -------------------------------------------------------------------------
    // 4. Showcase Stores, Menus, Option Groups, Vouchers & Images (18 stores)
    // -------------------------------------------------------------------------
    const storeIds: Record<string, string> = {};
    const keptStoreIdSet = new Set<string>();
    if (appReviewStore) keptStoreIdSet.add(appReviewStore.id);

    for (const spec of SHOWCASE_STORES) {
      const ownerId = await ensureUserByPhoneOrEmail(db, {
        email: spec.ownerEmail,
        phone: spec.ownerPhone,
        displayName: spec.ownerName,
      });
      for (const role of ['CUSTOMER', 'MERCHANT'] as const) {
        await db.roleGrant.upsert({
          where: { userId_role: { userId: ownerId, role } },
          create: { userId: ownerId, role, status: 'ACTIVE' },
          update: { status: 'ACTIVE' },
        });
      }

      // Match existing store by matchName, name, or ownerId
      let store =
        (spec.matchName
          ? await db.foodStore.findFirst({ where: { name: spec.matchName } })
          : null) ??
        (await db.foodStore.findFirst({ where: { name: spec.name } })) ??
        (await db.foodStore.findFirst({ where: { ownerId }, orderBy: { createdAt: 'asc' } }));

      const storeId = store?.id ?? stableUuid('store', spec.key);
      const logoKey = `store-logos/${storeId}/${stableUuid('logo', storeId, spec.logo)}.png`;
      const coverKey = `store-covers/${storeId}/${stableUuid('cover', storeId, spec.cover)}.png`;
      const storedLogoKey = await put(logoKey, spec.logo, 'store_noodle_shop.png');
      const storedCoverKey = await put(coverKey, spec.cover, 'hero_food_clean.png');

      const storePayload = {
        ownerId,
        name: spec.name,
        category: spec.category,
        lat: spec.lat,
        lng: spec.lng,
        serviceRegionCode: spec.region,
        addressLabel: spec.addressLabel,
        description: spec.description,
        logoUrl: storeLogoPath(storeId, storedLogoKey, 'logo'),
        coverUrl: storeLogoPath(storeId, storedCoverKey, 'cover'),
        serviceMode: 'OPEN' as const,
        serviceModeUntil: null,
        hoursConfigured: true,
        lastOrderMinutes: 0,
        defaultPrepMinutes: spec.defaultPrepMinutes,
        minOrderVnd: spec.minOrderVnd,
      };

      store = await db.foodStore.upsert({
        where: { id: storeId },
        create: { id: storeId, ...storePayload },
        update: storePayload,
      });

      keptStoreIdSet.add(store.id);
      storeIds[spec.name] = store.id;
      counts.stores += 1;
      counts.logos += 1;
      counts.covers += 1;

      // 24/7 weekly hours so every store is open at any time of day
      for (let weekday = 1; weekday <= 7; weekday += 1) {
        await db.foodStoreHour.upsert({
          where: { storeId_weekday: { storeId: store.id, weekday } },
          create: { storeId: store.id, weekday, opensMinute: 0, closesMinute: 1440 },
          update: { opensMinute: 0, closesMinute: 1440 },
        });
      }

      // Menu categories
      const sectionNames = [...new Set(spec.items.map((i) => i.section))];
      const sectionIdMap = new Map<string, string>();
      for (const [idx, secName] of sectionNames.entries()) {
        const existingCat = await db.foodMenuCategory.findFirst({
          where: { storeId: store.id, name: secName },
        });
        const catId = existingCat?.id ?? stableUuid('menu-cat', store.id, secName);
        await db.foodMenuCategory.upsert({
          where: { id: catId },
          create: { id: catId, storeId: store.id, name: secName, position: idx },
          update: { name: secName, position: idx },
        });
        sectionIdMap.set(secName, catId);
      }

      // Menu items + images + option groups
      const touchedItemIds: string[] = [];
      for (const it of spec.items) {
        const existingItem = await db.foodItem.findFirst({
          where: { storeId: store.id, name: it.name },
        });
        const itemId = existingItem?.id ?? stableUuid('item', store.id, it.name);
        touchedItemIds.push(itemId);
        const itemKey = `menu-items/${itemId}/${stableUuid('item-img', itemId, it.image)}.png`;
        const storedItemKey = await put(itemKey, it.image, 'food_mi_quang.png');
        const imgPath = menuItemImagePath(itemId, storedItemKey);

        const itemData = {
          storeId: store.id,
          menuCategoryId: sectionIdMap.get(it.section) ?? null,
          name: it.name,
          description: it.description,
          priceVnd: it.priceVnd,
          originalPriceVnd: it.originalPriceVnd ?? null,
          prepMinutes: it.prepMinutes,
          soldCount: Math.max(existingItem?.soldCount ?? 0, it.soldCount),
          imageUrl: imgPath,
          imageUrls: [imgPath],
          available: true,
          moderationStatus: 'APPROVED' as const,
          createdAt: new Date(now.getTime() - (it.fresh ? 1 : 45) * DAY_MS),
        };
        await db.foodItem.upsert({
          where: { id: itemId },
          create: { id: itemId, ...itemData },
          update: itemData,
        });
        counts.itemImages += 1;

        // Ensure option group on main items if none exists
        const groupCount = await db.foodOptionGroup.count({ where: { itemId } });
        if (groupCount === 0) {
          const gId = stableUuid('opt-group', itemId, 'size');
          await db.foodOptionGroup.create({
            data: {
              id: gId,
              itemId,
              name: 'Chọn cỡ phần ăn',
              minSelect: 1,
              maxSelect: 1,
              position: 0,
              options: {
                create: [
                  {
                    id: stableUuid('opt', gId, 'regular'),
                    name: 'Cỡ tiêu chuẩn',
                    priceDeltaVnd: 0,
                    position: 0,
                  },
                  {
                    id: stableUuid('opt', gId, 'large'),
                    name: 'Cỡ đặc biệt (+thêm nhân)',
                    priceDeltaVnd: 15_000,
                    position: 1,
                  },
                ],
              },
            },
          });
        }
      }

      // Remove obsolete duplicate/test items on this store that are not part of its curated menu
      await db.foodItem.deleteMany({
        where: { storeId: store.id, id: { notIn: touchedItemIds } },
      });

      // Store voucher (merchant-funded)
      const v = spec.voucher;
      const perUseCap = v.discountType === 'FIXED_AMOUNT' ? v.discountValue : (v.maxDiscountAmount ?? 25_000);
      const promoData = {
        name: v.name,
        description: `Ưu đãi trực tiếp tại ${spec.name}`,
        serviceType: 'FOOD' as const,
        discountType: v.discountType,
        discountValue: v.discountValue,
        maxDiscountAmount: v.maxDiscountAmount,
        minOrderAmount: v.minOrderAmount,
        totalBudget: perUseCap * 200,
        usageLimit: 200,
        userLimit: 3,
        targetAudience: 'CUSTOMER' as const,
        status: 'ACTIVE' as const,
        startDate: new Date(now.getTime() - 2 * DAY_MS),
        endDate: new Date(now.getTime() + 120 * DAY_MS),
        sponsor: 'MERCHANT' as const,
        storeId: store.id,
      };
      await db.promotion.upsert({
        where: { code: v.code },
        create: { id: stableUuid('promo', v.code), code: v.code, ...promoData },
        update: promoData,
      });
      counts.vouchers += 1;
    }

    // -------------------------------------------------------------------------
    // 5. Drivers (MOTORBIKE, CAR_4, CAR_7 in DN & HCM)
    // -------------------------------------------------------------------------
    const driverIds: string[] = [];
    for (const d of DRIVERS) {
      const id = await ensureUserByPhoneOrEmail(db, {
        phone: d.phone,
        displayName: d.name,
      });
      driverIds.push(id);
      for (const role of ['CUSTOMER', 'DRIVER'] as const) {
        await db.roleGrant.upsert({
          where: { userId_role: { userId: id, role } },
          create: { userId: id, role, status: 'ACTIVE' },
          update: { status: 'ACTIVE' },
        });
      }
      const metadata = {
        vehicleType: d.vehicle,
        vehicleClassCode: d.cls,
        plateNumber: d.plate,
        city: d.region === 'DN' ? 'Đà Nẵng' : 'TP. Hồ Chí Minh',
        seed: 'dev-showcase',
      };
      await db.partnerApplication.upsert({
        where: { userId_role: { userId: id, role: 'DRIVER' } },
        create: {
          userId: id,
          role: 'DRIVER',
          status: 'APPROVED',
          metadata,
          submittedAt: now,
          reviewedAt: now,
        },
        update: { status: 'APPROVED', metadata },
      });
      await db.driverPresence.upsert({
        where: { userId: id },
        create: {
          userId: id,
          online: true,
          parcelEnabled: true,
          lat: d.lat,
          lng: d.lng,
          locationAt: now,
          serviceRegionCode: d.region,
        },
        update: {
          online: true,
          parcelEnabled: true,
          lat: d.lat,
          lng: d.lng,
          locationAt: now,
          serviceRegionCode: d.region,
        },
      });
      counts.drivers += 1;
    }

    // -------------------------------------------------------------------------
    // 6. Delivered Food Orders + Store Ratings for EVERY Store
    // -------------------------------------------------------------------------
    const reviewerAccounts = [
      { email: 'customer.an@seed.dealgo.local', phone: '+84902000001', name: 'Nguyễn Văn An' },
      { email: 'customer.binh@seed.dealgo.local', phone: '+84902000002', name: 'Trần Thị Bình' },
      { email: 'customer.chi@seed.dealgo.local', phone: '+84902000003', name: 'Lê Minh Chi' },
    ];
    const reviewerIds: string[] = [];
    for (const rev of reviewerAccounts) {
      const rId = await ensureUserByPhoneOrEmail(db, {
        email: rev.email,
        phone: rev.phone,
        displayName: rev.name,
      });
      await db.roleGrant.upsert({
        where: { userId_role: { userId: rId, role: 'CUSTOMER' } },
        create: { userId: rId, role: 'CUSTOMER', status: 'ACTIVE' },
        update: { status: 'ACTIVE' },
      });
      reviewerIds.push(rId);
    }

    const setting = async (key: string, fallback: number): Promise<number> => {
      const val = Number((await db.platformSetting.findUnique({ where: { key } }))?.value ?? NaN);
      return Number.isFinite(val) ? val : fallback;
    };
    const [minD, maxD, perKm] = await Promise.all([
      setting('FOOD_MIN_DELIVERY_VND', 15_000),
      setting('FOOD_MAX_DELIVERY_VND', 60_000),
      setting('FOOD_DELIVERY_VND_PER_KM', 5_000),
    ]);

    for (const spec of SHOWCASE_STORES) {
      const storeId = storeIds[spec.name]!;
      const storeItems = await db.foodItem.findMany({
        where: { storeId },
        take: 3,
        orderBy: { priceVnd: 'desc' },
      });
      if (storeItems.length === 0) continue;

      for (const [rIdx, tpl] of REVIEW_TEMPLATES.entries()) {
        const raterId = reviewerIds[rIdx % reviewerIds.length]!;
        const driverId = driverIds[rIdx % driverIds.length]!;
        const idempotencyKey = `showcase-v2:${spec.key}:review-${rIdx + 1}`;
        const orderId = stableUuid('order', idempotencyKey);
        const daysAgo = 2 + rIdx * 3;
        const at = new Date(now.getTime() - daysAgo * DAY_MS);
        const dropoff =
          spec.region === 'DN'
            ? { lat: 16.0655 + rIdx * 0.002, lng: 108.2218 - rIdx * 0.002, label: '25 Trần Phú, Hải Châu, Đà Nẵng' }
            : { lat: 10.7755 + rIdx * 0.002, lng: 106.7012 - rIdx * 0.002, label: '72 Lê Thánh Tôn, Quận 1, TP.HCM' };
        const km = haversineKm({ lat: spec.lat, lng: spec.lng }, dropoff);
        const deliveryFareVnd = Math.min(maxD, Math.max(minD, Math.round(km * perKm)));
        const chosenItems = storeItems.slice(0, 2);
        const lines = chosenItems.map((it, idx) => ({
          id: stableUuid('order-line', orderId, String(idx)),
          itemId: it.id,
          name: it.name,
          unitPriceVnd: it.priceVnd,
          quantity: idx === 0 ? 2 : 1,
          imageUrl: it.imageUrl,
        }));
        const subtotalVnd = lines.reduce((sum, l) => sum + l.unitPriceVnd * l.quantity, 0);

        const orderPayload = {
          customerId: raterId,
          storeId,
          status: 'DELIVERED' as const,
          deliveryFareVnd,
          subtotalVnd,
          totalVnd: subtotalVnd + deliveryFareVnd,
          dropoffLat: dropoff.lat,
          dropoffLng: dropoff.lng,
          dropoffLabel: dropoff.label,
          pickupLat: spec.lat,
          pickupLng: spec.lng,
          pickupLabel: spec.addressLabel,
          serviceRegionCode: spec.region,
          assignedDriverId: driverId,
          prepMinutes: spec.defaultPrepMinutes,
          acceptedAt: new Date(at.getTime() + 60_000),
          readyAt: new Date(at.getTime() + 12 * 60_000),
          pickedUpAt: new Date(at.getTime() + 15 * 60_000),
          merchantCashVnd: subtotalVnd,
          createdAt: at,
        };

        await db.foodOrder.upsert({
          where: { customerId_idempotencyKey: { customerId: raterId, idempotencyKey } },
          create: { id: orderId, idempotencyKey, ...orderPayload },
          update: orderPayload,
        });
        const actualOrder = await db.foodOrder.findUniqueOrThrow({
          where: { customerId_idempotencyKey: { customerId: raterId, idempotencyKey } },
          select: { id: true },
        });
        await db.foodOrderLine.deleteMany({ where: { orderId: actualOrder.id } });
        await db.foodOrderLine.createMany({
          data: lines.map((l, idx) => ({
            ...l,
            id: stableUuid('order-line', actualOrder.id, String(idx)),
            orderId: actualOrder.id,
          })),
        });
        counts.foodOrders += 1;

        await db.serviceRating.upsert({
          where: {
            subjectType_subjectId: { subjectType: 'FOOD_ORDER', subjectId: actualOrder.id },
          },
          create: {
            id: stableUuid('rating', actualOrder.id),
            subjectType: 'FOOD_ORDER',
            subjectId: actualOrder.id,
            raterId,
            storeId,
            driverId,
            storeStars: tpl.stars,
            driverStars: 5,
            tags: [...tpl.tags],
            comment: tpl.comment,
            merchantReply: tpl.reply,
            repliedAt: tpl.reply ? new Date(at.getTime() + 3600_000) : null,
            createdAt: new Date(at.getTime() + 1800_000),
          },
          update: {
            storeStars: tpl.stars,
            driverStars: 5,
            tags: [...tpl.tags],
            comment: tpl.comment,
            merchantReply: tpl.reply,
            repliedAt: tpl.reply ? new Date(at.getTime() + 3600_000) : null,
            hiddenAt: null,
            hiddenReason: null,
          },
        });
        counts.ratings += 1;
      }
    }

    // -------------------------------------------------------------------------
    // 7. Customer Showcase History (+84909990101 & tien@gmail.com)
    // -------------------------------------------------------------------------
    const showcaseCustomerId = await ensureUserByPhoneOrEmail(db, {
      phone: CUSTOMER_PHONE,
      displayName: 'Khách DealGo',
    });
    await db.roleGrant.upsert({
      where: { userId_role: { userId: showcaseCustomerId, role: 'CUSTOMER' } },
      create: { userId: showcaseCustomerId, role: 'CUSTOMER', status: 'ACTIVE' },
      update: { status: 'ACTIVE' },
    });

    const tienUser = await db.user.findUnique({ where: { email: 'tien@gmail.com' } });
    const targetCustomerIds = [showcaseCustomerId, ...(tienUser ? [tienUser.id] : [])];
    const classes = new Map((await db.rideVehicleClass.findMany()).map((c) => [c.code, c]));

    for (const cId of targetCustomerIds) {
      // Saved addresses (HOME & WORK)
      const existingAddrs = await db.savedAddress.findMany({ where: { userId: cId } });
      if (existingAddrs.length === 0) {
        await db.savedAddress.createMany({
          data: [
            {
              id: stableUuid('saved-addr', cId, 'home'),
              userId: cId,
              kind: 'HOME',
              label: 'Nhà riêng',
              addressLine: '25 Trần Phú, Phường Thạch Thang, Quận Hải Châu, Đà Nẵng',
              note: 'Gần trung tâm hành chính Đà Nẵng',
              lat: 16.0765,
              lng: 108.2228,
              isDefault: true,
            },
            {
              id: stableUuid('saved-addr', cId, 'work'),
              userId: cId,
              kind: 'WORK',
              label: 'Văn phòng',
              addressLine: '96 Bạch Đằng, Quận Hải Châu, Đà Nẵng',
              note: 'Tầng 5 tòa nhà ven sông Hàn',
              lat: 16.0702,
              lng: 108.2244,
              isDefault: false,
            },
            {
              id: stableUuid('saved-addr', cId, 'other-hcm'),
              userId: cId,
              kind: 'OTHER',
              label: 'Chi nhánh Sài Gòn',
              addressLine: '68 Nguyễn Huệ, Quận 1, TP. Hồ Chí Minh',
              note: 'Phố đi bộ Nguyễn Huệ',
              lat: 10.7738,
              lng: 106.7035,
              isDefault: false,
            },
          ],
        });
      }

      // Place search history
      const places = [
        {
          placeKey: 'cau_rong_hai_chau_dn',
          name: 'Cầu Rồng Đà Nẵng',
          address: 'Đường Nguyễn Văn Linh, Phước Ninh, Hải Châu, Đà Nẵng',
          lat: 16.0611,
          lng: 108.2275,
          useCount: 5,
        },
        {
          placeKey: 'san_bay_quoc_te_da_nang',
          name: 'Sân bay Quốc tế Đà Nẵng',
          address: 'Hòa Thuận Tây, Hải Châu, Đà Nẵng',
          lat: 16.0544,
          lng: 108.2022,
          useCount: 4,
        },
        {
          placeKey: 'bai_bien_my_khe_dn',
          name: 'Bãi biển Mỹ Khê',
          address: 'Võ Nguyên Giáp, Phước Mỹ, Sơn Trà, Đà Nẵng',
          lat: 16.0598,
          lng: 108.2465,
          useCount: 3,
        },
        {
          placeKey: 'cho_ben_thanh_q1_hcm',
          name: 'Chợ Bến Thành',
          address: 'Lê Lợi, Phường Bến Thành, Quận 1, TP. Hồ Chí Minh',
          lat: 10.7725,
          lng: 106.698,
          useCount: 3,
        },
      ];
      for (const p of places) {
        await db.placeSearchHistory.upsert({
          where: { userId_placeKey: { userId: cId, placeKey: p.placeKey } },
          create: { userId: cId, ...p, lastUsedAt: now },
          update: { ...p, lastUsedAt: now },
        });
      }

      // In-app notifications
      const notifs = [
        {
          sourceEventKey: `showcase:notif:${cId}:welcome-promo`,
          category: 'PROMOTION',
          title: 'Ưu đãi DealGo Food giảm đến 30.000đ hôm nay',
          body: 'Nhập mã DEALGO20K hoặc chọn voucher trực tiếp tại các quán Mì Quảng Bà Mua, Phở Bò Gia Truyền, Cơm Tấm Ba Ghiền.',
        },
        {
          sourceEventKey: `showcase:notif:${cId}:ride-complete`,
          category: 'RIDE',
          title: 'Chuyến xe Cầu Rồng → Sân bay Đà Nẵng đã hoàn tất',
          body: 'Cảm ơn bạn đã di chuyển cùng tài xế Nguyễn Văn Hùng. Chúc bạn một ngày tốt lành!',
        },
        {
          sourceEventKey: `showcase:notif:${cId}:food-delivered`,
          category: 'FOOD',
          title: 'Đơn hàng Mì Quảng Bà Mua đã giao thành công',
          body: 'Chúc bạn ngon miệng! Đừng quên đánh giá món ăn để nhận thêm ưu đãi từ DealGo.',
        },
      ];
      for (const n of notifs) {
        await db.userNotification.upsert({
          where: { userId_sourceEventKey: { userId: cId, sourceEventKey: n.sourceEventKey } },
          create: { userId: cId, ...n },
          update: { title: n.title, body: n.body },
        });
      }

      // Completed rides
      const rides = [
        {
          key: `showcase-ride-1:${cId}`,
          cls: 'MOTORBIKE',
          driver: driverIds[0]!,
          days: 1,
          stars: 5,
          tags: ['Đúng giờ', 'Thân thiện'],
          comment: 'Anh tài xế chạy cẩn thận, nhiệt tình.',
          pickup: { lat: 16.0678, lng: 108.2208, label: 'Cầu Rồng, Hải Châu, Đà Nẵng' },
          dropoff: { lat: 16.0544, lng: 108.2022, label: 'Sân bay Quốc tế Đà Nẵng' },
          region: 'DN',
        },
        {
          key: `showcase-ride-2:${cId}`,
          cls: 'CAR_4',
          driver: driverIds[2]!,
          days: 3,
          stars: 5,
          tags: ['Xe sạch', 'Lịch sự'],
          comment: 'Xe 4 chỗ mát mẻ, sạch sẽ.',
          pickup: { lat: 16.0471, lng: 108.2468, label: 'Bãi biển Mỹ Khê, Đà Nẵng' },
          dropoff: { lat: 16.0717, lng: 108.2236, label: 'Chợ Hàn, Hải Châu, Đà Nẵng' },
          region: 'DN',
        },
        {
          key: `showcase-ride-3:${cId}`,
          cls: 'CAR_7',
          driver: driverIds[3]!,
          days: 5,
          stars: 5,
          tags: ['Đúng giờ', 'Xe rộng'],
          comment: null,
          pickup: { lat: 16.0605, lng: 108.2241, label: 'Vincom Plaza Ngô Quyền, Đà Nẵng' },
          dropoff: { lat: 16.0743, lng: 108.15, label: 'ĐH Bách Khoa Đà Nẵng' },
          region: 'DN',
        },
      ];
      for (const r of rides) {
        const vc = classes.get(r.cls);
        if (!vc) continue;
        const fare = quoteVehicleClassFare({
          distanceKm: haversineKm(r.pickup, r.dropoff),
          vehicle: vc,
        }).referenceFareVnd;
        const at = new Date(now.getTime() - r.days * DAY_MS);
        const data = {
          status: 'COMPLETED' as const,
          vehicleClassCode: r.cls,
          assignedDriverId: r.driver,
          pickupLat: r.pickup.lat,
          pickupLng: r.pickup.lng,
          pickupLabel: r.pickup.label,
          dropoffLat: r.dropoff.lat,
          dropoffLng: r.dropoff.lng,
          dropoffLabel: r.dropoff.label,
          offeredFareVnd: fare,
          referenceFareVnd: fare,
          agreedFareVnd: fare,
          expiresAt: at,
          serviceRegionCode: r.region,
        };
        const ride = await db.ride.upsert({
          where: { customerId_idempotencyKey: { customerId: cId, idempotencyKey: r.key } },
          create: { customerId: cId, idempotencyKey: r.key, ...data, createdAt: at },
          update: data,
        });
        counts.rides += 1;
        await db.serviceRating.upsert({
          where: { subjectType_subjectId: { subjectType: 'RIDE', subjectId: ride.id } },
          create: {
            subjectType: 'RIDE',
            subjectId: ride.id,
            raterId: cId,
            driverId: r.driver,
            driverStars: r.stars,
            tags: r.tags,
            comment: r.comment,
            createdAt: at,
          },
          update: { driverStars: r.stars, tags: r.tags, comment: r.comment },
        });
        counts.ratings += 1;
      }

      // Delivered food orders for customer history
      const custOrders = [
        {
          key: `showcase-food-1:${cId}`,
          store: 'Mì Quảng Bà Mua — Hải Châu Đà Nẵng',
          days: 1,
          stars: 5,
          tags: ['TASTY_FOOD', 'WELL_PACKED'],
          comment: 'Mì Quảng chuẩn vị, bánh tráng giòn rụm.',
        },
        {
          key: `showcase-food-2:${cId}`,
          store: 'Quán Cơm Nhà Làm — Hải Châu',
          days: 3,
          stars: 5,
          tags: ['TASTY_FOOD', 'ON_TIME'],
          comment: 'Cơm gà xối mỡ nóng giòn, giao nhanh.',
        },
        {
          key: `showcase-food-3:${cId}`,
          store: 'Cộng Cà Phê — Bạch Đằng Đà Nẵng',
          days: 5,
          stars: 5,
          tags: ['TASTY_FOOD'],
          comment: 'Cà phê cốt dừa béo thơm.',
        },
      ];
      for (const o of custOrders) {
        const sId = storeIds[o.store];
        if (!sId) continue;
        const store = await db.foodStore.findUniqueOrThrow({
          where: { id: sId },
          include: { items: { take: 2, orderBy: { soldCount: 'desc' } } },
        });
        const dropoff = {
          lat: 16.0688,
          lng: 108.2225,
          label: '25 Trần Phú, Hải Châu, Đà Nẵng',
        };
        const km =
          store.lat != null && store.lng != null
            ? haversineKm({ lat: store.lat, lng: store.lng }, dropoff)
            : 1.5;
        const deliveryFareVnd = Math.min(maxD, Math.max(minD, Math.round(km * perKm)));
        const lines = store.items.map((it, i) => ({
          itemId: it.id,
          name: it.name,
          unitPriceVnd: it.priceVnd,
          quantity: i === 0 ? 2 : 1,
          imageUrl: it.imageUrl,
        }));
        const subtotalVnd = lines.reduce((s, l) => s + l.unitPriceVnd * l.quantity, 0);
        const at = new Date(now.getTime() - o.days * DAY_MS);
        const data = {
          storeId: sId,
          status: 'DELIVERED' as const,
          deliveryFareVnd,
          subtotalVnd,
          totalVnd: subtotalVnd + deliveryFareVnd,
          dropoffLat: dropoff.lat,
          dropoffLng: dropoff.lng,
          dropoffLabel: dropoff.label,
          pickupLat: store.lat,
          pickupLng: store.lng,
          pickupLabel: store.addressLabel,
          serviceRegionCode: 'DN',
          assignedDriverId: driverIds[0]!,
        };
        const existing = await db.foodOrder.findUnique({
          where: { customerId_idempotencyKey: { customerId: cId, idempotencyKey: o.key } },
        });
        let orderId: string;
        if (existing) {
          await db.foodOrderLine.deleteMany({ where: { orderId: existing.id } });
          await db.foodOrder.update({
            where: { id: existing.id },
            data: { ...data, lines: { create: lines } },
          });
          orderId = existing.id;
        } else {
          orderId = (
            await db.foodOrder.create({
              data: {
                customerId: cId,
                idempotencyKey: o.key,
                ...data,
                createdAt: at,
                lines: { create: lines },
              },
            })
          ).id;
        }
        counts.foodOrders += 1;
        await db.serviceRating.upsert({
          where: { subjectType_subjectId: { subjectType: 'FOOD_ORDER', subjectId: orderId } },
          create: {
            subjectType: 'FOOD_ORDER',
            subjectId: orderId,
            raterId: cId,
            storeId: sId,
            storeStars: o.stars,
            driverId: driverIds[0]!,
            driverStars: 5,
            tags: o.tags,
            comment: o.comment,
            createdAt: at,
          },
          update: { storeStars: o.stars, tags: o.tags, comment: o.comment },
        });
        counts.ratings += 1;
      }
    }

    // -------------------------------------------------------------------------
    // 8. Clean up E2E / Perf Test Garbage from Dev DB
    // -------------------------------------------------------------------------
    const keepUserEmails = new Set<string>([
      'tien@gmail.com',
      'ops@localhost',
      'minh@dealgo.vn',
      'appreview@dealgo.laptrinhapp.com',
      'appreview@dealgo.trancongtien.com',
      ...SHOWCASE_STORES.map((s) => s.ownerEmail.toLowerCase()),
    ]);
    const keepUserPhones = new Set<string>([
      CUSTOMER_PHONE,
      '+84909990011',
      '+84908000001',
      '+84908000002',
      '+84908000003',
      '+84908000004',
      '+84908000005',
      '+84908000006',
      '+84902000001',
      '+84902000002',
      '+84902000003',
      '+84902000004',
      '+84902000005',
      '+84902000006',
      '+84902000007',
      '+84903000001',
      '+84903000002',
      '+84903000003',
      '+84903000004',
      '+84903000005',
      '+84903000006',
      '+84905000001',
      '+84905000002',
      '+84905000003',
      '+84905000004',
      ...DRIVERS.map((d) => d.phone),
      ...SHOWCASE_STORES.map((s) => s.ownerPhone),
    ]);

    const cleaned = await cleanupTestPollution(
      db,
      keptStoreIdSet,
      keepUserEmails,
      keepUserPhones,
    );

    // -------------------------------------------------------------------------
    // 9. Ensure Avatars for Remaining Real Users
    // -------------------------------------------------------------------------
    const remainingUsers = await db.user.findMany({
      include: { roleGrants: { select: { role: true } } },
    });
    for (const u of remainingUsers) {
      // Preserve tien@gmail.com's existing custom avatar if it exists in storage
      if (u.avatarUrl) {
        const key = `avatars/${u.avatarUrl.slice('/v1/public/avatars/'.length)}`;
        const found = await storage.get(key).catch(() => null);
        if (found) continue;
      }
      const roles = new Set(u.roleGrants.map((g) => g.role));
      const avatarFile = roles.has('DRIVER')
        ? 'role_driver_3d.png'
        : roles.has('MERCHANT')
          ? 'role_merchant_3d.png'
          : 'role_customer_3d.png';
      const fileUuid = stableUuid('avatar', u.id, avatarFile);
      const key = `avatars/${u.id}/${fileUuid}.png`;
      const storedKey = await put(key, avatarFile, 'role_customer.png');
      await db.user.update({
        where: { id: u.id },
        data: { avatarUrl: avatarPath(storedKey) },
      });
      counts.avatars += 1;
    }

    console.log(
      JSON.stringify(
        {
          seed: 'dev-showcase-v2',
          storage: storage.provider,
          cleaned,
          ...counts,
        },
        null,
        2,
      ),
    );
  } finally {
    await db.$disconnect();
  }
}

if (process.argv[1]?.endsWith('seed-dev-showcase.ts')) {
  main().catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  });
}
