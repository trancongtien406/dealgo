import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../../core/design_system/components/dealgo_secondary_button.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../payment/presentation/payment_method_sheet.dart';
import '../../../onboarding/presentation/document_image_source.dart';
import '../../../ride/domain/entities/ride_models.dart';
import '../../../ride/domain/entities/ride_money.dart';
import '../../../ride/presentation/cubit/ride_session.dart';
import '../../../ride/presentation/utils/ride_routes.dart';
import '../../../ride/presentation/widgets/ride_widgets.dart'
    show rideAccessToken;
import '../../domain/parcel_client.dart';
import '../../domain/parcel_models.dart';
import '../cubit/parcel_booking_cubit.dart';
import '../widgets/parcel_labels.dart';

/// Package sheet after the A→B map (DEC-PROD-071): size, weight, people, payer,
/// optional photo → quote → class + offer → waiting for driver offers (ride flow).
class ParcelDetailsPage extends StatelessWidget {
  const ParcelDetailsPage({required this.places, super.key});

  final RidePlaces places;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBookingCubit(
        client: context.read<ParcelClient>(),
        accessToken: () => rideAccessToken(context),
      )..load(),
      child: _ParcelDetailsView(places: places),
    );
  }
}

class _ParcelDetailsView extends StatefulWidget {
  const _ParcelDetailsView({required this.places});

  final RidePlaces places;

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

  /// Any edit after a quote invalidates it: re-quote before booking.
  void _changed() {
    context.read<ParcelBookingCubit>().invalidateQuote();
  }

  Future<void> _quote() async {
    final draft = _draft();
    if (draft != null) await context.read<ParcelBookingCubit>().quote(draft);
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
    const gap = SizedBox(height: DealGoSpacing.s12);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.parcelDetailsTitle)),
      body: SafeArea(
        child: Form(
          key: _form,
          onChanged: _changed,
          child: ListView(
            padding: const EdgeInsets.all(DealGoSpacing.s16),
            children: [
              Text(
                '${widget.places.pickup.label} → ${widget.places.dropoff.label}',
                style: text.bodyMedium,
              ),
              gap,
              Text(l10n.parcelSizeTitle, style: text.titleMedium),
              const SizedBox(height: DealGoSpacing.s8),
              if (state.status == ParcelBookingStatus.loading &&
                  state.sizes.isEmpty)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: DealGoSpacing.s8,
                  runSpacing: DealGoSpacing.s8,
                  children: [
                    for (final s in state.sizes)
                      ChoiceChip(
                        key: Key('parcel-size-${s.code}'),
                        label: Text(
                          '${parcelSizeLabel(l10n, s.code)} · ≤${s.maxWeightKg.toStringAsFixed(0)}kg',
                        ),
                        selected: s.code == state.sizeCode,
                        onSelected: (_) => context
                            .read<ParcelBookingCubit>()
                            .selectSize(s.code),
                      ),
                  ],
                ),
              if (size != null)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s4),
                  child: Text(
                    l10n.parcelSizeHint(size.dimsLabel),
                    style: text.bodySmall,
                  ),
                ),
              gap,
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
                  if ((v ?? '').trim().isEmpty || size == null) return null;
                  final w = _weightKg;
                  if (w == null || w <= 0) return l10n.parcelWeightInvalid;
                  final limit = parcelWeightOverLimit(size, w);
                  return limit == null
                      ? null
                      : l10n.parcelWeightOver(limit.toStringAsFixed(0));
                },
              ),
              TextFormField(
                key: const Key('parcel-note'),
                controller: _note,
                maxLength: 300,
                decoration: InputDecoration(labelText: l10n.parcelNoteLabel),
              ),
              Text(l10n.parcelSenderTitle, style: text.titleMedium),
              TextFormField(
                key: const Key('parcel-sender-name'),
                controller: _senderName,
                decoration: InputDecoration(labelText: l10n.parcelNameLabel),
                validator: _required,
              ),
              TextFormField(
                key: const Key('parcel-sender-phone'),
                controller: _senderPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.parcelPhoneLabel),
                validator: _phone,
              ),
              gap,
              Text(l10n.parcelRecipientTitle, style: text.titleMedium),
              TextFormField(
                key: const Key('parcel-recipient-name'),
                controller: _recipientName,
                decoration: InputDecoration(labelText: l10n.parcelNameLabel),
                validator: _required,
              ),
              TextFormField(
                key: const Key('parcel-recipient-phone'),
                controller: _recipientPhone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: l10n.parcelPhoneLabel),
                validator: _phone,
              ),
              gap,
              SegmentedButton<ParcelPayer>(
                key: const Key('parcel-payer'),
                segments: [
                  ButtonSegment(
                    value: ParcelPayer.sender,
                    label: Text(l10n.parcelPayerSender),
                  ),
                  ButtonSegment(
                    value: ParcelPayer.recipient,
                    label: Text(l10n.parcelPayerRecipient),
                  ),
                ],
                selected: {_payer},
                onSelectionChanged: (v) {
                  setState(() => _payer = v.first);
                  _changed();
                },
              ),
              // Sender pays like a checkout (methods the admin enabled for PARCEL);
              // recipient pays the driver in cash on delivery.
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
              DealGoSecondaryButton(
                key: const Key('parcel-item-photo'),
                label: _photo == null
                    ? l10n.parcelItemPhotoAdd
                    : l10n.parcelItemPhotoAdded,
                onPressed: _pickPhoto,
              ),
              if (state.errorCode != null) ...[
                gap,
                Text(
                  parcelErrorLabel(l10n, state.errorCode),
                  key: const Key('parcel-booking-error'),
                  style: text.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (state.quote != null) ...[
                gap,
                Text(l10n.parcelVehicleTitle, style: text.titleMedium),
                for (final o in state.quote!.options)
                  ListTile(
                    key: Key('parcel-option-${o.code}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      o.code == state.optionCode
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                    ),
                    title: Text(o.name),
                    subtitle: Text(
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
                    ),
                    trailing: Text(formatRideVnd(o.referenceFareVnd)),
                    onTap: () =>
                        context.read<ParcelBookingCubit>().selectOption(o.code),
                  ),
                if (option != null && state.fareVnd != null)
                  Row(
                    children: [
                      IconButton(
                        key: const Key('parcel-fare-down'),
                        onPressed: () => context
                            .read<ParcelBookingCubit>()
                            .setFare(state.fareVnd! - 1000),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Expanded(
                        child: Text(
                          formatRideVnd(state.fareVnd!),
                          key: const Key('parcel-fare'),
                          textAlign: TextAlign.center,
                          style: text.headlineSmall,
                        ),
                      ),
                      IconButton(
                        key: const Key('parcel-fare-up'),
                        onPressed: () => context
                            .read<ParcelBookingCubit>()
                            .setFare(state.fareVnd! + 1000),
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(DealGoSpacing.s16),
        child: state.quote == null || option == null
            ? DealGoPrimaryButton(
                key: const Key('parcel-quote'),
                label: l10n.parcelQuoteCta,
                isLoading: state.status == ParcelBookingStatus.quoting,
                enabled: !state.busy && state.sizeCode != null,
                onPressed: _quote,
              )
            : DealGoPrimaryButton(
                key: const Key('parcel-submit'),
                label: l10n.parcelSubmitCta,
                isLoading: state.status == ParcelBookingStatus.submitting,
                enabled: !state.busy,
                onPressed: _submit,
              ),
      ),
    );
  }
}
