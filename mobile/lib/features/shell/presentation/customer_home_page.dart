import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import 'customer_home_widgets.dart';
import 'customer_tab_bar.dart';

class CustomerHomePage extends StatefulWidget {
  const CustomerHomePage({super.key});

  @override
  State<CustomerHomePage> createState() => _CustomerHomePageState();
}

class _CustomerHomePageState extends State<CustomerHomePage> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey _servicesKey = GlobalKey();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _openShop() => context.go('/customer/shop');

  void _openBook() => context.go('/customer/book');

  void _explore() {
    final target = _servicesKey.currentContext;
    if (target == null) {
      return;
    }
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    Scrollable.ensureVisible(
      target,
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: dealGoSafeAreaBottom(context),
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          customerShellBottomClearance(context),
        ),
        children: [
          const HomeHeader(),
          const SizedBox(height: DealGoSpacing.s16),
          HomeSearch(onBook: _openBook),
          const SizedBox(height: DealGoSpacing.s16),
          HeroBanner(
            onExplore: _explore,
            onBook: _openBook,
            onFood: _openShop,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          ServiceRow(key: _servicesKey, onBook: _openBook, onFood: _openShop),
          const SizedBox(height: DealGoSpacing.s16),
          QuickBookCard(onBook: _openBook),
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
