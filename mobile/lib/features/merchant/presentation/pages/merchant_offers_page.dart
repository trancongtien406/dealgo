import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/components/dealgo_dialog.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/components/dealgo_text_field.dart';
import '../../../../core/design_system/components/dealgo_voucher_ticket.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/drafts/text_draft.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../core/motion/dealgo_motion_widgets.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../food/domain/entities/food_money.dart';
import '../../../food/presentation/widgets/store_meta.dart';
import '../../domain/merchant_offers.dart';
import '../utils/merchant_routes.dart';
import '../widgets/merchant_widgets.dart';

StoreOffer _asStoreOffer(MerchantOffer offer) => StoreOffer(
  id: offer.id,
  code: offer.code,
  name: offer.name,
  kind: offer.kind,
  discountValue: offer.discountValue,
  maxDiscountVnd: offer.maxDiscountVnd,
  minOrderVnd: offer.minOrderVnd,
  endsAt: offer.endsAt,
);

/// M040 — the store's own offers: list, pause / resume / end, create.
class MerchantOffersPage extends StatefulWidget {
  const MerchantOffersPage({super.key});

  @override
  State<MerchantOffersPage> createState() => _MerchantOffersPageState();
}

class _MerchantOffersPageState extends State<MerchantOffersPage> {
  List<MerchantOffer>? _offers;
  Object? _error;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final offers = await context.read<MerchantOfferRepository>().list(
        accessToken: merchantAccessToken(context) ?? '',
      );
      if (mounted) setState(() => _offers = offers);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _create() async {
    final created = await context.push<MerchantOffer>(MerchantRoutes.offerNew);
    if (created != null && mounted) {
      setState(() => _offers = [created, ...?_offers]);
    }
  }

