import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/design_system/tokens/dealgo_type_scale.dart';
import '../../../../core/motion/dealgo_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/entities/food_money.dart';
import '../cubit/food_cart_cubit.dart';
import 'food_widgets.dart';

const int foodOrderNoteMax = 300;
const int foodLineNoteMax = 200;

/// One cart line: tap the name/note area to edit the dish note, or use the
/// stepper and the remove button under it.
class FoodCartLineTile extends StatelessWidget {
  const FoodCartLineTile({
    required this.line,
    required this.onEditNote,
    required this.onQuantity,
    required this.onRemove,
    super.key,
  });

  final FoodCartLine line;
  final VoidCallback onEditNote;
  final ValueChanged<int> onQuantity;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final note = line.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodThumb(size: 44, imageUrl: line.imageUrl),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: InkWell(
                  key: Key('food-cart-line-${line.itemId}'),
                  onTap: onEditNote,
                  borderRadius: BorderRadius.circular(DealGoRadius.input),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: DealGoSpacing.s4,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: DealGoType.body(textTheme).copyWith(
                            fontWeight: FontWeight.w700,
                            color: DealGoColors.text,
                          ),
                        ),
                        if (note != null && note.isNotEmpty)
                          Text(
                            '"$note"',
                            key: Key('food-cart-line-note-${line.itemId}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: DealGoType.meta(textTheme).copyWith(
                              color: DealGoColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        Text(
                          l10n.foodLineQtyPrice(
                            line.quantity,
                            formatVnd(line.unitPriceVnd),
                          ),
                          style: DealGoType.meta(textTheme)
                              .copyWith(color: DealGoColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: DealGoSpacing.s8),
              Text(
                formatVnd(line.lineTotalVnd),
                style: DealGoType.body(textTheme)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: DealGoSpacing.s4),
          Row(
            children: [
              _QuantityButton(
                key: Key('food-cart-line-minus-${line.itemId}'),
                icon: DealGoIcons.remove,
                tooltip: l10n.foodDecreaseQuantity,
                onPressed: () => onQuantity(line.quantity - 1),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  '${line.quantity}',
                  key: Key('food-cart-line-qty-${line.itemId}'),
                  textAlign: TextAlign.center,
                  style: DealGoType.body(textTheme)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _QuantityButton(
                key: Key('food-cart-line-plus-${line.itemId}'),
                icon: DealGoIcons.add,
                tooltip: l10n.foodAddToCart,
                onPressed: line.quantity >= foodLineQuantityMax
                    ? null
                    : () => onQuantity(line.quantity + 1),
              ),
              const Spacer(),
              IconButton(
                key: Key('food-cart-line-remove-${line.itemId}'),
                tooltip: l10n.foodCartLineRemove,
                onPressed: onRemove,
                icon: const Icon(DealGoIcons.close, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        minimumSize: const Size.square(36),
        foregroundColor: enabled
            ? DealGoColors.primary
            : DealGoColors.textSecondary,
        side: BorderSide(
          color: enabled ? DealGoColors.primary : DealGoColors.border,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.pill),
        ),
      ),
      icon: Icon(icon, size: 18),
    );
  }
}

/// Order-level note. The controller lives here so a parent rebuild (quantity,
/// price, utensils) never resets what the customer is typing.
class FoodOrderNoteField extends StatefulWidget {
  const FoodOrderNoteField({super.key});

  @override
  State<FoodOrderNoteField> createState() => _FoodOrderNoteFieldState();
}

class _FoodOrderNoteFieldState extends State<FoodOrderNoteField> {
  late final FoodCartCubit _cart;
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late String _lastPushed;

  @override
  void initState() {
    super.initState();
    _cart = context.read<FoodCartCubit>();
    _controller = TextEditingController(text: _cart.state.note);
    _focus = FocusNode();
    _lastPushed = _cart.state.note;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _lastPushed = text.trim();
    _cart.setNote(text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocListener<FoodCartCubit, FoodCartState>(
      listenWhen: (previous, next) => previous.note != next.note,
      listener: (context, state) {
        if (state.note == _lastPushed || _focus.hasFocus) {
          return;
        }
        _controller.value = TextEditingValue(
          text: state.note,
          selection: TextSelection.collapsed(offset: state.note.length),
        );
      },
      child: DealGoTextField(
        fieldKey: const Key('food-order-note-field'),
        label: l10n.foodOrderNoteLabel,
        hint: l10n.foodOrderNoteHint,
        controller: _controller,
        focusNode: _focus,
        maxLines: 3,
        maxLength: foodOrderNoteMax,
        textCapitalization: TextCapitalization.sentences,
        onChanged: _onChanged,
      ),
    );
  }
}

class FoodUtensilsField extends StatelessWidget {
  const FoodUtensilsField({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final utensils = context.select<FoodCartCubit, bool>(
      (cart) => cart.state.utensils,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.foodUtensilsLabel,
          style: DealGoType.body(Theme.of(context).textTheme)
              .copyWith(fontWeight: FontWeight.w700, color: DealGoColors.text),
        ),
        const SizedBox(height: DealGoSpacing.s8),
        DealGoSegmentedControl(
          key: const Key('food-utensils-control'),
          items: [
            DealGoSegmentItem(id: 'yes', label: l10n.foodUtensilsYes),
            DealGoSegmentItem(id: 'no', label: l10n.foodUtensilsNo),
          ],
          value: utensils ? 'yes' : 'no',
          onChanged: (id) =>
              context.read<FoodCartCubit>().setUtensils(id == 'yes'),
        ),
      ],
    );
  }
}

/// Text entered in the line-note sheet: null note = the customer cleared it.
typedef FoodLineNoteResult = ({String? note});

Future<void> editFoodCartLineNote(
  BuildContext context,
  FoodCartLine line,
) async {
  final cubit = context.read<FoodCartCubit>();
  final l10n = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.maybeOf(context);
  final result = await showDealGoSheet<FoodLineNoteResult>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) =>
        _FoodLineNoteSheet(lineName: line.name, initialNote: line.note),
  );
  if (result == null || cubit.isClosed) {
    return;
  }
  cubit.setLineNote(line.itemId, result.note);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.foodNoteSaved)));
}

class _FoodLineNoteSheet extends StatefulWidget {
  const _FoodLineNoteSheet({required this.lineName, this.initialNote});

  final String lineName;
  final String? initialNote;

  @override
  State<_FoodLineNoteSheet> createState() => _FoodLineNoteSheetState();
}

class _FoodLineNoteSheetState extends State<_FoodLineNoteSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote ?? '');
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
    final hasNote = (widget.initialNote ?? '').trim().isNotEmpty;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
          ),
          child: Column(
            key: const Key('food-line-note-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.lineName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DealGoType.subtitle(textTheme),
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                fieldKey: const Key('food-line-note-field'),
                label: l10n.foodLineNoteLabel,
                hint: l10n.foodLineNoteHint,
                controller: _controller,
                autofocus: true,
                maxLines: 3,
                maxLength: foodLineNoteMax,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Row(
                children: [
                  if (hasNote)
                    TextButton(
                      key: const Key('food-line-note-clear'),
                      onPressed: () =>
                          Navigator.of(context)
                              .pop<FoodLineNoteResult>((note: null)),
                      child: Text(l10n.foodLineNoteClear),
                    ),
                  const Spacer(),
                  TextButton(
                    key: const Key('food-line-note-cancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  TextButton(
                    key: const Key('food-line-note-save'),
                    onPressed: () =>
                        Navigator.of(context)
                            .pop<FoodLineNoteResult>((note: _controller.text)),
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
