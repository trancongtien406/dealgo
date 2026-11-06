import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design_system/components/dealgo_app_header.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/components/dealgo_state_view.dart';
import '../../../core/design_system/components/dealgo_text_field.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../shell/presentation/account_routes.dart';
import '../domain/place.dart';
import '../../../core/location/location_service.dart';
import '../../../core/maps/map_lat_lng.dart';
import 'current_place.dart';
import 'map_pin_picker_page.dart';
import 'place_lists_store.dart';

/// Why the picker was opened; only changes the title.
enum PlacePickPurpose { pickup, dropoff, delivery, storeLocation }

abstract final class PlaceRoutes {
  static const pick = '/customer/places/pick';
}

/// Picker arguments when the caller already has a query (home search).
class PlacePickRequest {
  const PlacePickRequest({
    required this.purpose,
    this.initialQuery = '',
    this.near,
  });

  final PlacePickPurpose purpose;
  final String initialQuery;

  /// Search bias point (e.g. the pickup when choosing a drop-off); the
  /// device location is used when null.
  final MapLatLng? near;
}

/// Opens the S015 picker and resolves with the chosen place (null on back).
Future<PlaceOption?> pickPlace(
  BuildContext context,
  PlacePickPurpose purpose, {
  String initialQuery = '',
  MapLatLng? near,
}) {
  return context.push<PlaceOption>(
    PlaceRoutes.pick,
    extra: initialQuery.isEmpty && near == null
        ? purpose
        : PlacePickRequest(
            purpose: purpose,
            initialQuery: initialQuery,
            near: near,
          ),
  );
}

const _minQueryLength = 2;
const _debounce = Duration(milliseconds: 350);

/// S015 "Tìm địa điểm": current location, saved addresses, recent trips and
/// provider search, all with real coordinates.
class PlacePickerPage extends StatefulWidget {
  const PlacePickerPage({
    required this.purpose,
    this.initialQuery = '',
    this.near,
    super.key,
  });

  final PlacePickPurpose purpose;

  /// Search bias point; the device location when null.
  final MapLatLng? near;

  /// Pre-filled search text; searched right away when long enough.
  final String initialQuery;

  @override
  State<PlacePickerPage> createState() => _PlacePickerPageState();
}

enum _SearchState { idle, loading, done, unavailable, error }

class _PlacePickerPageState extends State<PlacePickerPage> {
  final TextEditingController _query = TextEditingController();
  Timer? _timer;
  var _search = _SearchState.idle;
  var _results = const <PlaceOption>[];
  var _googleAttribution = false;
  var _searchSeq = 0;

  var _locating = false;
  String? _locationError;

  PlaceListsStore get _lists => context.read<PlaceListsStore>();

