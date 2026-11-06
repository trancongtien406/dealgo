import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/replace_merchant_item_options.dart';
import '../cubit/merchant_item_options_cubit.dart';
import '../widgets/merchant_widgets.dart';

/// M028 — size / variant / topping editor for one dish (DEC-PROD-033).
/// Saves the whole layout via PUT /v1/food/merchant/items/:id/options.
class MerchantItemVariantsPage extends StatelessWidget {
  const MerchantItemVariantsPage({
    required this.itemId,
    this.itemName,
    super.key,
  });

  final String itemId;
  final String? itemName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MerchantItemOptionsCubit(
        getMerchantCatalog: context.read<GetMerchantCatalog>(),
        replaceOptions: context.read<ReplaceMerchantItemOptions>(),
        itemId: itemId,
      )..load(merchantAccessToken(context)),
      child: _VariantsView(itemName: itemName),
    );
  }
}

class _VariantsView extends StatelessWidget {
  const _VariantsView({this.itemName});

  final String? itemName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<MerchantItemOptionsCubit>().state;
    final ready = state is MerchantItemOptionsReady ? state : null;
    return BlocListener<MerchantItemOptionsCubit, MerchantItemOptionsState>(
      listenWhen: (previous, current) =>
          current is MerchantItemOptionsReady &&
          (previous is! MerchantItemOptionsReady ||
              previous.savedTick != current.savedTick ||
              (current.error != null && previous.error != current.error)),
      listener: (context, state) {
        final current = state as MerchantItemOptionsReady;
        final text =
            current.error?.resolve(l10n) ??
            (current.savedTick > 0 ? l10n.merchantOptionsSaved : null);
        if (text == null) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(text)));
      },
      // Scaffold: Material for the InkWell rows and a host for snackbars.
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        body: MerchantPageFrame(
          title: l10n.merchantVariantsTitle,
          subtitle: ready?.item.name ?? itemName,
          onBack: () => merchantBack(context),
          footer: ready == null
              ? null
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s8,
                    DealGoDimensions.pageGutter,
                    DealGoSpacing.s12,
                  ),
                  child: DealGoPrimaryButton(
                    key: const Key('merchant-variants-save'),
                    label: l10n.merchantVariantsSave,
                    isLoading: ready.saving,
                    enabled: ready.dirty,
                    onPressed: () => context
                        .read<MerchantItemOptionsCubit>()
                        .save(merchantAccessToken(context)),
                  ),
                ),
          body: switch (state) {
            MerchantItemOptionsLoading() => const DealGoSkeletonList(
              itemCount: 3,
            ),
            MerchantItemOptionsFailed(:final message) =>
              DealGoStateView.failure(
                context,
                key: const Key('merchant-variants-retry'),
                onRetry: () => context.read<MerchantItemOptionsCubit>().load(
                  merchantAccessToken(context),
                ),
                cause: message.error,
                message: message.resolve(l10n),
              ),
            // InkWell rows need a Material ancestor; the frame is a plain box.
            MerchantItemOptionsReady() => _VariantsBody(state: state),
          },
        ),
      ),
    );
  }
}

class _VariantsBody extends StatelessWidget {
  const _VariantsBody({required this.state});

  final MerchantItemOptionsReady state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<MerchantItemOptionsCubit>();
    final item = state.item;
    return ListView(
      padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
      children: [
        MerchantPanel(
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: DealGoColors.primaryLight,
                  borderRadius: BorderRadius.circular(DealGoRadius.card),
                ),
                child: const Icon(DealGoIcons.tag, color: DealGoColors.primary),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: textTheme.titleMedium),
                    Text(
                      l10n.merchantOptionsBasePrice(formatVnd(item.priceVnd)),
                      key: const Key('merchant-variants-base-price'),
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (state.dirty)
                Text(
                  l10n.merchantOptionsUnsaved,
                  key: const Key('merchant-variants-dirty'),
                  style: textTheme.labelSmall?.copyWith(
                    color: DealGoColors.warning,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: DealGoSpacing.s16),
        if (state.groups.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: DealGoSpacing.s16),
            child: Text(
              l10n.merchantOptionsEmpty,
              key: const Key('merchant-variants-empty'),
              style: textTheme.bodyMedium,
            ),
          ),
        for (var gi = 0; gi < state.groups.length; gi++) ...[
          _GroupSection(
            index: gi,
            group: state.groups[gi],
            basePriceVnd: item.priceVnd,
            enabled: !state.saving,
          ),
          const SizedBox(height: DealGoSpacing.s16),
        ],
        if (state.groups.length < merchantOptionMaxGroups)
          OutlinedButton.icon(
            key: const Key('merchant-group-add'),
            onPressed: state.saving
                ? null
                : () async {
                    final edit = await _showGroupDialog(context);
                    if (edit == null || edit.delete) return;
                    cubit.putGroup(
                      title: edit.title,
                      minSelect: edit.minSelect,
                      maxSelect: edit.maxSelect,
                    );
                  },
            icon: const Icon(DealGoIcons.add),
            label: Text(l10n.merchantOptionsAddGroup),
          ),
      ],
    );
  }
}

