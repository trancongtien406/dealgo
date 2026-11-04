import '../../features/food/domain/entities/food_models.dart';
import '../../features/ride/domain/entities/ride_models.dart';
import '../../features/ride/domain/params/create_ride_params.dart';
import '../../features/ride/domain/params/select_ride_offer_params.dart';
import '../../features/ride/domain/params/submit_ride_offer_params.dart';
import 'fake_food_client.dart';
import 'fake_identity_client.dart';
import 'fake_ride_client.dart';
import 'mock_order_lines.dart';
import 'food_option_groups.dart';

const mockStoreBunBo = 'store-bun-bo';
const mockStoreMart = 'store-coopmart';
const mockItemBun = 'item-bun';
const mockItemTra = 'item-tra';
const mockItemCom = 'item-com';

class MockClients {
  const MockClients({
    required this.identity,
    required this.ride,
    required this.food,
  });

  final FakeIdentityClient identity;
  final FakeRideClient ride;
  final FakeFoodClient food;
}

MockClients createSeededMockClients() {
  final identity = FakeIdentityClient(profile: demoMultiRoleProfile);
  final ride = FakeRideClient()
    ..openRides = mockOpenRides
    ..onCreate = _createRide
    ..onGet = _getRide
    ..onSelect = _selectOffer
    ..onOffer = _submitOffer
    ..onCancel = _cancelRide;
  final food = FakeFoodClient(
    stores: mockFoodStores,
    details: mockFoodDetails,
    queueOrders: mockMerchantQueue,
    readyOrders: mockReadyFoodJobs,
    placedOrder: mockPlacedOrder,
    claimed: const ClaimedFoodDelivery(id: 'food-ready-1', status: 'ASSIGNED'),
    orderDetail: mockActiveFoodOrder,
  )..onGetOrder = _mockFoodOrderDetail;
  return MockClients(identity: identity, ride: ride, food: food);
}

FoodOrderDetail _mockFoodOrderDetail(String orderId) {
  for (final order in mockMerchantQueue) {
    if (order.id == orderId) {
      return FoodOrderDetail(
        id: order.id,
        status: order.status,
        subtotalVnd: order.subtotalVnd,
        deliveryFareVnd: order.deliveryFareVnd,
        totalVnd: order.totalVnd,
        dropoff: order.dropoff,
        lines: mockOrderLinesForQueue(order),
      );
    }
  }
  if (orderId == mockActiveFoodOrder.id || orderId == 'food-ready-1') {
    return FoodOrderDetail(
      id: orderId,
      status: mockActiveFoodOrder.status,
      subtotalVnd: mockActiveFoodOrder.subtotalVnd,
      deliveryFareVnd: mockActiveFoodOrder.deliveryFareVnd,
      totalVnd: mockActiveFoodOrder.totalVnd,
      dropoff: mockActiveFoodOrder.dropoff,
      lines: mockActiveFoodOrder.lines,
    );
  }
  return FoodOrderDetail(
    id: orderId,
    status: mockActiveFoodOrder.status,
    subtotalVnd: mockActiveFoodOrder.subtotalVnd,
    deliveryFareVnd: mockActiveFoodOrder.deliveryFareVnd,
    totalVnd: mockActiveFoodOrder.totalVnd,
    dropoff: mockActiveFoodOrder.dropoff,
    lines: mockActiveFoodOrder.lines,
  );
}

const mockFoodStores = <FoodStoreSummary>[
  FoodStoreSummary(
    id: mockStoreBunBo,
    name: 'Bún Bò Huế Ô Cồ',
    category: 'noodles',
    distanceKm: 1.2,
    etaMinutes: 25,
    deliveryFeeFromVnd: 12000,
    ratingAverage: 4.8,
    ratingCount: 214,
    minOrderVnd: 30000,
  ),
  FoodStoreSummary(
    id: mockStoreMart,
    name: 'Co.opmart Đà Nẵng',
    category: 'mart',
    distanceKm: 2.4,
    etaMinutes: 35,
    deliveryFeeFromVnd: 18000,
    ratingAverage: 4.6,
    ratingCount: 96,
    minOrderVnd: 50000,
  ),
];

