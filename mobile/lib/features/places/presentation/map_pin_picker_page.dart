import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart' show Position;
import 'package:permission_handler/permission_handler.dart';

import '../../../core/design_system/components/dealgo_primary_button.dart';
import '../../../core/design_system/components/dealgo_skeleton.dart';
import '../../../core/design_system/icons/dealgo_icons.dart';
import '../../../core/design_system/tokens/dealgo_tokens.dart';
import '../../../core/location/location_service.dart';
import '../../../core/maps/map_controls.dart';
import '../../../core/maps/map_lat_lng.dart';
import '../../../core/maps/map_markers.dart';
import '../../../core/maps/map_port.dart';
import '../../../core/maps/pin_picker_map.dart';
import '../../../l10n/app_localizations.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../data/place_history_cache.dart';
import '../data/reverse_geocode_cache.dart';
import '../domain/place.dart';
import 'place_picker_page.dart';

/// Opens pick-on-map over everything (root navigator, platform route so iOS
/// swipe-back and Android back both close it) and returns the pinned place.
Future<PlaceOption?> pickOnMap(
  BuildContext context, {
  required PlacePickPurpose purpose,
  MapLatLng? initial,
}) {
  return Navigator.of(context, rootNavigator: true).push<PlaceOption>(
    MaterialPageRoute(
      builder: (_) => MapPinPickerPage(purpose: purpose, initial: initial),
    ),
  );
}

/// Pick-on-map: drag the map under a fixed pin, read the address, confirm.
/// Back, in-map search, map style, my location, attribution; the address is
/// looked up only after the camera rests and is memoised per ~11 m cell.
class MapPinPickerPage extends StatefulWidget {
  const MapPinPickerPage({
    required this.purpose,
    this.initial,
    this.settleDelay = const Duration(milliseconds: 500),
    this.cache,
    super.key,
  });

  final PlacePickPurpose purpose;
  final MapLatLng? initial;

  /// Camera rest time before the address lookup.
  final Duration settleDelay;

  /// Test seam; defaults to the app-wide memo.
  final ReverseGeocodeCache? cache;

  @override
  State<MapPinPickerPage> createState() => _MapPinPickerPageState();
}

class _MapPinPickerPageState extends State<MapPinPickerPage> {
  static const _minQuery = 2;
  static const _pinSize = 46.0;

  final _map = PinPickerController();
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  late final ReverseGeocodeCache _cache = widget.cache ?? reverseGeocodeCache;

  late MapLatLng _center = widget.initial ?? danangViewportCenter;
  var _userMoved = false;
  var _moving = false;
  var _resolving = false;
  PlaceOption? _resolved;
  var _resolveSeq = 0;
  Timer? _settle;

  var _searchOpen = false;
  var _searching = false;
  List<PlaceOption> _results = const [];
  List<PlaceOption> _history = const [];
  Timer? _searchDebounce;
  var _searchSeq = 0;