String _groupRule(AppLocalizations l10n, FoodOptionGroup group) {
  if (group.minSelect == 0) {
    return group.maxSelect <= 1
        ? l10n.merchantOptionsRuleOptionalOne
        : l10n.merchantOptionsRuleUpTo(group.maxSelect);
  }
  if (group.minSelect == 1 && group.maxSelect == 1) {
    return l10n.merchantOptionsRuleRequiredOne;
  }
  return l10n.merchantOptionsRuleRange(group.minSelect, group.maxSelect);
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({
    required this.index,
    required this.group,
    required this.basePriceVnd,
    required this.enabled,
  });

  final int index;
  final FoodOptionGroup group;
  final int basePriceVnd;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<MerchantItemOptionsCubit>();
    // Required single choice (e.g. Size) shows the full price like M028.
    final absolute = group.required && !group.multi;
    final valid = merchantOptionGroupValid(group);
    return Column(
      key: Key('merchant-group-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: Key('merchant-group-edit-$index'),
                onTap: !enabled
                    ? null
                    : () async {
                        final edit = await _showGroupDialog(
                          context,
                          group: group,
                        );
                        if (edit == null) return;
                        if (edit.delete) {
                          cubit.removeGroup(index);
                          return;
                        }
                        cubit.putGroup(
                          index: index,
                          title: edit.title,
                          minSelect: edit.minSelect,
                          maxSelect: edit.maxSelect,
                        );
                      },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            group.title,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: DealGoSpacing.s4),
                        Icon(
                          DealGoIcons.edit,
                          size: 16,
                          color: DealGoColors.textSecondary,
                        ),
                      ],
                    ),
                    Text(
                      _groupRule(l10n, group),
                      key: Key('merchant-group-rule-$index'),
                      style: textTheme.bodySmall?.copyWith(
                        color: valid
                            ? DealGoColors.textSecondary
                            : DealGoColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (group.choices.length < merchantOptionMaxChoices)
              TextButton(
                key: Key('merchant-option-add-$index'),
                onPressed: !enabled
                    ? null
                    : () async {
                        final edit = await _showChoiceDialog(context);
                        if (edit == null || edit.delete) return;
                        cubit.putChoice(
                          groupIndex: index,
                          label: edit.label,
                          extraVnd: edit.extraVnd,
                          available: edit.available,
                          maxQuantity: edit.maxQuantity,
                        );
                      },
                child: Text(l10n.merchantOptionsAddChoice),
              ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s8),
        if (group.choices.isNotEmpty)
          MerchantPanel(
            child: Column(
              children: [
                for (var ci = 0; ci < group.choices.length; ci++)
                  _ChoiceRow(
                    key: Key('merchant-option-$index-$ci'),
                    choice: group.choices[ci],
                    multi: group.multi,
                    priceText: absolute
                        ? formatVnd(basePriceVnd + group.choices[ci].extraVnd)
                        : '+${formatVnd(group.choices[ci].extraVnd)}',
                    onTap: !enabled
                        ? null
                        : () async {
                            final edit = await _showChoiceDialog(
                              context,
                              choice: group.choices[ci],
                            );
                            if (edit == null) return;
                            if (edit.delete) {
                              cubit.removeChoice(index, ci);
                              return;
                            }
                            cubit.putChoice(
                              groupIndex: index,
                              choiceIndex: ci,
                              label: edit.label,
                              extraVnd: edit.extraVnd,
                              available: edit.available,
                              maxQuantity: edit.maxQuantity,
                            );
                          },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.choice,
    required this.multi,
    required this.priceText,
    required this.onTap,
    super.key,
  });

  final FoodOptionChoice choice;
  final bool multi;
  final String priceText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DealGoColors.primaryLight,
                borderRadius: BorderRadius.circular(DealGoSpacing.s8),
              ),
              child: Icon(
                multi ? DealGoIcons.add : DealGoIcons.check,
                size: 18,
                color: DealGoColors.primary,
              ),
            ),
            const SizedBox(width: DealGoSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(choice.label, style: textTheme.titleSmall),
                  if (!choice.available)
                    Text(
                      l10n.merchantOptionsSoldOut,
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.danger,
                      ),
                    ),
                  if (choice.maxQuantity > 1)
                    Text(
                      l10n.merchantOptionsMaxQty('${choice.maxQuantity}'),
                      style: textTheme.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(priceText, style: textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}

class _GroupEdit {
  const _GroupEdit(
    this.title,
    this.minSelect,
    this.maxSelect, {
    this.delete = false,
  });

  final String title;
  final int minSelect;
  final int maxSelect;
  final bool delete;
}

class _ChoiceEdit {
  const _ChoiceEdit(
    this.label,
    this.extraVnd,
    this.available, {
    this.maxQuantity = 1,
    this.delete = false,
  });

  final String label;
  final int extraVnd;
  final bool available;
  final int maxQuantity;
  final bool delete;
}

Future<_GroupEdit?> _showGroupDialog(
  BuildContext context, {
  FoodOptionGroup? group,
}) {
  return showDialog<_GroupEdit>(
    context: context,
    builder: (context) => _GroupDialog(group: group),
  );
}

Future<_ChoiceEdit?> _showChoiceDialog(
  BuildContext context, {
  FoodOptionChoice? choice,
}) {
  return showDialog<_ChoiceEdit>(
    context: context,
    builder: (context) => _ChoiceDialog(choice: choice),
  );
}

class _GroupDialog extends StatefulWidget {
  const _GroupDialog({this.group});

  final FoodOptionGroup? group;

  @override
  State<_GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<_GroupDialog> {
  late final _name = TextEditingController(text: widget.group?.title ?? '');
  late final _min = TextEditingController(
    text: '${widget.group?.minSelect ?? 0}',
  );
  late final _max = TextEditingController(
    text: '${widget.group?.maxSelect ?? 1}',
  );

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minSelect = int.tryParse(_min.text) ?? -1;
    final maxSelect = int.tryParse(_max.text) ?? -1;
    final ok =
        _name.text.trim().isNotEmpty &&
        _name.text.trim().length <= 80 &&
        minSelect >= 0 &&
        maxSelect >= 1 &&
        minSelect <= maxSelect &&
        maxSelect <= merchantOptionMaxChoices;
    final digits = [FilteringTextInputFormatter.digitsOnly];
    return AlertDialog(
      title: Text(l10n.merchantOptionsGroupDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DealGoTextField(
            label: l10n.merchantOptionsGroupName,
            fieldKey: const Key('merchant-group-name'),
            controller: _name,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          DealGoTextField(
            label: l10n.merchantOptionsMin,
            fieldKey: const Key('merchant-group-min'),
            controller: _min,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onChanged: (_) => setState(() {}),
          ),
          DealGoTextField(
            label: l10n.merchantOptionsMax,
            fieldKey: const Key('merchant-group-max'),
            controller: _max,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        if (widget.group != null)
          TextButton(
            key: const Key('merchant-group-delete'),
            onPressed: () =>
                Navigator.of(context)
                    .pop(const _GroupEdit('', 0, 1, delete: true)),
            child: Text(
              l10n.merchantOptionsDelete,
              style: const TextStyle(color: DealGoColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('merchant-group-apply'),
          onPressed: ok
              ? () => Navigator.of(context)
                    .pop(_GroupEdit(_name.text.trim(), minSelect, maxSelect))
              : null,
          child: Text(l10n.merchantOptionsApply),
        ),
      ],
    );
  }
}

class _ChoiceDialog extends StatefulWidget {
  const _ChoiceDialog({this.choice});

  final FoodOptionChoice? choice;

  @override
  State<_ChoiceDialog> createState() => _ChoiceDialogState();
}

class _ChoiceDialogState extends State<_ChoiceDialog> {
  late final _name = TextEditingController(text: widget.choice?.label ?? '');
  late final _price = TextEditingController(
    text: '${widget.choice?.extraVnd ?? 0}',
  );
  late var _available = widget.choice?.available ?? true;
  late final _maxQty = TextEditingController(
    text: '${widget.choice?.maxQuantity ?? 1}',
  );

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _maxQty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final extra = int.tryParse(_price.text) ?? -1;
    final maxQ = int.tryParse(_maxQty.text) ?? 0;
    final ok =
        _name.text.trim().isNotEmpty &&
        _name.text.trim().length <= 80 &&
        extra >= 0 &&
        extra <= merchantOptionMaxDeltaVnd &&
        maxQ >= 1 &&
        maxQ <= 99;
    return AlertDialog(
      title: Text(l10n.merchantOptionsChoiceDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DealGoTextField(
            label: l10n.merchantOptionsChoiceName,
            fieldKey: const Key('merchant-option-name'),
            controller: _name,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          DealGoTextField(
            label: l10n.merchantOptionsChoicePrice,
            fieldKey: const Key('merchant-option-price'),
            controller: _price,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          DealGoTextField(
            label: l10n.merchantOptionsChoiceMaxQty,
            fieldKey: const Key('merchant-option-max-qty'),
            controller: _maxQty,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          SwitchListTile(
            key: const Key('merchant-option-available'),
            contentPadding: EdgeInsets.zero,
            value: _available,
            title: Text(l10n.merchantOptionsChoiceAvailable),
            onChanged: (value) => setState(() => _available = value),
          ),
        ],
      ),
      actions: [
        if (widget.choice != null)
          TextButton(
            key: const Key('merchant-option-delete'),
            onPressed: () =>
                Navigator.of(context)
                    .pop(const _ChoiceEdit('', 0, true, delete: true)),
            child: Text(
              l10n.merchantOptionsDelete,
              style: const TextStyle(color: DealGoColors.danger),
            ),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionCancel),
        ),
        FilledButton(
          key: const Key('merchant-option-apply'),
          onPressed: ok
              ? () => Navigator.of(context).pop(
                  _ChoiceEdit(
                    _name.text.trim(),
                    extra,
                    _available,
                    maxQuantity: maxQ,
                  ),
                )
              : null,
          child: Text(l10n.merchantOptionsApply),
        ),
      ],
    );
  }
}
