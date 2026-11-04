import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

/// Checkout review of the note and cutlery choice taken in the cart: both
/// write back to [FoodCartCubit], so cart and checkout never disagree.
class FoodCheckoutExtrasPanel extends StatelessWidget {
  const FoodCheckoutExtrasPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cart = context.watch<FoodCartCubit>().state;
    final note = cart.note;
    return FoodPanel(
      key: const Key('food-checkout-extras'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.foodCheckoutExtrasTitle, style: textTheme.titleMedium),
          const SizedBox(height: DealGoSpacing.s8),
          InkWell(
            key: const Key('food-checkout-note-row'),
            onTap: () => _editNote(context),
            borderRadius: BorderRadius.circular(DealGoRadius.input),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
                child: Row(
                  children: [
                    Icon(
                      DealGoIcons.note,
                      size: 18,
                      color: DealGoColors.textSecondary,
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Expanded(
                      child: Text(
                        note.isEmpty ? l10n.foodCheckoutNoteEmpty : note,
                        key: const Key('food-checkout-note-value'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: DealGoType.body(textTheme).copyWith(
                          color: note.isEmpty
                              ? DealGoColors.textSecondary
                              : DealGoColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    Text(
                      note.isEmpty
                          ? l10n.foodCheckoutNoteAdd
                          : l10n.foodCheckoutNoteEdit,
                      style: DealGoType.meta(textTheme)
                          .copyWith(color: DealGoColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: DealGoSpacing.s24),
          Text(
            l10n.foodUtensilsLabel,
            style: DealGoType.body(
              textTheme,
            ).copyWith(fontWeight: FontWeight.w700, color: DealGoColors.text),
          ),
          const SizedBox(height: DealGoSpacing.s8),
          DealGoSegmentedControl(
            key: const Key('food-checkout-utensils'),
            items: [
              DealGoSegmentItem(id: 'yes', label: l10n.foodUtensilsYes),
              DealGoSegmentItem(id: 'no', label: l10n.foodUtensilsNo),
            ],
            value: cart.utensils ? 'yes' : 'no',
            onChanged: (id) =>
                context.read<FoodCartCubit>().setUtensils(id == 'yes'),
          ),
        ],
      ),
    );
  }

  Future<void> _editNote(BuildContext context) async {
    final cubit = context.read<FoodCartCubit>();
    final result = await showDealGoSheet<String>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      builder: (_) => _CheckoutNoteSheet(initialNote: cubit.state.note),
    );
    if (result == null || cubit.isClosed) {
      return;
    }
    cubit.setNote(result);
  }
}

class _CheckoutNoteSheet extends StatefulWidget {
  const _CheckoutNoteSheet({required this.initialNote});

  final String initialNote;

  @override
  State<_CheckoutNoteSheet> createState() => _CheckoutNoteSheetState();
}

class _CheckoutNoteSheetState extends State<_CheckoutNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          child: Column(
            key: const Key('food-checkout-note-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.foodOrderNoteLabel,
                style: DealGoType.subtitle(textTheme),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                fieldKey: const Key('food-checkout-note-field'),
                label: l10n.foodOrderNoteLabel,
                hint: l10n.foodOrderNoteHint,
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                maxLength: foodOrderNoteMax,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Row(
                children: [
                  if (widget.initialNote.trim().isNotEmpty)
                    TextButton(
                      key: const Key('food-checkout-note-clear'),
                      onPressed: () => Navigator.of(context).pop(''),
                      child: Text(l10n.foodLineNoteClear),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const Key('food-checkout-note-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  TextButton(
                    key: const Key('food-checkout-note-save'),
                    onPressed: () =>
                        Navigator.of(context).pop(_controller.text),
                    child: Text(l10n.actionSave),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
