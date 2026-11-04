import '../domain/payment_models.dart';

/// Short-lived cache for `GET /v1/payments/methods`.
///
/// Checkout renders the method picker inside a lazily built list, so scrolling
/// it out of the viewport disposes the tile state. Availability is a
/// per-service property that changes rarely, so reusing the last answer keeps
/// a checkout session from issuing a request per scroll pass.
class PaymentMethodsCache {
  PaymentMethodsCache({this.ttl = const Duration(minutes: 5)});

  final Duration ttl;
  final Map<String, _CacheEntry> _entries = {};
  final Map<String, Future<List<PaymentMethodOption>>> _pending = {};

  Future<List<PaymentMethodOption>> read(
    String service,
    Future<List<PaymentMethodOption>> Function() fetch,
  ) {
    final cached = _entries[service];
    if (cached != null && !cached.isExpired(ttl)) {
      return Future.value(cached.methods);
    }
    final pending = _pending[service];
    if (pending != null) {
      return pending;
    }
    final tracked = fetch()
        .then((methods) {
          _entries[service] = _CacheEntry(
            methods: List.unmodifiable(methods),
            fetchedAt: DateTime.now(),
          );
          return methods;
        })
        .whenComplete(() {
          _pending.remove(service);
        });
    _pending[service] = tracked;
    return tracked;
  }

  void invalidate([String? service]) {
    if (service == null) {
      _entries.clear();
      return;
    }
    _entries.remove(service);
  }
}

class _CacheEntry {
  const _CacheEntry({required this.methods, required this.fetchedAt});

  final List<PaymentMethodOption> methods;
  final DateTime fetchedAt;

  bool isExpired(Duration ttl) => DateTime.now().difference(fetchedAt) >= ttl;
}
