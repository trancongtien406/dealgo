import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/components/dealgo_banner.dart';
import '../../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../../core/design_system/components/dealgo_state_view.dart';
import '../../../../core/design_system/icons/dealgo_icons.dart';
import '../../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../../core/l10n/api_error_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../food/domain/entities/food_models.dart';
import '../../../places/domain/place.dart';
import '../utils/merchant_routes.dart';
import '../../domain/usecases/get_merchant_catalog.dart';
import '../../domain/usecases/update_store_location.dart';
import '../widgets/merchant_widgets.dart';
import '../../../../core/design_system/components/dealgo_nav_insets.dart';

/// Opens the place picker for the store point; tests swap it for a canned place.
typedef StorePlacePicker = Future<PlaceOption?> Function(BuildContext context);

Future<PlaceOption?> _defaultPicker(BuildContext context) =>
    context.push<PlaceOption>(MerchantRoutes.locationPick);

/// M030 (part) — the store pickup point. Without it drivers get no pickup pin and
/// delivery distance falls back to the flat fee (DEC-PROD-044).
class MerchantLocationPage extends StatefulWidget {
  const MerchantLocationPage({this.picker = _defaultPicker, super.key});

  final StorePlacePicker picker;

  @override
  State<MerchantLocationPage> createState() => _MerchantLocationPageState();
}

class _MerchantLocationPageState extends State<MerchantLocationPage> {
  FoodStoreDetail? _store;
  Object? _loadError;
  PlaceOption? _picked;
  var _saving = false;
  var _saved = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loadError = null;
      _store = null;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final store = await context.read<GetMerchantCatalog>()(token);
      if (mounted) {
        setState(() => _store = store);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loadError = error);
      }
    }
  }

  Future<void> _pick() async {
    final place = await widget.picker(context);
    if (place == null || !mounted) {
      return;
    }
    setState(() {
      _picked = place;
      _saved = false;
      _saveError = null;
    });
  }

  Future<void> _save() async {
    final place = _picked;
    if (place == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final token = merchantAccessToken(context) ?? '';
      final label = place.label;
      final store = await context.read<UpdateStoreLocation>()(
        accessToken: token,
        lat: place.lat,
        lng: place.lng,
        addressLabel: label.length > 200 ? label.substring(0, 200) : label,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _store = store;
        _picked = null;
        _saved = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = apiErrorText(l10n, error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final store = _store;
    final Widget body;
    if (_loadError != null) {
      body = DealGoStateView.failure(
        context,
        onRetry: _load,
        cause: _loadError,
        message: apiErrorText(l10n, _loadError),
      );
    } else if (store == null) {
      body = const DealGoSkeletonList(itemCount: 2);
    } else {
      body = Material(
        color: DealGoColors.canvas,
        child: _content(context, l10n, store),
      );
    }
    return MerchantPageFrame(
      title: l10n.merchantLocationTitle,
      onBack: () => merchantBack(context),
      body: body,
      footer: store == null
          ? null
          : MerchantPrimaryBar(
              label: l10n.merchantLocationSave,
              buttonKey: const Key('merchant-location-save'),
              loading: _saving,
              enabled: !_saving && _picked != null,
              onPressed: _save,
            ),
    );
  }

  Widget _content(
    BuildContext context,
    AppLocalizations l10n,
    FoodStoreDetail store,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final picked = _picked;
    final String current;
    if (picked != null) {
      current = picked.label;
    } else if (store.hasLocation) {
      current = (store.addressLabel?.trim().isNotEmpty ?? false)
          ? store.addressLabel!
          : '${store.lat!.toStringAsFixed(5)}, ${store.lng!.toStringAsFixed(5)}';
    } else {
      current = l10n.merchantLocationUnsetValue;
    }
    return ListView(
      padding: dealGoScrollPadding(context, merchantPagePadding),
      children: [
        if (!store.hasLocation && picked == null) ...[
          DealGoBanner(
            key: const Key('merchant-location-unset'),
            tone: DealGoBannerTone.warning,
            message: l10n.merchantLocationUnset,
          ),
          const SizedBox(height: DealGoSpacing.s16),
        ],
        MerchantPanel(
          child: Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: const Key('merchant-location-pick'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(DealGoIcons.pin, color: DealGoColors.primary),
              title: Text(current, style: textTheme.bodyMedium),
              subtitle: Text(
                picked != null
                    ? l10n.merchantLocationPendingHint
                    : l10n.merchantLocationPickHint,
                style: textTheme.bodySmall,
              ),
              trailing: const Icon(DealGoIcons.chevronRight),
              onTap: _saving ? null : _pick,
            ),
          ),
        ),
        if (_saved) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(
            key: const Key('merchant-location-saved'),
            message: l10n.merchantLocationSaved,
          ),
        ],
        if (_saveError != null) ...[
          const SizedBox(height: DealGoSpacing.s12),
          DealGoBanner(tone: DealGoBannerTone.warning, message: _saveError!),
        ],
      ],
    );
  }
}
