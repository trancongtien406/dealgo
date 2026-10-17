import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../widgets/merchant_widgets.dart';

/// M028 — catalog item variants / size / topping editor shell (mock).
class MerchantItemVariantsPage extends StatefulWidget {
  const MerchantItemVariantsPage({
    required this.itemId,
    this.itemName,
    super.key,
  });

  final String itemId;
  final String? itemName;

  @override
  State<MerchantItemVariantsPage> createState() =>
      _MerchantItemVariantsPageState();
}

class _MerchantItemVariantsPageState extends State<MerchantItemVariantsPage> {
  var _size = 'm';
  final _toppings = <String>{'egg'};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final title = widget.itemName?.trim().isNotEmpty == true
        ? widget.itemName!
        : '${l10n.merchantVariantsItem} ${widget.itemId}';

    return MerchantPageFrame(
      title: l10n.merchantVariantsTitle,
      onBack: () => merchantBack(context),
      footer: Padding(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s8,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: DealGoPrimaryButton(
          key: const Key('merchant-variants-save'),
          label: l10n.merchantVariantsSave,
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.merchantVariantsSavedLocal)),
            );
            if (context.canPop()) {
              context.pop();
            }
          },
        ),
      ),
      body: ListView(
        padding: merchantPagePadding,
        children: [
          DealGoBanner(
            tone: DealGoBannerTone.info,
            message: l10n.merchantSettingsMockHint,
          ),
          const SizedBox(height: DealGoSpacing.s16),
          MerchantPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: textTheme.titleMedium),
                const SizedBox(height: DealGoSpacing.s8),
                DealGoChip(
                  label: l10n.merchantVariantsShellChip,
                  tone: DealGoChipTone.brand,
                ),
              ],
            ),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(l10n.merchantVariantsSizeLabel, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          DealGoSegmentedControl(
            items: [
              DealGoSegmentItem(id: 's', label: l10n.merchantSizeS),
              DealGoSegmentItem(id: 'm', label: l10n.merchantSizeM),
              DealGoSegmentItem(id: 'l', label: l10n.merchantSizeL),
            ],
            value: _size,
            onChanged: (value) => setState(() => _size = value),
          ),
          const SizedBox(height: DealGoSpacing.s16),
          Text(l10n.merchantVariantsToppingsLabel, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s12),
          Wrap(
            spacing: DealGoSpacing.s8,
            runSpacing: DealGoSpacing.s8,
            children: [
              for (final topping in [
                (id: 'egg', label: l10n.merchantToppingEgg),
                (id: 'cheese', label: l10n.merchantToppingCheese),
                (id: 'spice', label: l10n.merchantToppingSpice),
              ])
                DealGoChip(
                  key: Key('merchant-topping-${topping.id}'),
                  label: topping.label,
                  tone: DealGoChipTone.neutral,
                  selected: _toppings.contains(topping.id),
                  onTap: () {
                    setState(() {
                      if (_toppings.contains(topping.id)) {
                        _toppings.remove(topping.id);
                      } else {
                        _toppings.add(topping.id);
                      }
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s16),
          DealGoBanner(
            tone: DealGoBannerTone.warning,
            message: l10n.merchantVariantsPriceHint,
          ),
        ],
      ),
    );
  }
}
