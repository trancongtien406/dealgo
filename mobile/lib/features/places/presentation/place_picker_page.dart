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
import '../../address_book/domain/entities/saved_address.dart';
import '../../address_book/domain/repositories/address_book_repository.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../../shell/presentation/account_routes.dart';
import '../domain/place.dart';
import 'current_place.dart';

/// Why the picker was opened; only changes the title.
enum PlacePickPurpose { pickup, dropoff, delivery, storeLocation }

abstract final class PlaceRoutes {
  static const pick = '/customer/places/pick';
}

/// Picker arguments when the caller already has a query (home search).
class PlacePickRequest {
  const PlacePickRequest({required this.purpose, this.initialQuery = ''});

  final PlacePickPurpose purpose;
  final String initialQuery;
}

/// Opens the S015 picker and resolves with the chosen place (null on back).
Future<PlaceOption?> pickPlace(
  BuildContext context,
  PlacePickPurpose purpose, {
  String initialQuery = '',
}) {
  return context.push<PlaceOption>(
    PlaceRoutes.pick,
    extra: initialQuery.isEmpty
        ? purpose
        : PlacePickRequest(purpose: purpose, initialQuery: initialQuery),
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
    super.key,
  });

  final PlacePickPurpose purpose;

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
  var _searchSeq = 0;

  var _loadingLists = true;
  var _saved = const <PlaceOption>[];
  var _recent = const <PlaceOption>[];

  var _locating = false;
  String? _locationError;

  String? get _token {
    final state = context.read<AuthCubit>().state;
    return state is AuthSignedIn ? state.tokens.accessToken : null;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadLists());
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

  Future<void> _loadLists() async {
    final token = _token;
    if (token == null) {
      setState(() => _loadingLists = false);
      return;
    }
    final book = context.read<AddressBookRepository>();
    final places = context.read<PlacesRepository>();
    // Each list is optional: one failing must not hide the other.
    final saved = await book
        .list(accessToken: token)
        .then(_savedOptions, onError: (_) => const <PlaceOption>[]);
    final recent = await places
        .recentDestinations(accessToken: token)
        .then((rows) => rows, onError: (_) => const <PlaceOption>[]);
    if (!mounted) {
      return;
    }
    setState(() {
      _saved = saved;
      _recent = recent;
      _loadingLists = false;
    });
  }

  static List<PlaceOption> _savedOptions(List<SavedAddress> rows) {
    return [
      for (final row in rows)
        if (row.lat != null && row.lng != null)
          PlaceOption(
            name: row.label,
            address: row.addressLine,
            lat: row.lat!,
            lng: row.lng!,
            source: PlaceSource.saved,
          ),
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
      );
      if (!mounted || seq != _searchSeq) {
        return;
      }
      setState(() {
        _results = result.items;
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

  void _choose(PlaceOption place) => context.pop(place);

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
        if (_loadingLists)
          const DealGoSkeletonList(
            itemCount: 3,
            thumbSize: 40,
            padding: EdgeInsets.symmetric(vertical: DealGoSpacing.s12),
          )
        else ...[
          if (_saved.isNotEmpty) ...[
            _SectionHeader(
              title: l10n.placeSavedTitle,
              action: l10n.placeSavedManage,
              onAction: () =>
                  context.push(AccountRoutes.addresses('/customer/account')),
            ),
            for (final place in _saved)
              _PlaceTile(
                icon: DealGoIcons.bookmark,
                tone: DealGoColors.brandGreen,
                title: place.name,
                subtitle: place.address,
                onTap: () => _choose(place),
              ),
          ],
          if (_recent.isNotEmpty) ...[
            _SectionHeader(title: l10n.placeRecentTitle),
            for (final place in _recent)
              _PlaceTile(
                icon: DealGoIcons.history,
                tone: DealGoColors.textSecondary,
                title: place.name,
                subtitle: place.address,
                onTap: () => _choose(place),
              ),
          ],
          if (_saved.isEmpty && _recent.isEmpty)
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
                subtitle: place.address,
                onTap: () => _choose(place),
              ),
          ],
        );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
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
            TextButton(onPressed: onAction, child: Text(action!)),
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
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall,
            ),
      trailing: trailing,
    );
  }
}