  var _locating = false;
  var _denied = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      unawaited(_startNearUser());
    } else {
      _scheduleResolve(immediate: true);
    }
  }

  @override
  void dispose() {
    _settle?.cancel();
    _searchDebounce?.cancel();
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  String? get _token {
    final state = context.read<AuthCubit>().state;
    return state is AuthSignedIn ? state.tokens.accessToken : null;
  }

  /// Opens on the last known fix without prompting for permission; the first
  /// lookup waits for it so the fallback centre is never geocoded for nothing.
  Future<void> _startNearUser() async {
    Position? pos;
    try {
      pos = await context.read<LocationService>().quietPosition();
    } catch (_) {
      pos = null;
    }
    if (!mounted || _userMoved) {
      return;
    }
    if (pos == null) {
      _scheduleResolve(immediate: true);
      return;
    }
    final here = MapLatLng(lat: pos.latitude, lng: pos.longitude);
    _center = here;
    _map.moveTo(here);
    _scheduleResolve(immediate: true);
  }

  void _onCenterChanged(MapLatLng center) {
    _center = center;
    _userMoved = true;
    if (!_moving) {
      setState(() => _moving = true);
    }
    _scheduleResolve();
  }

  void _scheduleResolve({bool immediate = false}) {
    _settle?.cancel();
    _settle = Timer(immediate ? Duration.zero : widget.settleDelay, () {
      if (!mounted) {
        return;
      }
      setState(() => _moving = false);
      unawaited(_resolve(_center));
    });
  }

  Future<void> _resolve(MapLatLng at) async {
    final token = _token;
    final seq = ++_resolveSeq;
    if (token == null) {
      setState(() => _resolved = null);
      return;
    }
    final places = context.read<PlacesRepository>();
    if (!_cache.contains(at.lat, at.lng)) {
      setState(() => _resolving = true);
    }
    PlaceOption? place;
    try {
      place = await _cache.resolve(
        lat: at.lat,
        lng: at.lng,
        lookup: () =>
            places.reverse(accessToken: token, lat: at.lat, lng: at.lng),
      );
    } catch (_) {
      place = null;
    }
    if (!mounted || seq != _resolveSeq) {
      return;
    }
    setState(() {
      _resolving = false;
      _resolved = place;
    });
  }

  Future<void> _locate() async {
    if (_locating) {
      return;
    }
    setState(() => _locating = true);
    final location = context.read<LocationService>();
    Position? pos;
    try {
      pos = await location.currentPosition().timeout(
        const Duration(seconds: 15),
      );
    } catch (_) {
      pos = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _locating = false;
      _denied = pos == null;
    });
    if (pos != null) {
      _map.moveTo(MapLatLng(lat: pos.latitude, lng: pos.longitude), zoom: 17);
    }
  }

  void _onQueryChanged(String _) {
    _searchDebounce?.cancel();
    final query = _query.text.trim();
    if (query.length < _minQuery) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => unawaited(_runSearch(query)),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = _token;
    final seq = ++_searchSeq;
    if (token == null) {
      setState(() => _searching = false);
      return;
    }
    List<PlaceOption> items;
    try {
      final result = await context.read<PlacesRepository>().search(
        accessToken: token,
        query: query,
        nearLat: _center.lat,
        nearLng: _center.lng,
      );
      items = result.items;
    } catch (_) {
      items = const [];
    }
    if (!mounted || seq != _searchSeq) {
      return;
    }
    setState(() {
      _searching = false;
      _results = items.take(5).toList();
    });
  }

  void _openSearch() {
    setState(() => _searchOpen = true);
    _queryFocus.requestFocus();
    unawaited(_loadHistory());
  }

  /// Picked-place history for the empty search field (device copy, then
  /// the server list).
  Future<void> _loadHistory() async {
    final cached = await PlaceHistoryCache.load();
    if (mounted && cached.isNotEmpty) {
      setState(() => _history = cached);
    }
    final token = _token;
    if (token == null || !mounted) {
      return;
    }
    try {
      final rows = await context.read<PlacesRepository>().history(
        accessToken: token,
      );
      await PlaceHistoryCache.save(rows);
      if (mounted) {
        setState(() => _history = rows);
      }
    } catch (_) {}
  }

  List<PlaceOption> get _shownRows =>
      _query.text.trim().isEmpty ? _history.take(5).toList() : _results;

  void _closeSearch() {
    _searchDebounce?.cancel();
    _queryFocus.unfocus();
    _query.clear();
    setState(() {
      _searchOpen = false;
      _searching = false;
      _results = const [];
    });
  }

  void _chooseResult(PlaceOption place) {
    // Known name for that cell: the lookup after the camera lands is free.
    _cache.put(place);
    _closeSearch();
    _map.moveTo(MapLatLng(lat: place.lat, lng: place.lng), zoom: 17);
  }

  void _back() {
    if (_searchOpen) {
      _closeSearch();
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _confirm() {
    final l10n = AppLocalizations.of(context);
    final at = _center;
    final named = _resolved;
    Navigator.of(context).pop(
      PlaceOption(
        name: named?.name ?? l10n.mapPickerPinned,
        address: named?.address ?? _coords(at),
        lat: at.lat,
        lng: at.lng,
        source: PlaceSource.search,
      ),
    );
  }

  static String _coords(MapLatLng at) =>
      '${at.lat.toStringAsFixed(5)}, ${at.lng.toStringAsFixed(5)}';

  DealGoMapPinKind get _pinKind => switch (widget.purpose) {
    PlacePickPurpose.pickup => DealGoMapPinKind.pickup,
    PlacePickPurpose.dropoff => DealGoMapPinKind.dropoff,
    PlacePickPurpose.delivery => DealGoMapPinKind.home,
    PlacePickPurpose.storeLocation => DealGoMapPinKind.store,
  };

  @override
  Widget build(BuildContext context) {
    final port = context.watch<MapPort>();
    final top = MediaQuery.paddingOf(context).top + DealGoSpacing.s8;
    return PopScope(
      canPop: !_searchOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _closeSearch();
        }
      },
      child: Scaffold(
        backgroundColor: DealGoColors.canvas,
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: PinPickerMap(
                      port: port,
                      initialCenter: _center,
                      controller: _map,
                      onCenterChanged: _onCenterChanged,
                    ),
                  ),
                  IgnorePointer(child: Center(child: _centerPin())),
                  Positioned(
                    left: DealGoDimensions.pageGutter,
                    right: DealGoDimensions.pageGutter,
                    top: top,
                    child: _topBar(context),
                  ),
                  if (!_searchOpen)
                    Positioned(
                      right: DealGoDimensions.pageGutter,
                      top: top + MapRoundButton.size + DealGoSpacing.s12,
                      child: MapSideControls(
                        stylesAvailable: mapStylesAvailable(port),
                        locateKey: const Key('map-picker-locate'),
                        onLocate: _locating ? null : _locate,
                      ),
                    ),
                ],
              ),
            ),
            _bottomCard(context),
          ],
        ),
      ),
    );
  }

  Widget _centerPin() {
    return AnimatedSlide(
      duration: const Duration(milliseconds: 140),
      offset: Offset(0, _moving ? -0.6 : -0.46),
      child: SizedBox(
        key: const Key('map-picker-pin'),
        width: DealGoMapPin.boxFor(_pinSize, showLabel: false).width,
        height: _pinSize,
        child: DealGoMapPin(kind: _pinKind, size: _pinSize, showLabel: false),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            MapBackButton(key: const Key('map-picker-back'), onPressed: _back),
            const SizedBox(width: DealGoSpacing.s8),
            Expanded(
              child: Material(
                color: DealGoColors.card,
                elevation: 2,
                shadowColor: const Color(0x33171B2C),
                borderRadius: BorderRadius.circular(DealGoRadius.pill),
                child: SizedBox(
                  height: MapRoundButton.size,
                  child: _searchOpen
                      ? TextField(
                          key: const Key('map-picker-search-field'),
                          controller: _query,
                          focusNode: _queryFocus,
                          textInputAction: TextInputAction.search,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(120),
                          ],
                          onChanged: _onQueryChanged,
                          style: const TextStyle(fontSize: 15),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: l10n.mapPickerSearch,
                            prefixIcon: const Icon(
                              DealGoIcons.search,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              key: const Key('map-picker-search-close'),
                              tooltip: MaterialLocalizations.of(context)
                                  .closeButtonTooltip,
                              onPressed: _closeSearch,
                              icon: const Icon(DealGoIcons.close, size: 18),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                          ),
                        )
                      : InkWell(
                          key: const Key('map-picker-search'),
                          borderRadius: BorderRadius.circular(
                            DealGoRadius.pill,
                          ),
                          onTap: _openSearch,
                          child: Row(
                            children: [
                              const SizedBox(width: DealGoSpacing.s12),
                              const Icon(
                                DealGoIcons.search,
                                size: 18,
                                color: DealGoColors.textSecondary,
                              ),
                              const SizedBox(width: DealGoSpacing.s8),
                              Text(
                                l10n.mapPickerSearch,
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: DealGoColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
        if (_searchOpen && (_searching || _shownRows.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(top: DealGoSpacing.s8),
            child: Material(
              key: const Key('map-picker-results'),
              color: DealGoColors.card,
              elevation: 3,
              shadowColor: const Color(0x33171B2C),
              borderRadius: BorderRadius.circular(DealGoRadius.button),
              clipBehavior: Clip.antiAlias,
              child: _searching
                  ? const DealGoSkeletonList(
                      itemCount: 2,
                      thumbSize: 32,
                      padding: EdgeInsets.all(DealGoSpacing.s12),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final (i, place) in _shownRows.indexed)
                          ListTile(
                            key: Key(
                              place.source == PlaceSource.history
                                  ? 'map-picker-history-$i'
                                  : 'map-picker-result-$i',
                            ),
                            dense: true,
                            leading: Icon(
                              place.source == PlaceSource.history
                                  ? DealGoIcons.history
                                  : DealGoIcons.pin,
                              size: 18,
                              color: place.source == PlaceSource.history
                                  ? DealGoColors.textSecondary
                                  : DealGoColors.primary,
                            ),
                            title: Text(
                              place.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: place.address.isEmpty
                                ? null
                                : Text(
                                    place.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                            onTap: () => _chooseResult(place),
                          ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  Widget _bottomCard(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final named = _resolved;
    final busy = _moving || _resolving;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: DealGoColors.card,
        boxShadow: DealGoShadows.floating,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(DealGoRadius.card),
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: DealGoSpacing.s12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            DealGoDimensions.pageGutter,
            DealGoSpacing.s16,
            DealGoDimensions.pageGutter,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    DealGoIcons.pin,
                    size: 20,
                    color: _pinKind == DealGoMapPinKind.pickup
                        ? DealGoColors.brandGreen
                        : DealGoColors.primary,
                  ),
                  const SizedBox(width: DealGoSpacing.s12),
                  Expanded(
                    child: busy
                        ? const Column(
                            key: Key('map-picker-address-loading'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              DealGoSkeletonBox(width: 160, height: 16),
                              SizedBox(height: DealGoSpacing.s6),
                              DealGoSkeletonBox(width: 220, height: 12),
                            ],
                          )
                        : Column(
                            key: const Key('map-picker-address'),
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                named?.name ?? l10n.mapPickerPinned,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.titleSmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                named?.address.isNotEmpty == true
                                    ? named!.address
                                    : _coords(_center),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall,
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              if (_denied)
                Padding(
                  padding: const EdgeInsets.only(top: DealGoSpacing.s8),
                  child: Row(
                    key: const Key('map-picker-denied'),
                    children: [
                      Expanded(
                        child: Text(
                          l10n.placeLocationDenied,
                          style: textTheme.bodySmall?.copyWith(
                            color: DealGoColors.danger,
                          ),
                        ),
                      ),
                      TextButton(
                        key: const Key('map-picker-settings'),
                        onPressed: () => unawaited(openAppSettings()),
                        child: Text(l10n.mapOpenSettings),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: DealGoSpacing.s16),
              DealGoPrimaryButton(
                key: const Key('map-picker-confirm'),
                label: l10n.mapPickerConfirm,
                enabled: !_moving,
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