  String? get _token {
    final state = context.read<AuthCubit>().state;
    return state is AuthSignedIn ? state.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    _nearLat = widget.near?.lat;
    _nearLng = widget.near?.lng;
    unawaited(_lists.loadHistory());
    unawaited(_lists.loadLists());
    unawaited(_loadNear());
    final initial = widget.initialQuery.trim();
    if (initial.isNotEmpty) {
      _query.text = initial;
      if (initial.length >= _minQueryLength) {
        _search = _SearchState.loading;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            unawaited(_runSearch(initial));
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _deleteHistory(PlaceOption place) async {
    final id = place.historyId;
    if (id == null) {
      return;
    }
    await _lists.deleteHistory(id);
  }

  Future<void> _clearHistory() async {
    if (_token == null) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.placeHistoryClearTitle),
        content: Text(l10n.placeHistoryClearBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            key: const Key('place-history-clear-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.placeHistoryClearConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    await _lists.clearHistory();
  }

  /// Ride drop-offs not already in the picked-place history.
  List<PlaceOption> _recentNotInHistory(
    List<PlaceOption> recent,
    List<PlaceOption> history,
  ) {
    final names = {for (final row in history) foldVietnamese(row.name)};
    return [
      for (final row in recent)
        if (!names.contains(foldVietnamese(row.name))) row,
    ];
  }

  void _onQueryChanged(String _) {
    _timer?.cancel();
    final query = _query.text.trim();
    if (query.length < _minQueryLength) {
      setState(() {
        _search = _SearchState.idle;
        _results = const [];
      });
      return;
    }
    setState(() => _search = _SearchState.loading);
    _timer = Timer(_debounce, () => unawaited(_runSearch(query)));
  }

  double? _nearLat;
  double? _nearLng;

  Future<void> _loadNear() async {
    if (widget.near != null) {
      return;
    }
    try {
      final pos = await context.read<LocationService>().quietPosition();
      if (pos != null) {
        _nearLat = pos.latitude;
        _nearLng = pos.longitude;
      }
    } catch (_) {}
  }

  Future<void> _runSearch(String query) async {
    final token = _token;
    if (token == null) {
      return;
    }
    final seq = ++_searchSeq;
    setState(() => _search = _SearchState.loading);
    try {
      final result = await context.read<PlacesRepository>().search(
        accessToken: token,
        query: query,
        nearLat: _nearLat,
        nearLng: _nearLng,
      );
      if (!mounted || seq != _searchSeq) {
        return;
      }
      setState(() {
        _results = result.items;
        _googleAttribution = result.googleAttribution;
        _search = result.available
            ? _SearchState.done
            : _SearchState.unavailable;
      });
    } catch (_) {
      if (!mounted || seq != _searchSeq) {
        return;
      }
      setState(() => _search = _SearchState.error);
    }
  }

  void _clear() {
    _query.clear();
    _onQueryChanged('');
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    setState(() {
      _locating = true;
      _locationError = null;
    });
    final result = await locateCurrentPlace(context, accessToken: _token);
    if (!mounted) {
      return;
    }
    switch (result) {
      case CurrentPlaceFound(:final place):
        context.pop(place);
      case CurrentPlaceDenied():
        setState(() {
          _locating = false;
          _locationError = l10n.placeLocationDenied;
        });
      case CurrentPlaceFailed():
        setState(() {
          _locating = false;
          _locationError = l10n.placeLocationFailed;
        });
    }
  }

  void _choose(PlaceOption place) {
    _remember(place);
    context.pop(place);
  }

  /// Saves a searched / map / recent pick to the history (fire-and-forget;
  /// saved addresses and the GPS fix are not history).
  void _remember(PlaceOption place) {
    if (place.source == PlaceSource.saved ||
        place.source == PlaceSource.current) {
      return;
    }
    if (_token == null) {
      return;
    }
    unawaited(_lists.recordHistory(place));
  }

  Future<void> _pickOnMap() async {
    final near = _nearLat != null && _nearLng != null
        ? MapLatLng(lat: _nearLat!, lng: _nearLng!)
        : null;
    final place = await pickOnMap(
      context,
      purpose: widget.purpose,
      initial: near,
    );
    if (!mounted || place == null) {
      return;
    }
    _choose(place);
  }

  String _title(AppLocalizations l10n) => switch (widget.purpose) {
    PlacePickPurpose.pickup => l10n.placePickerPickupTitle,
    PlacePickPurpose.dropoff => l10n.placePickerDropoffTitle,
    PlacePickPurpose.delivery => l10n.placePickerDeliveryTitle,
    PlacePickPurpose.storeLocation => l10n.placePickerStoreTitle,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final searching = _query.text.trim().length >= _minQueryLength;
    return Scaffold(
      backgroundColor: DealGoColors.canvas,
      appBar: DealGoAppHeader(
        title: _title(l10n),
        onBack: () => context.pop(),
        applySafeArea: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DealGoDimensions.pageGutter,
              DealGoSpacing.s4,
              DealGoDimensions.pageGutter,
              DealGoSpacing.s8,
            ),
            child: DealGoTextField(
              label: l10n.placePickerHint,
              showLabel: false,
              hint: l10n.placePickerHint,
              prefixIcon: DealGoIcons.search,
              controller: _query,
              fieldKey: const Key('place-search-field'),
              autofocus: widget.purpose != PlacePickPurpose.pickup,
              textInputAction: TextInputAction.search,
              inputFormatters: [LengthLimitingTextInputFormatter(120)],
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _onQueryChanged(''),
              suffix: _query.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(context)
                          .deleteButtonTooltip,
                      onPressed: _clear,
                      icon: const Icon(DealGoIcons.close, size: 18),
                    ),
            ),
          ),
          Expanded(child: searching ? _buildResults(l10n) : _buildHome(l10n)),
        ],
      ),
    );
  }

