import 'package:flutter/material.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/available_voucher.dart';
import '../pages/vouchers_page.dart';

/// Available food vouchers (`GET /v1/promotions/available`). Picking a code
/// returns it to checkout; the field still asks the server to price it.
class FoodVoucherPickerSheet extends StatefulWidget {
  const FoodVoucherPickerSheet({required this.load, super.key});

  final Future<List<AvailableVoucher>> Function() load;

  @override
  State<FoodVoucherPickerSheet> createState() => _FoodVoucherPickerSheetState();
}

class _FoodVoucherPickerSheetState extends State<FoodVoucherPickerSheet> {
  List<AvailableVoucher>? _items;
  Object? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _failure = null;
      _items = null;
    });
    try {
      final items = await widget.load();
      if (mounted) {
        setState(() => _items = items);
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _failure = error;
          _items = const [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = _items;
    final failure = _failure;
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoDimensions.pageGutter,
                DealGoSpacing.s16,
                DealGoDimensions.pageGutter,
                DealGoSpacing.s8,
              ),
              child: Text(
                l10n.accountVouchers,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Expanded(
              child: items == null
                  ? const Center(
                      child: CircularProgressIndicator(
                        key: Key('checkout-vouchers-loading'),
                      ),
                    )
                  : failure != null
                  ? Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s16),
                      child: DealGoStateView.failure(
                        context,
                        key: const Key('checkout-vouchers-error'),
                        onRetry: _load,
                        cause: failure,
                      ),
                    )
                  : items.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(DealGoSpacing.s16),
                      child: DealGoStateView(
                        key: const Key('checkout-vouchers-empty'),
                        art: DealGoStateArt.noVouchers,
                        title: l10n.vouchersEmptyTitle,
                        message: l10n.vouchersEmptyBody,
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s8,
                        DealGoDimensions.pageGutter,
                        DealGoSpacing.s24,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: DealGoSpacing.s12),
                      itemBuilder: (context, index) {
                        final voucher = items[index];
                        return ListTile(
                          key: Key('checkout-voucher-${voucher.code}'),
                          contentPadding: EdgeInsets.zero,
                          title: Text(voucherHeadline(l10n, voucher)),
                          subtitle: Text(voucher.name),
                          trailing: DealGoChip(
                            label: voucher.code,
                            tone: DealGoChipTone.promo,
                          ),
                          onTap: () => Navigator.of(context).pop(voucher.code),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