const mockFoodDetails = <String, FoodStoreDetail>{
  mockStoreBunBo: FoodStoreDetail(
    id: mockStoreBunBo,
    name: 'Bún Bò Huế Ô Cồ',
    category: 'noodles',
    addressLabel: '12 Nguyễn Chí Thanh, Hải Châu, Đà Nẵng',
    estimatedPrepMinutes: 15,
    minOrderVnd: 30000,
    deliveryFeeFromVnd: 12000,
    menuSections: [
      FoodMenuSection(id: 'sec-bun', name: 'Món chính'),
      FoodMenuSection(id: 'sec-drink', name: 'Đồ uống'),
      FoodMenuSection(id: 'sec-side', name: 'Món thêm'),
    ],
    items: [
      FoodMenuItem(
        id: mockItemBun,
        name: 'Bún bò đặc biệt',
        priceVnd: 45000,
        originalPriceVnd: 55000,
        available: true,
        description:
            'Nước dùng hầm xương 12 tiếng, bắp bò, giò heo và chả cua.',
        prepMinutes: 12,
        soldCount: 128,
        menuCategoryId: 'sec-bun',
        optionGroups: mockBunOptionGroups,
      ),
      FoodMenuItem(
        id: mockItemTra,
        name: 'Trà đá',
        priceVnd: 5000,
        available: true,
        description: 'Ly trà đá mát lạnh, pha từ trà xanh Đà Lạt.',
        prepMinutes: 2,
        soldCount: 342,
        menuCategoryId: 'sec-drink',
      ),
      FoodMenuItem(
        id: 'item-tra-tac',
        name: 'Trà tắc',
        priceVnd: 15000,
        available: true,
        description: 'Trà tắc chua ngọt, thêm sả và đá nhiều.',
        prepMinutes: 4,
        soldCount: 186,
        menuCategoryId: 'sec-drink',
      ),
      FoodMenuItem(
        id: 'item-nuoc-mia',
        name: 'Nước mía lá dứa',
        priceVnd: 12000,
        available: true,
        description: 'Nước mía ép tay, thơm mùi lá dứa.',
        prepMinutes: 3,
        soldCount: 210,
        menuCategoryId: 'sec-drink',
      ),
      FoodMenuItem(
        id: mockItemCom,
        name: 'Cơm thêm',
        priceVnd: 10000,
        available: false,
        description: 'Chén cơm trắng dẻo, ăn kèm cùng bún bò.',
        prepMinutes: 3,
        soldCount: 64,
        menuCategoryId: 'sec-side',
      ),
      FoodMenuItem(
        id: 'item-cha-cua',
        name: 'Chả cua hấp',
        priceVnd: 20000,
        available: true,
        description: 'Chả cua hấp chín tới, chấm nước mắm gừng.',
        prepMinutes: 8,
        soldCount: 142,
        menuCategoryId: 'sec-side',
      ),
      FoodMenuItem(
        id: 'item-bun-tai',
        name: 'Bún bò tái chín',
        priceVnd: 42000,
        available: true,
        description: 'Bò tái mềm, gân giòn, nước dùng đậm đà.',
        prepMinutes: 12,
        soldCount: 264,
        menuCategoryId: 'sec-bun',
      ),
      FoodMenuItem(
        id: 'item-bun-gio',
        name: 'Bún bò giò heo',
        priceVnd: 48000,
        available: true,
        description: 'Giò heo hầm mềm, béo ngậy vị sả.',
        prepMinutes: 14,
        soldCount: 198,
        menuCategoryId: 'sec-bun',
      ),
    ],
  ),
  mockStoreMart: FoodStoreDetail(
    id: mockStoreMart,
    name: 'Co.opmart Đà Nẵng',
    category: 'mart',
    addressLabel: '255 Hùng Vương, Thanh Khê, Đà Nẵng',
    estimatedPrepMinutes: 10,
    minOrderVnd: 50000,
    deliveryFeeFromVnd: 18000,
    menuSections: [
      FoodMenuSection(id: 'sec-drink', name: 'Đồ uống'),
      FoodMenuSection(id: 'sec-dry', name: 'Thực phẩm khô'),
    ],
    items: [
      FoodMenuItem(
        id: 'item-sua',
        name: 'Sữa tươi Vinamilk',
        priceVnd: 32000,
        originalPriceVnd: 38000,
        available: true,
        description: 'Sữa tươi nguyên chất 100%, hộp 1 lít.',
        soldCount: 210,
        menuCategoryId: 'sec-drink',
      ),
      FoodMenuItem(
        id: 'item-mi',
        name: 'Mì gói Hảo Hảo',
        priceVnd: 4500,
        available: true,
        description: 'Mì ăn liền vị tôm chua cay, gói 75g.',
        soldCount: 485,
        menuCategoryId: 'sec-dry',
      ),
    ],
  ),
};

