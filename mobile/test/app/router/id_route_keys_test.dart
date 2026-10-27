import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Deep-linking from /…/orders/A to /…/orders/B must rebuild the
/// page state (otherwise the old order stays on screen). Id-param pages are
/// keyed by their id in the router.
void main() {
  test('id-param pages in app_router are keyed by id', () {
    final src = File('lib/app/router/app_router.dart').readAsStringSync();
    final unkeyed = RegExp(r'child: [A-Za-z]+Page\((orderId|rideId|storeId): ')
        .allMatches(src)
        .map((m) => m.group(0))
        .toList();
    expect(unkeyed, isEmpty);
    expect(src.contains('FoodTrackingPage(key: ValueKey(orderId)'), isTrue);
    expect(src.contains('RideOffersPage(key: ValueKey(rideId)'), isTrue);
  });
}
