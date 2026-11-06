import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_chip.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';
import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../identity/domain/entities/auth_state.dart';
import '../../../identity/presentation/cubit/auth_cubit.dart';
import '../../../payment/presentation/payment_method_sheet.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/presentation/cubit/ride_session.dart';
import '../../../ride/domain/ride_fare_presets.dart';
import '../../../ride/presentation/utils/ride_routes.dart';
import '../../../ride/presentation/widgets/ride_fare_raise_chips.dart';
import '../../../ride/presentation/widgets/ride_widgets.dart'
    show RideTripSummary, rideAccessToken;
import '../../data/contact_picker.dart';
import '../../domain/parcel_client.dart';
import '../../domain/parcel_models.dart';
import '../cubit/parcel_booking_cubit.dart';
import '../widgets/parcel_labels.dart';

/// Stand-alone route (deep links / old callers). The booking hot path embeds
/// [ParcelDetailsPanel] in the map sheet instead of pushing this page.
class ParcelDetailsPage extends StatelessWidget {
  const ParcelDetailsPage({required this.places, super.key});

  final RidePlaces places;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.parcelDetailsTitle)),
      body: SafeArea(child: ParcelDetailsPanel(places: places)),
    );
  }
}

/// Package sheet after A→B (DEC-PROD-071), one screen: size chips priced by
/// the server as soon as A/B are known, sender prefilled from the signed-in
/// account, recipient from the system contact picker, payer/payment defaults.
class ParcelDetailsPanel extends StatelessWidget {
  const ParcelDetailsPanel({
    required this.places,
    this.scrollController,
    this.onEditRoute,
    super.key,
  });

  final RidePlaces places;
  final ScrollController? scrollController;
  final VoidCallback? onEditRoute;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBookingCubit(
        client: context.read<ParcelClient>(),
        accessToken: () => rideAccessToken(context),
      )..start(places),
      child: _ParcelDetailsView(
        places: places,
        scrollController: scrollController,
        onEditRoute: onEditRoute,
      ),
    );
  }
}

class _ParcelDetailsView extends StatefulWidget {
  const _ParcelDetailsView({
    required this.places,
    this.scrollController,
    this.onEditRoute,
  });

  final RidePlaces places;
  final ScrollController? scrollController;
  final VoidCallback? onEditRoute;

  @override
  State<_ParcelDetailsView> createState() => _ParcelDetailsViewState();
}

class _ParcelDetailsViewState extends State<_ParcelDetailsView> {
  final _form = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _note = TextEditingController();
  final _senderName = TextEditingController();
  final _senderPhone = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  var _payer = ParcelPayer.sender;
  var _method = 'CASH';
  ParcelPhoto? _photo;
  var _editSender = false;

  @override
  void initState() {
    super.initState();
    _prefillSender();
    _weight.addListener(_weightChanged);
  }

  /// Sender = the signed-in customer (editable, rarely changed).
  void _prefillSender() {
    AuthState? auth;
    try {
      auth = context.read<AuthCubit>().state;
    } on ProviderNotFoundException {
      auth = null;
    }
    if (auth is! AuthSignedIn) {
      _editSender = true;
      return;
    }
    final p = auth.profile;
    _senderName.text = p.displayName.trim();
    _senderPhone.text = normalizeVnPhone(
      (p.phone?.trim().isNotEmpty ?? false) ? p.phone! : (p.contactPhone ?? ''),
    );
    _editSender =
        _senderName.text.isEmpty || !isValidParcelPhone(_senderPhone.text);
  }

  void _weightChanged() {
    final raw = _weight.text.trim();
    context.read<ParcelBookingCubit>().setWeight(
      raw.isEmpty ? null : _weightKg,
    );
  }

