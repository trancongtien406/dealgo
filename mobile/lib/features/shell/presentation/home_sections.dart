import 'package:flutter/material.dart';

import '../../../core/design_system/components/dealgo_illustration.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'home_shared.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    required this.title,
    required this.action,
    required this.onAction,
    super.key,
  });

  final String title;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(foregroundColor: DealGoColors.primary),
          child: Text(action),
        ),
      ],
    );
  }
}

class CategoryRow extends StatelessWidget {
  const CategoryRow({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    const categories = <_Category>[
      _Category(
        'Đồ ăn',
        Icons.ramen_dining,
        Color(0xFFFFF1E6),
        Color(0xFFEA580C),
      ),
      _Category(
        'Siêu thị',
        Icons.shopping_cart_outlined,
        Color(0xFFE7F8EC),
        DealGoColors.brandGreen,
      ),
      _Category(
        'Cửa hàng tiện lợi',
        Icons.storefront_outlined,
        Color(0xFFE8F1FF),
        Color(0xFF2563EB),
      ),
      _Category(
        'Giao thuốc',
        Icons.medical_services_outlined,
        Color(0xFFFFEEF1),
        DealGoColors.danger,
      ),
      _Category(
        'Hoa & Quà',
        Icons.local_florist_outlined,
        Color(0xFFF3EAFF),
        DealGoColors.primary,
      ),
      _Category(
        'Điện tử',
        Icons.devices_outlined,
        Color(0xFFEEF2FF),
        Color(0xFF4F46E5),
      ),
      _Category(
        'Thời trang',
        Icons.checkroom_outlined,
        Color(0xFFFFF1F6),
        Color(0xFFDB2777),
      ),
    ];

    return SizedBox(
      height: 104,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          final category = categories[index];
          return _CategoryTile(category: category, onTap: onOpen);
        },
      ),
    );
  }
}

class _Category {
  const _Category(this.label, this.icon, this.background, this.color);

  final String label;
  final IconData icon;
  final Color background;
  final Color color;
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category, required this.onTap});

  final _Category category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: category.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(category.icon, color: category.color, size: 22),
              ),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Text(
              category.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: DealGoColors.text, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class StoreRow extends StatelessWidget {
  const StoreRow({required this.onOpen, super.key});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _stores.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: DealGoSpacing.s12),
        itemBuilder: (context, index) {
          return _StoreCard(store: _stores[index], onTap: onOpen);
        },
      ),
    );
  }
}

class _StoreSample {
  const _StoreSample({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.time,
    required this.kind,
    required this.imageAsset,
    this.price,
  });

  final String name;
  final String rating;
  final String reviews;
  final String time;
  final _StoreKind kind;
  final String imageAsset;
  final String? price;
}

enum _StoreKind { food, mart, convenience }

const _stores = <_StoreSample>[
  _StoreSample(
    name: 'Bún Bò Huế Ô Cồ',
    rating: '4.8',
    reviews: '(1.2k+)',
    time: '20-30 phút',
    price: '35.000đ',
    kind: _StoreKind.food,
    imageAsset: 'assets/images/food_bun_bo_hue.png',
  ),
  _StoreSample(
    name: 'Co.opmart Đà Nẵng',
    rating: '4.7',
    reviews: '(3.4k+)',
    time: '30-45 phút',
    kind: _StoreKind.mart,
    imageAsset: 'assets/images/store_supermarket.png',
  ),
  _StoreSample(
    name: 'Circle K',
    rating: '4.6',
    reviews: '(2.1k+)',
    time: '15-25 phút',
    kind: _StoreKind.convenience,
    imageAsset: 'assets/images/store_convenience.png',
  ),
];

class _StoreCard extends StatelessWidget {
  const _StoreCard({required this.store, required this.onTap});

  final _StoreSample store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final price = store.price;
    return SizedBox(
      width: 176,
      child: Material(
        color: DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.card),
          side: const BorderSide(color: DealGoColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 84,
                width: double.infinity,
                child: _StoreArt(
                  kind: store.kind,
                  imageAsset: store.imageAsset,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(DealGoSpacing.s12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    Text(
                      '★ ${store.rating} ${store.reviews}',
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.amber,
                      ),
                    ),
                    Text(store.time, style: textTheme.bodySmall),
                    const SizedBox(height: DealGoSpacing.s8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: DealGoColors.greenSurface,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DealGoSpacing.s8,
                          vertical: DealGoSpacing.s4,
                        ),
                        child: Text(
                          AppLocalizations.of(context).foodFreeshipChip,
                          style: textTheme.labelSmall?.copyWith(
                            color: DealGoColors.brandGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    if (price != null) ...[
                      const SizedBox(height: DealGoSpacing.s4),
                      Text(
                        price,
                        style: textTheme.titleMedium?.copyWith(
                          color: DealGoColors.primary,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreArt extends StatelessWidget {
  const _StoreArt({required this.kind, required this.imageAsset});

  final _StoreKind kind;
  final String imageAsset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      imageAsset,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) {
        return switch (kind) {
          _StoreKind.food => const ColoredBox(
            color: Color(0xFFFFF4EA),
            child: Center(
              child: Icon(
                Icons.ramen_dining,
                color: Color(0xFFEA580C),
                size: 42,
              ),
            ),
          ),
          _StoreKind.mart => const ColoredBox(
            color: Color(0xFF1D4ED8),
            child: Center(
              child: Text(
                'co.opmart',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          _StoreKind.convenience => const ColoredBox(
            color: Color(0xFFE11D2E),
            child: Center(
              child: Text(
                'CIRCLE K',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        };
      },
    );
  }
}

class VoucherBanner extends StatelessWidget {
  const VoucherBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF4ECFF), Color(0xFFE8F8EC)],
        ),
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined, color: DealGoColors.primary),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DealGo Voucher',
                    style: textTheme.labelSmall?.copyWith(
                      color: DealGoColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Ưu đãi mỗi ngày, tiết kiệm mỗi chuyến!',
                    style: textTheme.titleMedium?.copyWith(fontSize: 15),
                  ),
                  const SizedBox(height: DealGoSpacing.s4),
                  Text(
                    'Giảm đến 50% cho Đặt xe, Mua hàng và nhiều dịch vụ khác.',
                    style: textTheme.bodySmall,
                  ),
                  const SizedBox(height: DealGoSpacing.s8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: HomePillButton(
                      label: AppLocalizations.of(context).actionHuntDeals,
                      onPressed: _noop,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Image.asset(
              'assets/images/promo_voucher_clean.png',
              width: 64,
              height: 64,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stack) {
                return const DealGoIllustration(
                  'assets/illustrations/accent_promo_gift.svg',
                  width: 64,
                  height: 64,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void _noop() {}

class RecentTripCard extends StatelessWidget {
  const RecentTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.card,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s16),
        child: Row(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.subtlePurple,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.two_wheeler, color: DealGoColors.primary),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hôm qua · 14:32', style: textTheme.bodySmall),
                  Text(
                    'Sân bay Đà Nẵng → 123 Nguyễn Văn Linh',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: DealGoSpacing.s8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '72.000đ',
                  style: textTheme.titleMedium?.copyWith(fontSize: 15),
                ),
                const SizedBox(height: DealGoSpacing.s4),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: DealGoColors.greenSurface,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DealGoSpacing.s8,
                      vertical: 2,
                    ),
                    child: Text(
                      'Hoàn thành',
                      style: textTheme.labelSmall?.copyWith(
                        color: DealGoColors.brandGreen,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
