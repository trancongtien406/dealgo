import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../address_book/domain/entities/saved_address.dart';
import '../../address_book/domain/repositories/address_book_repository.dart';
import '../../identity/domain/entities/auth_state.dart';
import '../../identity/presentation/cubit/auth_cubit.dart';
import '../data/place_history_cache.dart';
import '../domain/place.dart';

/// Owns the place lists the booking flow shows before the customer types:
/// saved addresses, recent ride drop-offs and picked-place history.
///
/// The book tab, the place picker and the pin picker read this instance
/// instead of querying the repositories, so opening one from another costs no
/// extra request and a list changed on one screen is already current on the
/// next. Each list loads on its own, once per signed-in account, and is
/// cleared on an account switch so one customer never sees another's places.
class PlaceListsStore extends ChangeNotifier {
  PlaceListsStore({
    required this._places,
    required this._addresses,
    required this._auth,
  }) {
    _ownerId = _signedInId(_auth.state);
    _authSub = _auth.stream.listen(_onAuthState);
  }

  final PlacesRepository _places;
  final AddressBookRepository _addresses;
  final AuthCubit _auth;
  late final StreamSubscription<AuthState> _authSub;

  String? _ownerId;

  List<PlaceOption> _saved = const [];
  List<PlaceOption> _recent = const [];
  List<PlaceOption> _history = const [];

  var _savedLoaded = false;
  var _recentLoaded = false;
  var _historyLoaded = false;

  Future<void>? _savedInFlight;
  Future<void>? _recentInFlight;
  Future<void>? _historyInFlight;

  var _disposed = false;

  List<PlaceOption> get saved => _saved;
  List<PlaceOption> get recent => _recent;
  List<PlaceOption> get history => _history;

  /// True until saved addresses and recent drop-offs have answered once;
  /// screens draw their skeleton list while it is set.
  bool get listsLoading => !_savedLoaded || !_recentLoaded;
  bool get historyLoading => !_historyLoaded;

  /// Saved addresses first, then recent drop-offs, capped for the book tab.
  List<PlaceOption> suggestions({int limit = 5}) {
    final rows = [..._saved, ..._recent];
    if (limit <= 0 || rows.length <= limit) {
      return List.unmodifiable(rows);
    }
    return List.unmodifiable(rows.sublist(0, limit));
  }

  Future<void> loadLists() => Future.wait([
    if (!_savedLoaded) _loadSaved(),
    if (!_recentLoaded) _loadRecent(),
  ]);

  Future<void> refreshLists() =>
      Future.wait([_loadSaved(force: true), _loadRecent(force: true)]);

  /// Recent drop-offs changed (a ride was created): the saved list stands.
  Future<void> refreshRecent() => _loadRecent(force: true);

  Future<void> loadHistory() {
    if (_historyLoaded) {
      return Future.value();
    }
    return _historyInFlight ??= _fetchHistory().whenComplete(() {
      _historyInFlight = null;
    });
  }

  Future<void> refreshHistory() {
    _historyLoaded = false;
    return loadHistory();
  }

  /// Takes the address book as another screen just read it, so an open
  /// booking screen updates without a second request for the same rows.
  void adoptSavedAddresses(List<SavedAddress> rows) {
    _saved = _savedOptions(rows);
    _savedLoaded = true;
    _notify();
  }

  /// Best-effort write of a picked place; the new row heads the history.
  Future<PlaceOption?> recordHistory(PlaceOption place) async {
    final token = _token;
    if (token == null) {
      return null;
    }
    final PlaceOption? row;
    try {
      row = await _places.recordHistory(accessToken: token, place: place);
    } catch (_) {
      return null;
    }
    if (row == null) {
      return null;
    }
    final key = placeDedupeKey(place);
    final next = [
      row,
      for (final old in _history)
        if (placeDedupeKey(old) != key && old.historyId != row.historyId) old,
    ].take(placeHistoryMax).toList(growable: false);
    _history = List.unmodifiable(next);
    _notify();
    unawaited(PlaceHistoryCache.save(_history));
    return row;
  }

