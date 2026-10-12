import 'package:flutter_test/flutter_test.dart';

import 'package:dealgo/main.dart';

void main() {
  testWidgets('DealGo home shows brand', (WidgetTester tester) async {
    await tester.pumpWidget(const DealGoApp());

    expect(find.text('DealGo'), findsOneWidget);
    expect(
      find.textContaining('Ride & Food'),
      findsOneWidget,
    );
  });
}