const mockMerchantQueue = <MerchantQueueOrder>[
  MerchantQueueOrder(
    id: 'food-q-1',
    storeId: mockStoreBunBo,
    status: 'PLACED',
    deliveryFareVnd: 25000,
    subtotalVnd: 90000,
    totalVnd: 115000,
    dropoff: FoodDropoff(
      lat: 16.06,
      lng: 108.22,
      label: '45 Trần Phú, Hải Châu',
    ),
    lineCount: 2,
    createdAt: '2026-10-14T03:10:00.000Z',
  ),
  MerchantQueueOrder(
    id: 'food-q-2',
    storeId: mockStoreBunBo,
    status: 'PREPARING',
    deliveryFareVnd: 25000,
    subtotalVnd: 60000,
    totalVnd: 85000,
    dropoff: FoodDropoff(lat: 16.07, lng: 108.21, label: '12 Nguyễn Văn Linh'),
    lineCount: 1,
    createdAt: '2026-10-14T03:05:00.000Z',
  ),
];

const mockReadyFoodJobs = <ReadyFoodJob>[
  ReadyFoodJob(
    id: 'food-ready-1',
    storeId: mockStoreBunBo,
    storeName: 'Bún Bò Huế O Xuân',
    storeAddress: 'Quận Hải Châu, Đà Nẵng',
    deliveryFareVnd: 25000,
    subtotalVnd: 90000,
    totalVnd: 115000,
    dropoff: FoodDropoff(
      lat: 16.06,
      lng: 108.22,
      label: '45 Trần Phú, Hải Châu',
    ),
    lineCount: 2,
  ),
];

const mockPlacedOrder = PlacedFoodOrder(
  id: 'food-order-1',
  status: 'PLACED',
  subtotalVnd: 60000,
  deliveryFareVnd: 25000,
  totalVnd: 85000,
  lines: [
    FoodOrderLine(
      itemId: mockItemBun,
      name: 'Bún bò đặc biệt',
      unitPriceVnd: 60000,
      quantity: 1,
    ),
  ],
);

const mockActiveFoodOrder = FoodOrderDetail(
  id: 'DG123456',
  status: 'ASSIGNED',
  subtotalVnd: 105000,
  deliveryFareVnd: 25000,
  totalVnd: 130000,
  dropoff: FoodDropoff(
    lat: 16.0544,
    lng: 108.2022,
    label: '123 Nguyễn Văn Linh',
  ),
  lines: [
    FoodOrderLine(
      itemId: mockItemBun,
      name: 'Bún bò đặc biệt',
      unitPriceVnd: 45000,
      quantity: 2,
    ),
    FoodOrderLine(
      itemId: mockItemTra,
      name: 'Trà đá',
      unitPriceVnd: 5000,
      quantity: 3,
    ),
  ],
);