  Widget _buildHome(AppLocalizations l10n) {
    final textTheme = Theme.of(context).textTheme;
    final lists = context.watch<PlaceListsStore>();
    final saved = lists.saved;
    final recent = lists.recent;
    final history = lists.history;
    final recentNotInHistory = _recentNotInHistory(recent, history);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DealGoDimensions.pageGutter,
        0,
        DealGoDimensions.pageGutter,
        DealGoSpacing.s24,
      ),
      children: [
        _PlaceTile(
          key: const Key('place-current-location'),
          icon: DealGoIcons.myLocation,
          tone: DealGoColors.primary,
          title: l10n.placeCurrentLocation,
          subtitle: _locating
              ? l10n.placeLocating
              : l10n.placeCurrentLocationHint,
          trailing: _locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _locating ? null : _useCurrentLocation,
        ),
        if (_locationError != null)
          Padding(
            padding: const EdgeInsets.only(left: 56, bottom: DealGoSpacing.s8),
            child: Text(
              _locationError!,
              key: const Key('place-location-error'),
              style: textTheme.bodySmall?.copyWith(color: DealGoColors.danger),
            ),
          ),
        _PlaceTile(
          key: const Key('place-pick-on-map'),
          icon: DealGoIcons.map,
          tone: DealGoColors.primary,
          title: l10n.mapPickerTitle,
          subtitle: '',
          onTap: _pickOnMap,
        ),
        if (lists.listsLoading)
          const DealGoSkeletonList(
            itemCount: 3,
            thumbSize: 40,
            padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
          )
        else ...[
          if (saved.isNotEmpty) ...[
            _SectionHeader(
              title: l10n.placeSavedTitle,
              action: l10n.placeSavedManage,
              onAction: () =>
                  context.push(AccountRoutes.addresses('/customer/account')),
            ),
            for (final place in saved)
              _PlaceTile(
                icon: DealGoIcons.bookmark,
                tone: DealGoColors.brandGreen,
                title: place.name,
                subtitle: place.address,
                onTap: () => _choose(place),
              ),
          ],
          if (history.isNotEmpty || recent.isNotEmpty) ...[
            _SectionHeader(
              title: l10n.placeHistoryTitle,
              action: history.isEmpty ? null : l10n.placeHistoryClear,
              actionKey: const Key('place-history-clear'),
              onAction: _clearHistory,
            ),
            for (final (index, place) in history.indexed)
              _PlaceTile(
                key: Key('place-history-$index'),
                icon: DealGoIcons.history,
                tone: DealGoColors.textSecondary,
                title: place.name,
                subtitle: place.address,
                onTap: () => _choose(place),
                trailing: IconButton(
                  key: Key('place-history-delete-$index'),
                  tooltip: l10n.placeHistoryDelete,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => unawaited(_deleteHistory(place)),
                  icon: Icon(
                    DealGoIcons.close,
                    size: 16,
                    color: DealGoColors.textSecondary,
                  ),
                ),
              ),
            for (final place in recentNotInHistory)
              _PlaceTile(
                icon: DealGoIcons.history,
                tone: DealGoColors.textSecondary,
                title: place.name,
                subtitle: place.address,
                onTap: () => _choose(place),
              ),
          ],
          if (saved.isEmpty && recent.isEmpty && history.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: DealGoSpacing.s24),
              child: Text(
                l10n.placeNothingYet,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    switch (_search) {
      case _SearchState.idle:
      case _SearchState.loading:
        return const DealGoSkeletonList(itemCount: 4, thumbSize: 40);
      case _SearchState.error:
        return DealGoStateView.error(
          context,
          compact: true,
          message: l10n.placeSearchError,
          onRetry: () => unawaited(_runSearch(_query.text.trim())),
        );
      case _SearchState.unavailable:
        return DealGoStateView(
          art: DealGoStateArt.location,
          compact: true,
          title: l10n.placeSearchEmptyTitle,
          message: l10n.placeSearchUnavailable,
          actionLabel: l10n.placeCurrentLocation,
          onAction: _clear,
        );
      case _SearchState.done:
        if (_results.isEmpty) {
          return DealGoStateView(
            art: DealGoStateArt.noSearch,
            compact: true,
            title: l10n.placeSearchEmptyTitle,
            message: l10n.placeSearchEmptyBody,
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: DealGoDimensions.pageGutter,
          ),
          children: [
            _SectionHeader(title: l10n.placeResultsTitle),
            for (final (index, place) in _results.indexed)
              _PlaceTile(
                key: Key('place-result-$index'),
                icon: DealGoIcons.pin,
                tone: DealGoColors.primary,
                title: place.name,
                subtitle: place.approximate
                    ? '${place.address}\n${l10n.placeApproximate}'
                    : place.address,
                trailing: place.distanceKm == null
                    ? null
                    : Text(
                        l10n.placeDistanceKm(
                          _km(
                            place.distanceKm!,
                            comma:
                                Localizations.localeOf(context).languageCode ==
                                'vi',
                          ),
                        ),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: DealGoColors.textSecondary),
                      ),
                onTap: () => _choose(place),
              ),
            if (_googleAttribution) const _GoogleMapsAttribution(),
          ],
        );
    }
  }
}

/// Google Places attribution when results are not shown on a Google map:
/// the untranslated text "Google Maps", 12sp, #5E5E5E.
class _GoogleMapsAttribution extends StatelessWidget {
  const _GoogleMapsAttribution();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      key: Key('place-google-attribution'),
      padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'Google Maps',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF5E5E5E),
            fontFamily: 'Roboto',
            fontFamilyFallback: ['sans-serif'],
          ),
        ),
      ),
    );
  }
}

/// "0,8" / "12": one decimal under 10 km ([comma] for Vietnamese).
String _km(double km, {required bool comma}) {
  if (km >= 10) {
    return km.round().toString();
  }
  final text = km.toStringAsFixed(1);
  return comma ? text.replaceAll('.', ',') : text;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.action,
    this.actionKey,
    this.onAction,
  });

  final String title;
  final String? action;
  final Key? actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(
        top: DealGoSpacing.s16,
        bottom: DealGoSpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: textTheme.titleSmall)),
          if (action != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              child: Text(action!),
            ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 40,
          child: Icon(icon, color: tone, size: 20),
        ),
      ),
      title: Text(
        title,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(subtitle, style: textTheme.bodySmall),
      trailing: trailing,
    );
  }
}
