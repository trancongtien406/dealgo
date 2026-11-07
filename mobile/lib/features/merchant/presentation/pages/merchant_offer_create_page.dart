import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_date_time_picker.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../domain/merchant_offers.dart';
import '../widgets/merchant_widgets.dart';

/// M041 — new store offer form; pops the created offer.
class MerchantOfferCreatePage extends StatefulWidget {
  const MerchantOfferCreatePage({super.key});

  @override
  State<MerchantOfferCreatePage> createState() =>
      _MerchantOfferCreatePageState();
}

class _MerchantOfferCreatePageState extends State<MerchantOfferCreatePage>
    with TextDraftMixin {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  final _min = TextEditingController(text: '0');
  final _usage = TextEditingController(text: '100');
  final _perUser = TextEditingController(text: '1');
  var _kind = StoreOfferKind.percentage;
  late DateTime _start;
  late DateTime _end;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateUtils.dateOnly(DateTime.now());
    _start = today;
    _end = today.add(const Duration(days: 7));
    // A half-typed offer survives an app kill; cleared once it is created.
    bindTextDraft(
      'merchant.offer.create',
      {
        'name': _name,
        'code': _code,
        'value': _value,
        'max': _max,
        'min': _min,
        'usage': _usage,
        'perUser': _perUser,
      },
      extras: () => {'kind': _kind.name},
      restoreExtras: (saved) {
        final kind = StoreOfferKind.values
            .where((k) => k.name == saved['kind'])
            .firstOrNull;
        if (kind == null || kind == _kind) return false;
        setState(() => _kind = kind);
        return true;
      },
    );
  }

  @override
  void dispose() {
    for (final c in [_name, _code, _value, _max, _min, _usage, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  int? _num(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _pickDate({required bool start}) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final first = start ? today : _start;
    final picked = await showDealGoDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: first,
      lastDate: today.add(const Duration(days: merchantOfferMaxDays)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = picked;
        if (!_end.isAfter(_start)) _end = _start.add(const Duration(days: 1));
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final start = DateUtils.isSameDay(_start, now) ? now : _start;
    // Inclusive end date: the offer runs through the last picked day.
    final end = DateTime(_end.year, _end.month, _end.day, 23, 59);
    try {
      final created = await context.read<MerchantOfferRepository>().create(
        accessToken: merchantAccessToken(context) ?? '',
        draft: MerchantOfferDraft(
          name: _name.text,
          code: _code.text.trim().isEmpty ? null : _code.text.trim(),
          kind: _kind,
          discountValue: _num(_value)!,
          maxDiscountVnd: _kind == StoreOfferKind.percentage
              ? _num(_max)
              : null,
          minOrderVnd: _num(_min) ?? 0,
          usageLimit: _num(_usage)!,
          userLimit: _num(_perUser) ?? 1,
          startsAt: start,
          endsAt: end,
        ),
      );
      clearTextDraft();
      if (mounted) context.pop(created);
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorText(l10n, error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final date = DateFormat('dd/MM/yyyy');
    final percent = _kind == StoreOfferKind.percentage;
    String? required(String? v) =>
        (v ?? '').trim().isEmpty ? l10n.merchantOfferFieldRequired : null;
    String? positive(String? v, {int min = 1, int? max}) {
      final n = int.tryParse((v ?? '').trim());
      if (n == null || n < min || (max != null && n > max)) {
        return l10n.merchantOfferFieldInvalid;
      }
      return null;
    }

    final digits = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: MerchantPageFrame(
        title: l10n.merchantOfferNewTitle,
        onBack: () => merchantBack(context),
        body: Form(
          key: _form,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            padding: dealGoScrollPadding(
              context,
              const EdgeInsets.all(DealGoDimensions.pageGutter),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DealGoTextField(
                  label: l10n.merchantOfferFormName,
                  hint: 'VD: Giảm 20% combo trưa...',
                  controller: _name,
                  fieldKey: const Key('merchant-offer-name'),
                  maxLength: 80,
                  requiredMark: true,
                  textInputAction: TextInputAction.next,
                  validator: required,
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DealGoTextField(
                  label: l10n.merchantOfferFormCode,
                  hint: 'VD: COMBO20',
                  controller: _code,
                  fieldKey: const Key('merchant-offer-code'),
                  textCapitalization: TextCapitalization.characters,
                  maxLength: 20,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9_-]')),
                  ],
                  validator: (v) {
                    final t = (v ?? '').trim();
                    return t.isEmpty || t.length >= 3
                        ? null
                        : l10n.merchantOfferFieldInvalid;
                  },
                ),
                const SizedBox(height: DealGoSpacing.s12),
                SegmentedButton<StoreOfferKind>(
                  key: const Key('merchant-offer-kind'),
                  segments: [
                    ButtonSegment(
                      value: StoreOfferKind.percentage,
                      label: Text(l10n.merchantOfferKindPercent),
                    ),
                    ButtonSegment(
                      value: StoreOfferKind.fixedAmount,
                      label: Text(l10n.merchantOfferKindFixed),
                    ),
                  ],
                  selected: {_kind},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _kind = s.first);
                    markTextDraftDirty();
                  },
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DealGoTextField(
                        label: percent
                            ? l10n.merchantOfferFormPercent
                            : l10n.merchantOfferFormAmount,
                        hint: percent ? 'VD: 15' : 'VD: 20000',
                        controller: _value,
                        fieldKey: const Key('merchant-offer-value'),
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        requiredMark: true,
                        textInputAction: percent
                            ? TextInputAction.next
                            : TextInputAction.next,
                        validator: (v) => percent
                            ? positive(v, max: 100)
                            : positive(v, min: 1000),
                      ),
                    ),
                    if (percent) ...[
                      const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: DealGoTextField(
                          label: l10n.merchantOfferFormMax,
                          hint: 'VD: 30000',
                          controller: _max,
                          fieldKey: const Key('merchant-offer-max'),
                          keyboardType: TextInputType.number,
                          inputFormatters: digits,
                          requiredMark: true,
                          textInputAction: TextInputAction.next,
                          validator: (v) => positive(v, min: 1000),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                DealGoTextField(
                  label: l10n.merchantOfferFormMinOrder,
                  hint: '0',
                  controller: _min,
                  fieldKey: const Key('merchant-offer-min'),
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim()) ?? 0;
                    final value = _num(_value) ?? 0;
                    return !percent && n < value
                        ? l10n.merchantOfferMinBelowValue
                        : null;
                  },
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DealGoTextField(
                        label: l10n.merchantOfferFormUsage,
                        hint: '100',
                        controller: _usage,
                        fieldKey: const Key('merchant-offer-usage'),
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        textInputAction: TextInputAction.next,
                        validator: (v) => positive(v, max: 100000),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s12),
                    Expanded(
                      child: DealGoTextField(
                        label: l10n.merchantOfferFormPerUser,
                        hint: '1',
                        controller: _perUser,
                        fieldKey: const Key('merchant-offer-per-user'),
                        keyboardType: TextInputType.number,
                        inputFormatters: digits,
                        textInputAction: TextInputAction.done,
                        validator: (v) => positive(v, max: 50),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s12),
                Row(
                  children: [
                    for (final (index, start) in [true, false].indexed) ...[
                      if (index > 0) const SizedBox(width: DealGoSpacing.s12),
                      Expanded(
                        child: InkWell(
                          key: Key('merchant-offer-${start ? 'start' : 'end'}'),
                          borderRadius: BorderRadius.circular(DealGoRadius.input),
                          onTap: () => _pickDate(start: start),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: start
                                  ? l10n.merchantOfferFormStart
                                  : l10n.merchantOfferFormEnd,
                              prefixIcon: const Icon(DealGoIcons.calendar),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                  DealGoRadius.input,
                                ),
                              ),
                            ),
                            child: Text(
                              date.format(start ? _start : _end),
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: DealGoSpacing.s12),
                  MerchantNote(tone: MerchantNoteTone.warning, message: _error!),
                ],
              ],
            ),
          ),
        ),
        footer: MerchantPrimaryBar(
          label: l10n.merchantOfferSave,
          buttonKey: const Key('merchant-offer-save'),
          loading: _saving,
          enabled: !_saving,
          onPressed: _save,
        ),
      ),
    );
  }
}