  Future<void> _setStatus(MerchantOffer offer, MerchantOfferStatus to) async {
    final l10n = AppLocalizations.of(context);
    if (to == MerchantOfferStatus.ended) {
      final ok = await showDealGoConfirmDialog(
        context: context,
        title: l10n.merchantOfferEndConfirm(offer.name),
        confirmLabel: l10n.merchantOfferEnd,
        cancelLabel: l10n.actionCancel,
        confirmTone: DealGoDialogPrimaryTone.danger,
        confirmKey: const Key('merchant-offer-end-confirm'),
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busyId = offer.id);
    try {
      final updated = await context.read<MerchantOfferRepository>().setStatus(
        accessToken: merchantAccessToken(context) ?? '',
        offerId: offer.id,
        status: to,
      );
      if (!mounted) return;
      setState(() {
        _offers = [
          for (final o in _offers ?? const <MerchantOffer>[])
            o.id == updated.id ? updated : o,
        ];
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(apiErrorText(l10n, error))));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final offers = _offers;
    final now = DateTime.now();
    final live = offers?.where((o) => o.isLive(now)).length ?? 0;
    final full = live >= merchantOfferLiveLimit;
    final Widget body;
    if (_error != null && offers == null) {
      body = DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _error,
        message: apiErrorText(l10n, _error),
      );
    } else if (offers == null) {
      body = const DealGoSkeletonList(itemCount: 3);
    } else if (offers.isEmpty) {
      body = Center(
        child: Text(
          l10n.merchantOffersEmpty,
          key: const Key('merchant-offers-empty'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.separated(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          itemCount: offers.length + (full ? 1 : 0),
          separatorBuilder: (context, index) =>
              const SizedBox(height: DealGoSpacing.s12),
          itemBuilder: (context, index) {
            if (full && index == 0) {
              return MerchantNote(
                tone: MerchantNoteTone.warning,
                message: l10n.merchantOfferLimitReached(merchantOfferLiveLimit),
              );
            }
            final offer = offers[index - (full ? 1 : 0)];
            return DealGoStaggerIn(
              index: index,
              child: _OfferCard(
                offer: offer,
                now: now,
                busy: _busyId == offer.id,
                onStatus: (to) => _setStatus(offer, to),
              ),
            );
          },
        ),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantOffersTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: offers == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantOffersCreate,
              buttonKey: const Key('merchant-offer-create'),
              enabled: !full,
              onPressed: _create,
            ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.now,
    required this.busy,
    required this.onStatus,
  });

  final MerchantOffer offer;
  final DateTime now;
  final bool busy;
  final ValueChanged<MerchantOfferStatus> onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final date = DateFormat('dd/MM/yyyy');
    final live = offer.isLive(now);
    final (statusLabel, tone) = !live
        ? (l10n.merchantOfferStatusEnded, MerchantChipTone.neutral)
        : offer.status == MerchantOfferStatus.paused
        ? (l10n.merchantOfferStatusPaused, MerchantChipTone.warning)
        : offer.isUpcoming(now)
        ? (l10n.merchantOfferStatusUpcoming, MerchantChipTone.neutral)
        : (l10n.merchantOfferStatusActive, MerchantChipTone.green);
    final used = offer.usageLimit > 0
        ? (offer.usedCount / offer.usageLimit).clamp(0.0, 1.0)
        : 0.0;
    final cap = offer.maxDiscountVnd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DealGoVoucherTicket(
          key: Key('merchant-offer-${offer.id}'),
          headline: storeOfferHeadline(l10n, _asStoreOffer(offer)),
          caption: offer.code,
          title: offer.name,
          accent: DealGoColors.danger,
          dimmed: !live,
          conditions: [
            if (offer.minOrderVnd > 0)
              l10n.voucherMinOrder(formatVnd(offer.minOrderVnd)),
            if (offer.kind == StoreOfferKind.percentage && cap != null)
              l10n.voucherCap(formatVnd(cap)),
            '${date.format(offer.startsAt)} – ${date.format(offer.endsAt)}',
          ],
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MerchantChip(label: statusLabel, tone: tone),
              const SizedBox(height: DealGoSpacing.s8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: used,
                  minHeight: 6,
                  color: DealGoColors.danger,
                  backgroundColor: DealGoColors.dangerSurface,
                ),
              ),
              const SizedBox(height: DealGoSpacing.s4),
              Text(
                l10n.merchantOfferUsage(offer.usedCount, offer.usageLimit),
                style: textTheme.labelSmall,
              ),
            ],
          ),
        ),
        if (live) ...[
          const SizedBox(height: DealGoSpacing.s12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: DealGoSecondaryButton(
                    key: Key('merchant-offer-toggle-${offer.id}'),
                    compact: true,
                    label: offer.status == MerchantOfferStatus.paused
                        ? l10n.merchantOfferResume
                        : l10n.merchantOfferPause,
                    enabled: !busy,
                    onPressed: () => onStatus(
                      offer.status == MerchantOfferStatus.paused
                          ? MerchantOfferStatus.active
                          : MerchantOfferStatus.paused,
                    ),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: DealGoSecondaryButton(
                    key: Key('merchant-offer-end-${offer.id}'),
                    compact: true,
                    tone: DealGoSecondaryTone.danger,
                    label: l10n.merchantOfferEnd,
                    enabled: !busy,
                    onPressed: () => onStatus(MerchantOfferStatus.ended),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

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
    final picked = await showDatePicker(
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
    return MerchantPageFrame(
      title: l10n.merchantOfferNewTitle,
      onBack: () => merchantBack(context),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(DealGoDimensions.pageGutter),
          children: [
            DealGoTextField(
              label: l10n.merchantOfferFormName,
              controller: _name,
              fieldKey: const Key('merchant-offer-name'),
              maxLength: 80,
              requiredMark: true,
              validator: required,
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantOfferFormCode,
              controller: _code,
              fieldKey: const Key('merchant-offer-code'),
              textCapitalization: TextCapitalization.characters,
              maxLength: 20,
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
                    controller: _value,
                    fieldKey: const Key('merchant-offer-value'),
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    requiredMark: true,
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
                      controller: _max,
                      fieldKey: const Key('merchant-offer-max'),
                      keyboardType: TextInputType.number,
                      inputFormatters: digits,
                      requiredMark: true,
                      validator: (v) => positive(v, min: 1000),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: DealGoSpacing.s12),
            DealGoTextField(
              label: l10n.merchantOfferFormMinOrder,
              controller: _min,
              fieldKey: const Key('merchant-offer-min'),
              keyboardType: TextInputType.number,
              inputFormatters: digits,
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
                    controller: _usage,
                    fieldKey: const Key('merchant-offer-usage'),
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
                    validator: (v) => positive(v, max: 100000),
                  ),
                ),
                const SizedBox(width: DealGoSpacing.s12),
                Expanded(
                  child: DealGoTextField(
                    label: l10n.merchantOfferFormPerUser,
                    controller: _perUser,
                    fieldKey: const Key('merchant-offer-per-user'),
                    keyboardType: TextInputType.number,
                    inputFormatters: digits,
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
      footer: MerchantPrimaryBar(
        label: l10n.merchantOfferSave,
        buttonKey: const Key('merchant-offer-save'),
        loading: _saving,
        enabled: !_saving,
        onPressed: _save,
      ),
    );
  }
}
