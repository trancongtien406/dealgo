import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_segmented_control.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/maps/map_lat_lng.dart';
import '../../../l10n/app_localizations.dart';
import '../../address_book/domain/entities/saved_address.dart';
import '../../places/presentation/map_pin_picker_page.dart';
import '../../places/presentation/place_picker_page.dart';
import 'saved_addresses_page.dart' show addressErrorText;

/// Bottom sheet to create or edit an address. Resolves `true` once saved.
Future<bool?> showAddressFormSheet(
  BuildContext context, {
  required Set<SavedAddressKind> takenKinds,
  required Future<String?> Function(SavedAddressDraft draft) onSubmit,
  SavedAddress? editing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: DealGoColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(DealGoRadius.card),
      ),
    ),
    builder: (_) => AddressFormSheet(
      editing: editing,
      takenKinds: takenKinds,
      onSubmit: onSubmit,
    ),
  );
}

class AddressFormSheet extends StatefulWidget {
  const AddressFormSheet({
    required this.takenKinds,
    required this.onSubmit,
    this.editing,
    super.key,
  });

  final SavedAddress? editing;
  final Set<SavedAddressKind> takenKinds;
  final Future<String?> Function(SavedAddressDraft draft) onSubmit;

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _line;
  late final TextEditingController _note;
  late SavedAddressKind _kind;
  late bool _makeDefault;
  double? _lat;
  double? _lng;
  var _locating = false;
  var _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    _kind = editing?.kind ?? _firstFreeKind();
    _label = TextEditingController(text: editing?.label ?? '');
    _line = TextEditingController(text: editing?.addressLine ?? '');
    _note = TextEditingController(text: editing?.note ?? '');
    _makeDefault = editing?.isDefault ?? false;
    _lat = editing?.lat;
    _lng = editing?.lng;
  }

  var _prefilled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_prefilled && widget.editing == null) {
      _prefilled = true;
      _label.text = _defaultLabel(AppLocalizations.of(context), _kind);
    }
  }

  SavedAddressKind _firstFreeKind() {
    for (final kind in SavedAddressKind.values) {
      if (!widget.takenKinds.contains(kind)) {
        return kind;
      }
    }
    return SavedAddressKind.other;
  }

  @override
  void dispose() {
    _label.dispose();
    _line.dispose();
    _note.dispose();
    super.dispose();
  }

  String _defaultLabel(AppLocalizations l10n, SavedAddressKind kind) =>
      switch (kind) {
        SavedAddressKind.home => l10n.addrBookKindHome,
        SavedAddressKind.work => l10n.addrBookKindWork,
        SavedAddressKind.other => '',
      };

  void _selectKind(AppLocalizations l10n, SavedAddressKind kind) {
    final previousDefault = _defaultLabel(l10n, _kind);
    setState(() => _kind = kind);
    if (_label.text.trim().isEmpty || _label.text.trim() == previousDefault) {
      _label.text = _defaultLabel(l10n, kind);
    }
  }

  Future<void> _pinHere() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _error = null;
    });
    final position = await context.read<LocationService>().currentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      if (position == null) {
        _error = l10n.addrBookPinFailed;
      } else {
        _lat = position.latitude;
        _lng = position.longitude;
      }
    });
  }

  /// Exact spot on the map (gate, alley) instead of the GPS fix.
  Future<void> _pinOnMap() async {
    final lat = _lat;
    final lng = _lng;
    final place = await pickOnMap(
      context,
      purpose: PlacePickPurpose.delivery,
      initial: lat != null && lng != null
          ? MapLatLng(lat: lat, lng: lng)
          : null,
    );
    if (!mounted || place == null) {
      return;
    }
    setState(() {
      _lat = place.lat;
      _lng = place.lng;
      _error = null;
      if (_line.text.trim().isEmpty) {
        _line.text = place.address.isNotEmpty ? place.address : place.name;
      }
    });
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_kind != SavedAddressKind.other && widget.takenKinds.contains(_kind)) {
      setState(() => _error = l10n.addrBookErrKindTaken);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSubmit(
      SavedAddressDraft(
        kind: _kind,
        label: _label.text.trim(),
        addressLine: _line.text.trim(),
        note: _note.text.trim(),
        lat: _lat,
        lng: _lng,
        isDefault: _makeDefault,
      ),
    );
    if (!mounted) {
      return;
    }
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = addressErrorText(l10n, error);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final pinned = _lat != null && _lng != null;
    final editing = widget.editing;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
          DealGoDimensions.pageGutter,
          DealGoSpacing.s16,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                editing == null
                    ? l10n.addrBookAddTitle
                    : l10n.addrBookEditTitle,
                style: textTheme.titleLarge,
              ),
              const SizedBox(height: DealGoSpacing.s16),
              DealGoSegmentedControl(
                value: _kind.wire,
                onChanged: (wire) =>
                    _selectKind(l10n, SavedAddressKind.fromWire(wire)),
                items: [
                  DealGoSegmentItem(id: 'HOME', label: l10n.addrBookKindHome),
                  DealGoSegmentItem(id: 'WORK', label: l10n.addrBookKindWork),
                  DealGoSegmentItem(id: 'OTHER', label: l10n.addrBookKindOther),
                ],
              ),
              const SizedBox(height: DealGoSpacing.s16),
              DealGoTextField(
                key: const Key('address-label'),
                label: l10n.addrBookLabel,
                hint: l10n.addrBookLabelHint,
                controller: _label,
                maxLength: 60,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.addrBookLabelRequired
                    : null,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                key: const Key('address-line'),
                label: l10n.addrBookLine,
                hint: l10n.addrBookLineHint,
                controller: _line,
                maxLength: 300,
                maxLines: 2,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().length < 3
                    ? l10n.addrBookLineRequired
                    : null,
              ),
              const SizedBox(height: DealGoSpacing.s12),
              DealGoTextField(
                key: const Key('address-note'),
                label: l10n.addrBookNote,
                hint: l10n.addrBookNoteHint,
                controller: _note,
                maxLength: 200,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: DealGoSpacing.s8),
              Row(
                children: [
                  Icon(
                    pinned ? DealGoIcons.check : DealGoIcons.pin,
                    size: 20,
                    color: pinned
                        ? DealGoColors.brandGreen
                        : DealGoColors.textSecondary,
                  ),
                  const SizedBox(width: DealGoSpacing.s8),
                  Expanded(
                    child: Text(
                      pinned ? l10n.addrBookPinned : l10n.addrBookNoPin,
                      style: textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    key: const Key('address-pin-map'),
                    tooltip: l10n.mapPickerTitle,
                    onPressed: _locating ? null : _pinOnMap,
                    icon: const Icon(
                      DealGoIcons.map,
                      size: 20,
                      color: DealGoColors.primary,
                    ),
                  ),
                  TextButton(
                    key: const Key('address-pin-here'),
                    onPressed: _locating ? null : _pinHere,
                    child: Text(
                      _locating ? l10n.addrBookLocating : l10n.addrBookPinHere,
                    ),
                  ),
                ],
              ),
              if (!(editing?.isDefault ?? false))
                SwitchListTile.adaptive(
                  key: const Key('address-default'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.addrBookMakeDefault),
                  value: _makeDefault,
                  onChanged: (value) => setState(() => _makeDefault = value),
                ),
              if (_error case final error?) ...[
                const SizedBox(height: DealGoSpacing.s8),
                Text(
                  error,
                  key: const Key('address-form-error'),
                  style: textTheme.bodySmall?.copyWith(
                    color: DealGoColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: DealGoSpacing.s16),
              DealGoPrimaryButton(
                key: const Key('address-save'),
                label: l10n.addrBookSave,
                isLoading: _saving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