  /// Removes one row at once and puts it back when the server rejects it.
  Future<bool> deleteHistory(String id) async {
    final token = _token;
    if (token == null) {
      return false;
    }
    final before = _history;
    _history = List.unmodifiable([
      for (final row in before)
        if (row.historyId != id) row,
    ]);
    _notify();
    try {
      await _places.deleteHistory(accessToken: token, id: id);
      await PlaceHistoryCache.save(_history);
      return true;
    } catch (_) {
      _history = before;
      _notify();
      return false;
    }
  }

  Future<bool> clearHistory() async {
    final token = _token;
    if (token == null) {
      return false;
    }
    final before = _history;
    _history = const [];
    _notify();
    try {
      await _places.clearHistory(accessToken: token);
      await PlaceHistoryCache.clear();
      return true;
    } catch (_) {
      _history = before;
      _notify();
      return false;
    }
  }

  void reset() {
    _saved = const [];
    _recent = const [];
    _history = const [];
    _savedLoaded = false;
    _recentLoaded = false;
    _historyLoaded = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_authSub.cancel());
    super.dispose();
  }

  String? get _token {
    final state = _auth.state;
    return state is AuthSignedIn ? state.tokens.accessToken : null;
  }

  Future<void> _loadSaved({bool force = false}) {
    if (!force && _savedLoaded) {
      return Future.value();
    }
    return _savedInFlight ??= _fetchSaved().whenComplete(() {
      _savedInFlight = null;
    });
  }

  Future<void> _loadRecent({bool force = false}) {
    if (!force && _recentLoaded) {
      return Future.value();
    }
    return _recentInFlight ??= _fetchRecent().whenComplete(() {
      _recentInFlight = null;
    });
  }

  Future<void> _fetchSaved() async {
    final owner = _ownerId;
    final token = _token;
    if (token != null) {
      try {
        final rows = await _addresses.list(accessToken: token);
        if (owner == _ownerId) {
          _saved = _savedOptions(rows);
        }
      } catch (_) {
        // Addresses are optional; the picker still offers recents and search.
      }
    }
    if (owner != _ownerId) {
      return;
    }
    _savedLoaded = true;
    _notify();
  }

  Future<void> _fetchRecent() async {
    final owner = _ownerId;
    final token = _token;
    if (token != null) {
      try {
        final rows = await _places.recentDestinations(accessToken: token);
        if (owner == _ownerId) {
          _recent = List.unmodifiable(rows);
        }
      } catch (_) {
        // See _fetchSaved: recent drop-offs are a convenience, not a
        // requirement for the booking screen.
      }
    }
    if (owner != _ownerId) {
      return;
    }
    _recentLoaded = true;
    _notify();
  }

  Future<void> _fetchHistory() async {
    final owner = _ownerId;
    final cached = await PlaceHistoryCache.load();
    if (owner != _ownerId) {
      return;
    }
    if (cached.isNotEmpty && _history.isEmpty) {
      _history = cached;
      _notify();
    }
    final token = _token;
    if (token != null) {
      try {
        final rows = await _places.history(accessToken: token);
        if (owner != _ownerId) {
          return;
        }
        _history = List.unmodifiable(rows);
        await PlaceHistoryCache.save(_history);
      } catch (_) {
        // Offline or older server: the device copy stays.
      }
    }
    if (owner != _ownerId) {
      return;
    }
    _historyLoaded = true;
    _notify();
  }

  static List<PlaceOption> _savedOptions(List<SavedAddress> rows) {
    return List.unmodifiable([
      for (final row in rows)
        if (row.lat != null && row.lng != null)
          PlaceOption(
            name: row.label,
            address: row.addressLine,
            lat: row.lat!,
            lng: row.lng!,
            source: PlaceSource.saved,
          ),
    ]);
  }

  void _onAuthState(AuthState state) {
    final next = _signedInId(state);
    if (next == _ownerId) {
      return;
    }
    _ownerId = next;
    reset();
  }

  static String? _signedInId(AuthState state) =>
      state is AuthSignedIn ? state.profile.id : null;

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