  Future<void> _pickRecipient() async {
    ContactPicker picker;
    try {
      picker = context.read<ContactPicker>();
    } on ProviderNotFoundException {
      picker = NativeContactPicker();
    }
    PickedContact? picked;
    try {
      picked = await picker.pickPhone();
    } catch (_) {
      picked = null;
    }
    if (picked == null || !mounted) return;
    setState(() {
      _recipientPhone.text = picked!.phone;
      if (picked.name.isNotEmpty) _recipientName.text = picked.name;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _weight,
      _note,
      _senderName,
      _senderPhone,
      _recipientName,
      _recipientPhone,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? get _weightKg =>
      double.tryParse(_weight.text.trim().replaceAll(',', '.'));

  ParcelDraft? _draft() {
    final size = context.read<ParcelBookingCubit>().state.sizeCode;
    if (size == null || !(_form.currentState?.validate() ?? false)) return null;
    return ParcelDraft(
      places: widget.places,
      sizeClass: size,
      weightKg: _weightKg,
      note: _note.text,
      payer: _payer,
      paymentMethod: _payer == ParcelPayer.recipient ? 'CASH' : _method,
      itemPhoto: _photo,
      sender: ParcelContact(name: _senderName.text, phone: _senderPhone.text),
      recipient: ParcelContact(
        name: _recipientName.text,
        phone: _recipientPhone.text,
      ),
    );
  }

  Future<void> _quote() async {
    await context.read<ParcelBookingCubit>().autoQuote();
  }

  Future<void> _submit() async {
    final draft = _draft();
    if (draft == null) return;
    final ride = await context.read<ParcelBookingCubit>().submit(draft);
    if (!mounted || ride == null) return;
    context.read<RideSessionCubit>().remember(ride.ride.id);
    await context.push(
      ride.ride.status.hasDriver
          ? RideRoutes.tracking(ride.ride.id)
          : RideRoutes.matching(ride.ride.id),
    );
  }

  Future<void> _pickPhoto() async {
    final picked = await context.read<DocumentImageSource>().pick(camera: true);
    if (picked == null || !mounted) return;
    setState(
      () => _photo = ParcelPhoto(
        bytes: picked.bytes,
        contentType: picked.contentType,
      ),
    );
  }

  String? _required(String? v) => (v ?? '').trim().isEmpty
      ? AppLocalizations.of(context).parcelFieldRequired
      : null;

  String? _phone(String? v) => isValidParcelPhone(v ?? '')
      ? null
      : AppLocalizations.of(context).parcelPhoneInvalid;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final state = context.watch<ParcelBookingCubit>().state;
    final size = state.size;
    final option = state.option;
    final cubit = context.read<ParcelBookingCubit>();
    const gap = SizedBox(height: DealGoSpacing.s12);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Form(
      key: _form,
      // ListTiles/ExpansionTile need a Material ancestor for ink.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            // Fixed sheet header: content scrolls under it, never under the
            // rounded sheet edge.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                DealGoSpacing.s16,
                DealGoSpacing.s12,
                DealGoSpacing.s8,
                DealGoSpacing.s4,
              ),
              child: Column(
                children: [
                  const SizedBox(height: DealGoSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.parcelDetailsTitle,
                          key: const Key('parcel-sheet-title'),
                          style: text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (widget.onEditRoute != null)
                        TextButton(
                          key: const Key('parcel-edit-route'),
                          onPressed: widget.onEditRoute,
                          child: Text(l10n.parcelEditRoute),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: DealGoColors.divider),
            Expanded(
              child: ListView(
                controller: widget.scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  DealGoSpacing.s16,
                  DealGoSpacing.s16,
                  DealGoSpacing.s16,
                  DealGoSpacing.s24 + keyboard,
                ),
                children: [
                  // Route + trip summary (server distance/time).
                  _RouteCard(
                    pickup: widget.places.pickup.label,
                    dropoff: widget.places.dropoff.label,
                    summary: RideTripSummary(
                      distanceKm: state.quote?.distanceKm,
                      durationMin: option?.durationMin,
                    ),
                  ),

                  // ── Gói hàng ────────────────────────────────────────
                  _SectionHeader(
                    icon: DealGoIcons.package,
                    title: l10n.parcelSectionPackage,
                  ),
                  if (state.status == ParcelBookingStatus.loading &&
                      state.sizes.isEmpty)
                    const LinearProgressIndicator()
                  else
                    Row(
                      children: [
                        for (var i = 0; i < state.sizes.length; i++) ...[
                          if (i > 0) const SizedBox(width: DealGoSpacing.s8),
                          Expanded(
                            child: _SizeTile(
                              key: Key('parcel-size-${state.sizes[i].code}'),
                              code: state.sizes[i].code,
                              label: parcelSizeLabel(l10n, state.sizes[i].code),
                              weight:
                                  '≤${state.sizes[i].maxWeightKg.toStringAsFixed(0)}kg',
                              selected: state.sizes[i].code == state.sizeCode,
                              onTap: () =>
                                  cubit.selectSize(state.sizes[i].code),
                            ),
                          ),
                        ],
                      ],
                    ),
                  if (size != null)
                    Padding(
                      padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                      child: Text(
                        l10n.parcelSizeHint(size.dimsLabel),
                        style: text.bodySmall?.copyWith(
                          color: DealGoColors.textSecondary,
                        ),
                      ),
                    ),
                  if (state.status == ParcelBookingStatus.quoting) ...[
                    gap,
                    Row(
                      key: const Key('parcel-pricing'),
                      children: [
                        const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: DealGoSpacing.s8),
                        Text(l10n.parcelPricing, style: text.bodyMedium),
                      ],
                    ),
                  ],
                  if (state.quote != null)
                    for (final o in state.quote!.options) ...[
                      gap,
                      _OptionTile(
                        key: Key('parcel-option-${o.code}'),
                        selected: o.code == state.optionCode,
                        title: o.name,
                        price: formatRideVnd(o.referenceFareVnd),
                        detail: Text(
                          [
                            l10n.parcelOptionHint(
                              formatRideVnd(o.minBidVnd),
                              formatRideVnd(o.maxBidVnd),
                            ),
                            if (o.serviceFeeVnd > 0)
                              l10n.parcelServiceFeeLine(
                                formatRideVnd(o.serviceFeeVnd),
                              ),
                            if (o.returnFeeVnd > 0)
                              l10n.parcelReturnFeeLine(
                                formatRideVnd(o.returnFeeVnd),
                              ),
                          ].join('\n'),
                          key: Key('parcel-option-fees-${o.code}'),
                          style: text.bodySmall?.copyWith(
                            color: DealGoColors.textSecondary,
                          ),
                        ),
                        onTap: () => cubit.selectOption(o.code),
                      ),
                    ],
                  if (option != null && state.fareVnd != null) ...[
                    gap,
                    _FareStepper(
                      amount: formatRideVnd(state.fareVnd!),
                      onMinus: () =>
                          cubit.setFare(state.fareVnd! - option.fareStepVnd),
                      onPlus: () =>
                          cubit.setFare(state.fareVnd! + option.fareStepVnd),
                    ),
                    const SizedBox(height: DealGoSpacing.s8),
                    RideFareRaiseChips(
                      keyPrefix: 'parcel-fare-preset',
                      presets: rideFareRaisePresets(
                        suggestedVnd: option.referenceFareVnd,
                        minBidVnd: option.minBidVnd,
                        maxBidVnd: option.maxBidVnd,
                        maxHeadroomPercent: option.bidHeadroomPercent,
                        stepVnd: option.fareStepVnd,
                      ),
                      selectedVnd: state.fareVnd,
                      onPick: cubit.setFare,
                    ),
                  ],
                  if (state.errorCode != null) ...[
                    gap,
                    Text(
                      parcelErrorLabel(l10n, state.errorCode),
                      key: const Key('parcel-booking-error'),
                      style: text.bodyMedium?.copyWith(
                        color: DealGoColors.danger,
                      ),
                    ),
                  ],

                  // ── Người nhận ──────────────────────────────────────
                  _SectionHeader(
                    icon: DealGoIcons.userRound,
                    title: l10n.parcelRecipientTitle,
                  ),
                  TextFormField(
                    key: const Key('parcel-recipient-phone'),
                    controller: _recipientPhone,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                      LengthLimitingTextInputFormatter(13),
                    ],
                    decoration: InputDecoration(
                      labelText: l10n.parcelPhoneLabel,
                      hintText: l10n.parcelPhoneHint,
                      prefixIcon: const Icon(DealGoIcons.phone, size: 20),
                      suffixIcon: IconButton(
                        key: const Key('parcel-pick-contact'),
                        tooltip: l10n.parcelPickContact,
                        icon: const Icon(
                          Icons.contacts_outlined,
                          color: DealGoColors.primary,
                        ),
                        onPressed: _pickRecipient,
                      ),
                    ),
                    validator: _phone,
                  ),
                  gap,
                  TextFormField(
                    key: const Key('parcel-recipient-name'),
                    controller: _recipientName,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: l10n.parcelNameLabel,
                      prefixIcon: const Icon(DealGoIcons.user, size: 20),
                    ),
                    validator: _required,
                  ),

                  // ── Người gửi ───────────────────────────────────────
                  _SectionHeader(
                    icon: DealGoIcons.send,
                    title: l10n.parcelSenderTitle,
                  ),
                  if (_editSender) ...[
                    TextFormField(
                      key: const Key('parcel-sender-name'),
                      controller: _senderName,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: l10n.parcelNameLabel,
                        prefixIcon: const Icon(DealGoIcons.user, size: 20),
                      ),
                      validator: _required,
                    ),
                    gap,
                    TextFormField(
                      key: const Key('parcel-sender-phone'),
                      controller: _senderPhone,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                        LengthLimitingTextInputFormatter(13),
                      ],
                      decoration: InputDecoration(
                        labelText: l10n.parcelPhoneLabel,
                        hintText: l10n.parcelPhoneHint,
                        prefixIcon: const Icon(DealGoIcons.phone, size: 20),
                      ),
                      validator: _phone,
                    ),
                  ] else
                    _SenderCard(
                      key: const Key('parcel-sender-summary'),
                      name: _senderName.text,
                      phone: _senderPhone.text,
                      badge: l10n.parcelSenderYou,
                      editLabel: l10n.parcelEdit,
                      onEdit: () => setState(() => _editSender = true),
                    ),

                  // ── Thanh toán ──────────────────────────────────────
                  _SectionHeader(
                    icon: DealGoIcons.wallet,
                    title: l10n.parcelSectionPayment,
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ParcelPayer>(
                      key: const Key('parcel-payer'),
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: ParcelPayer.sender,
                          label: Text(
                            l10n.parcelPayerSender,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                        ButtonSegment(
                          value: ParcelPayer.recipient,
                          label: Text(
                            l10n.parcelPayerRecipient,
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ],
                      selected: {_payer},
                      onSelectionChanged: (v) =>
                          setState(() => _payer = v.first),
                    ),
                  ),
                  // Sender pays like a checkout (methods the admin enabled
                  // for PARCEL); recipient pays the driver cash on delivery.
                  if (_payer == ParcelPayer.recipient) ...[
                    const SizedBox(height: DealGoSpacing.s8),
                    Text(
                      l10n.parcelPayerRecipientNote,
                      key: const Key('parcel-payer-note'),
                      style: text.bodySmall?.copyWith(
                        color: DealGoColors.textSecondary,
                      ),
                    ),
                  ],
                  if (_payer == ParcelPayer.sender) ...[
                    gap,
                    PaymentMethodTile(
                      key: const Key('parcel-payment-method'),
                      service: 'PARCEL',
                      selected: _method,
                      onChanged: (m) => setState(() => _method = m.code),
                    ),
                  ],
                  gap,
                  Theme(
                    data: Theme.of(context)
                        .copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      key: const Key('parcel-more'),
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: const EdgeInsets.only(
                        bottom: DealGoSpacing.s12,
                      ),
                      title: Text(
                        l10n.parcelMoreDetails,
                        style: text.titleSmall?.copyWith(
                          color: DealGoColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      children: [
                        TextFormField(
                          key: const Key('parcel-weight'),
                          controller: _weight,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: l10n.parcelWeightLabel,
                            suffixText: 'kg',
                          ),
                          validator: (v) {
                            if ((v ?? '').trim().isEmpty || size == null) {
                              return null;
                            }
                            final w = _weightKg;
                            if (w == null || w <= 0) {
                              return l10n.parcelWeightInvalid;
                            }
                            final limit = parcelWeightOverLimit(size, w);
                            return limit == null
                                ? null
                                : l10n.parcelWeightOver(
                                    limit.toStringAsFixed(0),
                                  );
                          },
                        ),
                        gap,
                        TextFormField(
                          key: const Key('parcel-note'),
                          controller: _note,
                          maxLength: 300,
                          minLines: 1,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: l10n.parcelNoteLabel,
                          ),
                        ),
                        DealGoSecondaryButton(
                          key: const Key('parcel-item-photo'),
                          label: _photo == null
                              ? l10n.parcelItemPhotoAdd
                              : l10n.parcelItemPhotoAdded,
                          onPressed: _pickPhoto,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Sticky CTA with the price; safe-area aware.
            DecoratedBox(
              decoration: BoxDecoration(
                color: DealGoColors.card,
                border: Border(top: BorderSide(color: DealGoColors.divider)),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DealGoSpacing.s16,
                  DealGoSpacing.s12,
                  DealGoSpacing.s16,
                  dealGoStickyFooterBottom(context),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: state.quote == null || option == null
                          ? DealGoPrimaryButton(
                              key: const Key('parcel-quote'),
                              label: l10n.parcelQuoteCta,
                              isLoading:
                                  state.status == ParcelBookingStatus.quoting,
                              enabled: !state.busy && state.sizeCode != null,
                              onPressed: _quote,
                            )
                          : DealGoPrimaryButton(
                              key: const Key('parcel-submit'),
                              label: state.fareVnd == null
                                  ? l10n.parcelSubmitCta
                                  : l10n.parcelSubmitWithPrice(
                                      formatRideVnd(state.fareVnd!),
                                    ),
                              isLoading:
                                  state.status ==
                                  ParcelBookingStatus.submitting,
                              enabled: !state.busy,
                              onPressed: _submit,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: DealGoSpacing.s24,
        bottom: DealGoSpacing.s12,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DealGoColors.primary),
          const SizedBox(width: DealGoSpacing.s8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    required this.pickup,
    required this.dropoff,
    required this.summary,
  });

  final String pickup;
  final String dropoff;
  final Widget summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget line(Color dot, String label) => Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: DealGoSpacing.s12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  line(DealGoColors.brandGreen, pickup),
                  const SizedBox(height: DealGoSpacing.s8),
                  line(DealGoColors.danger, dropoff),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: DealGoSpacing.s12),
        summary,
      ],
    );
  }
}

class _SizeTile extends StatelessWidget {
  const _SizeTile({
    required this.code,
    required this.label,
    required this.weight,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String code;
  final String label;
  final String weight;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = selected ? DealGoColors.primary : DealGoColors.text;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          side: BorderSide(
            color: selected ? DealGoColors.primary : DealGoColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(DealGoRadius.input),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: DealGoSpacing.s8,
              horizontal: DealGoSpacing.s4,
            ),
            child: Column(
              children: [
                Text(
                  code,
                  style: text.titleMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall?.copyWith(color: fg),
                ),
                Text(
                  weight,
                  style: text.labelSmall?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.selected,
    required this.title,
    required this.price,
    required this.detail,
    required this.onTap,
    super.key,
  });

  final bool selected;
  final String title;
  final String price;
  final Widget detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: selected ? DealGoColors.subtlePurple : DealGoColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        side: BorderSide(
          color: selected ? DealGoColors.primary : DealGoColors.border,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(DealGoSpacing.s12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected ? DealGoIcons.radioOn : DealGoIcons.radioOff,
                size: 20,
                color: selected
                    ? DealGoColors.primary
                    : DealGoColors.textTertiary,
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: DealGoSpacing.s4),
                    detail,
                  ],
                ),
              ),
              const SizedBox(width: DealGoSpacing.s12),
              Text(
                price,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FareStepper extends StatelessWidget {
  const _FareStepper({
    required this.amount,
    required this.onMinus,
    required this.onPlus,
  });

  final String amount;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    Widget step(Key key, IconData icon, VoidCallback onTap) => Material(
      color: DealGoColors.card,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        key: key,
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: DealGoDimensions.minTapTarget,
          child: Icon(icon, color: DealGoColors.primary, size: 22),
        ),
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DealGoColors.subtlePurple,
        borderRadius: BorderRadius.circular(DealGoRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DealGoSpacing.s12),
        child: Row(
          children: [
            step(const Key('parcel-fare-down'), DealGoIcons.remove, onMinus),
            const SizedBox(width: DealGoSpacing.s16),
            Expanded(
              child: Text(
                amount,
                key: const Key('parcel-fare'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: DealGoColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: DealGoSpacing.s16),
            step(const Key('parcel-fare-up'), DealGoIcons.add, onPlus),
          ],
        ),
      ),
    );
  }
}

class _SenderCard extends StatelessWidget {
  const _SenderCard({
    required this.name,
    required this.phone,
    required this.badge,
    required this.editLabel,
    required this.onEdit,
    super.key,
  });

  final String name;
  final String phone;
  final String badge;
  final String editLabel;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        DealGoSpacing.s12,
        DealGoSpacing.s12,
        DealGoSpacing.s4,
        DealGoSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: DealGoColors.lavender,
        borderRadius: BorderRadius.circular(DealGoRadius.input),
        border: Border.all(color: DealGoColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: DealGoColors.subtlePurple,
            child: Text(
              name.isEmpty ? '?' : name.characters.first.toUpperCase(),
              style: text.titleMedium?.copyWith(
                color: DealGoColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: DealGoSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: DealGoSpacing.s8),
                    DealGoChip(label: badge, tone: DealGoChipTone.brand),
                  ],
                ),
                const SizedBox(height: DealGoSpacing.s2),
                Text(
                  phone,
                  style: text.bodyMedium?.copyWith(
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('parcel-sender-edit'),
            onPressed: onEdit,
            child: Text(editLabel),
          ),
        ],
      ),
    );
  }
}
