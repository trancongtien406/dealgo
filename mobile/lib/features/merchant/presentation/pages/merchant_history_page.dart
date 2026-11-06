import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/entities/merchant_menu_models.dart';
import '../../domain/repositories/merchant_orders_repository.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_refresh.dart';

/// M020 — finished order history (DEC-PROD-039).
class MerchantHistoryPageView extends StatefulWidget {
  const MerchantHistoryPageView({super.key});

  @override
  State<MerchantHistoryPageView> createState() =>
      _MerchantHistoryPageViewState();
}

class _MerchantHistoryPageViewState extends State<MerchantHistoryPageView> {
  static const _pageSize = 20;

  final _search = TextEditingController();
  final _scroll = ScrollController();
  String? _tab; // null = ALL, DELIVERED, CANCELLED
  var _loading = true;
  var _loadingMore = false;
  var _loadMoreFailed = false;
  var _generation = 0;
  Object? _failure;
  MerchantHistoryPage? _page;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent <= 0) return;
    if (position.pixels < position.maxScrollExtent - 400) return;
    final page = _page;
    if (page == null || _loadingMore || _loadMoreFailed) return;
    if (page.items.length >= page.total) return;
    unawaited(_loadMore());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _loadMoreFailed = false;
      _failure = null;
    });
    try {
      final page = await context
          .read<MerchantOrdersRepository>()
          .listOrderHistory(
            accessToken: (merchantAccessToken(context) ?? ''),
            page: 1,
            limit: _pageSize,
            tab: _tab,
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
          );
      if (mounted && generation == _generation) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    final current = _page;
    if (current == null || _loadingMore) return;
    final generation = _generation;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final next = await context
          .read<MerchantOrdersRepository>()
          .listOrderHistory(
            accessToken: (merchantAccessToken(context) ?? ''),
            page: current.page + 1,
            limit: _pageSize,
            tab: _tab,
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _page = MerchantHistoryPage(
          items: [...current.items, ...next.items],
          page: next.page,
          limit: next.limit,
          total: next.total,
          deliveredCount: next.deliveredCount,
          deliveredRevenueVnd: next.deliveredRevenueVnd,
        );
        _loadingMore = false;
      });
    } on Object {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _page;
    return MerchantPageFrame(
      title: l10n.merchantHistoryTitle,
      onBack: () => merchantBack(context),
      body: DealGoRefresh(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          padding: dealGoScrollPadding(context, merchantPagePadding),
          children: [
            Text(
              l10n.merchantHistoryHeadline,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            DealGoTextField(
              label: l10n.merchantHistorySearch,
              showLabel: false,
              hint: l10n.merchantHistorySearch,
              controller: _search,
              fieldKey: const Key('merchant-history-search'),
              textInputAction: TextInputAction.search,
              suffix: IconButton(
                key: const Key('merchant-history-search-go'),
                icon: const Icon(DealGoIcons.search),
                onPressed: _load,
              ),
              onSubmitted: (_) => _load(),
            ),
            const SizedBox(height: DealGoSpacing.s8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('merchant-history-tab-all'),
                  label: Text(l10n.merchantHistoryAll),
                  selected: _tab == null,
                  onSelected: (_) {
                    setState(() => _tab = null);
                    _load();
                  },
                ),
                ChoiceChip(
                  key: const Key('merchant-history-tab-done'),
                  label: Text(l10n.merchantHistoryDone),
                  selected: _tab == 'DELIVERED',
                  onSelected: (_) {
                    setState(() => _tab = 'DELIVERED');
                    _load();
                  },
                ),
                ChoiceChip(
                  key: const Key('merchant-history-tab-cancelled'),
                  label: Text(l10n.merchantHistoryCancelled),
                  selected: _tab == 'CANCELLED',
                  onSelected: (_) {
                    setState(() => _tab = 'CANCELLED');
                    _load();
                  },
                ),
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            if (page != null)
              Text(
                l10n.merchantHistoryRevenue(
                  formatVnd(page.deliveredRevenueVnd),
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            const SizedBox(height: DealGoSpacing.s12),
            if (_loading && page == null)
              const DealGoSkeletonList(itemCount: 4, padding: EdgeInsets.zero)
            else if (_failure != null && page == null)
              DealGoStateView.failure(
                context,
                onRetry: _load,
                cause: _failure,
                message: _failure is ApiException
                    ? apiErrorText(l10n, _failure as ApiException)
                    : null,
                compact: true,
              )
            else if (page == null || page.items.isEmpty)
              DealGoStateView(
                art: DealGoStateArt.noOrders,
                title: l10n.merchantHistoryEmpty,
                compact: true,
              )
            else ...[
              Text(
                l10n.merchantHistoryList,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              for (final row in page.items) ...[
                MerchantPanel(
                  child: Material(
                    type: MaterialType.transparency,
                    child: ListTile(
                      key: Key('merchant-history-${row.id}'),
                      title: Text(
                        row.customerName?.isNotEmpty == true
                            ? row.customerName!
                            : row.id,
                      ),
                      subtitle: Text('${row.lineSummary} · ${row.status}'),
                      trailing: Text(formatVnd(row.totalVnd)),
                    ),
                  ),
                ),
                const SizedBox(height: DealGoSpacing.s8),
              ],
              if (_loadingMore)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_loadMoreFailed)
                Center(
                  child: TextButton(
                    key: const Key('merchant-history-more-retry'),
                    onPressed: _loadMore,
                    child: Text(l10n.actionRetry),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