const mockOpenRides = <OpenRide>[
  OpenRide(
    id: 'ride-open-1',
    status: 'NEGOTIATING',
    pickup: RidePoint(
      lat: 16.0544,
      lng: 108.2022,
      label: '123 Nguyễn Văn Linh, Hải Châu',
    ),
    dropoff: RidePoint(lat: 16.0439, lng: 108.199, label: 'Sân bay Đà Nẵng'),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offerCount: 1,
  ),
  OpenRide(
    id: 'ride-open-2',
    status: 'NEGOTIATING',
    pickup: RidePoint(lat: 16.068, lng: 108.223, label: 'Cầu Rồng'),
    dropoff: RidePoint(lat: 16.047, lng: 108.22, label: 'Chợ Hàn'),
    offeredFareVnd: 28000,
    referenceFareVnd: 25000,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offerCount: 0,
  ),
];

RideView _createRide(CreateRideRequest request) {
  return RideView(
    id: 'ride-demo-1',
    status: RideStatus.negotiating,
    pickup: request.pickup,
    dropoff: request.dropoff,
    offeredFareVnd: request.offeredFareVnd,
    referenceFareVnd: request.offeredFareVnd,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offers: const [],
  );
}

RideView _getRide(String rideId) {
  return RideView(
    id: rideId,
    status: RideStatus.negotiating,
    pickup: const RidePoint(
      lat: 16.0544,
      lng: 108.2022,
      label: '123 Nguyễn Văn Linh, Hải Châu',
    ),
    dropoff: const RidePoint(
      lat: 16.0439,
      lng: 108.199,
      label: 'Sân bay Đà Nẵng',
    ),
    offeredFareVnd: 42000,
    referenceFareVnd: 40000,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: '2030-01-01T00:00:00.000Z',
    offers: const [
      RideOffer(
        id: 'offer-1',
        driverId: 'driver-1',
        amountVnd: 40000,
        kind: RideOfferKind.accept,
        status: RideOfferStatus.pending,
        expiresAt: '2030-01-01T00:00:00.000Z',
      ),
    ],
  );
}

RideView _selectOffer(SelectRideOfferRequest request) {
  final base = _getRide(request.rideId);
  return RideView(
    id: base.id,
    status: RideStatus.assigned,
    pickup: base.pickup,
    dropoff: base.dropoff,
    offeredFareVnd: base.offeredFareVnd,
    referenceFareVnd: base.referenceFareVnd,
    agreedFareVnd: 40000,
    assignedDriverId: 'driver-1',
    selectedOfferId: request.offerId,
    expiresAt: base.expiresAt,
    offers: [
      for (final offer in base.offers)
        RideOffer(
          id: offer.id,
          driverId: offer.driverId,
          amountVnd: offer.amountVnd,
          kind: offer.kind,
          status: offer.id == request.offerId
              ? RideOfferStatus.selected
              : RideOfferStatus.lost,
          expiresAt: offer.expiresAt,
        ),
    ],
  );
}

RideView _submitOffer(SubmitRideOfferRequest request) {
  final base = _getRide(request.rideId);
  return RideView(
    id: base.id,
    status: base.status,
    pickup: base.pickup,
    dropoff: base.dropoff,
    offeredFareVnd: base.offeredFareVnd,
    referenceFareVnd: base.referenceFareVnd,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: base.expiresAt,
    offers: [
      ...base.offers,
      RideOffer(
        id: 'offer-${request.amountVnd}',
        driverId: 'driver-self',
        amountVnd: request.amountVnd,
        kind: RideOfferKind.counter,
        status: RideOfferStatus.pending,
        expiresAt: '2030-01-01T00:00:00.000Z',
      ),
    ],
  );
}

RideView _cancelRide(String rideId) {
  final base = _getRide(rideId);
  return RideView(
    id: base.id,
    status: RideStatus.cancelled,
    pickup: base.pickup,
    dropoff: base.dropoff,
    offeredFareVnd: base.offeredFareVnd,
    referenceFareVnd: base.referenceFareVnd,
    agreedFareVnd: null,
    assignedDriverId: null,
    selectedOfferId: null,
    expiresAt: base.expiresAt,
    offers: base.offers,
  );
}
