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

/// M020 — finished order history (DEC-PROD-039).
class MerchantHistoryPageView extends StatefulWidget {
  const MerchantHistoryPageView({super.key});

  @override
  State<MerchantHistoryPageView> createState() =>
      _MerchantHistoryPageViewState();
}

class _MerchantHistoryPageViewState extends State<MerchantHistoryPageView> {
  final _search = TextEditingController();
  String? _tab; // null = ALL, DELIVERED, CANCELLED
  var _loading = true;
  Object? _failure;
  MerchantHistoryPage? _page;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failure = null;
    });
    try {
      final page = await context
          .read<MerchantOrdersRepository>()
          .listOrderHistory(
            accessToken: (merchantAccessToken(context) ?? ''),
            tab: _tab,
            q: _search.text.trim().isEmpty ? null : _search.text.trim(),
          );
      if (mounted) {
        setState(() {
          _page = page;
          _loading = false;
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failure = error;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final page = _page;
    return MerchantPageFrame(
      title: l10n.merchantHistoryTitle,
      onBack: () => merchantBack(context),
      body: ListView(
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
              l10n.merchantHistoryRevenue(formatVnd(page.deliveredRevenueVnd)),
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
          ],
        ],
      ),
    );
  }
}
