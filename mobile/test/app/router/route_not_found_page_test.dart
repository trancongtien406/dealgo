import 'package:dealgo/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('route-not-found page is friendly Vietnamese, no debug text', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DealGoRouteNotFoundPage()));
    expect(find.byKey(const Key('route-not-found-title')), findsOneWidget);
    expect(find.text('Về trang chủ'), findsOneWidget);
    expect(find.textContaining('GoException'), findsNothing);
  });
}
