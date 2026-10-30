import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../home_banner/presentation/home_banner_carousel.dart';
import '../../identity/domain/entities/app_role.dart';
import 'customer_home_widgets.dart';
import '../../../core/design_system/components/dealgo_nav_insets.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openShop() => context.go('/customer/shop');

  /// One Ride entry — vehicle class is chosen inside the booking flow.
  void _openBook() => context.go('/customer/book');

  void _openParcel() => context.push('/customer/parcel');

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        controller: _scroll,
        padding: dealGoScrollPadding(
          context,
          const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s8,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
        ),
        children: [
          const HomeHeader(),
          const SizedBox(height: DealGoSpacing.s16),
          HomeSearch(onBook: _openBook),
          const SizedBox(height: DealGoSpacing.s16),
          const HomeBannerCarousel(role: AppRole.customer),
          ServiceRow(
            onRide: _openBook,
            onFood: _openShop,
            onParcel: _openParcel,
          ),
          const SizedBox(height: DealGoSpacing.s24),
          FeaturedShoppingCard(onOpen: _openShop),
          const SizedBox(height: DealGoSpacing.s24),
          const VoucherBanner(),
          const SizedBox(height: DealGoSpacing.s24),
          SectionTitle(
            title: AppLocalizations.of(context).homeRecentTitle,
            action: AppLocalizations.of(context).actionSeeAll,
            onAction: () => context.go('/customer/trips'),
          ),
          const SizedBox(height: DealGoSpacing.s12),
          const RecentTripCard(),
        ],
      ),
    );
  }
}
