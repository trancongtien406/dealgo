import 'package:dealgo/core/design_system/components/dealgo_contact_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// chat / call circles are ≥ 44 pt and 12 pt apart.
void main() {
  testWidgets('contact circles: 44 pt+ and a 12 pt gap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DealGoContactActions(
              children: [
                DealGoContactButton(
                  key: const Key('call'),
                  tooltip: 'Gọi',
                  filled: true,
                  onPressed: () => taps++,
                  icon: const Icon(Icons.call),
                ),
                DealGoContactButton(
                  key: const Key('chat'),
                  tooltip: 'Nhắn tin',
                  onPressed: () => taps++,
                  icon: const Icon(Icons.chat),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final call = tester.getRect(find.byKey(const Key('call')));
    final chat = tester.getRect(find.byKey(const Key('chat')));
    expect(call.width, greaterThanOrEqualTo(44));
    expect(call.height, greaterThanOrEqualTo(44));
    expect(chat.left - call.right, 12);
    await tester.tap(find.byKey(const Key('call')));
    await tester.tap(find.byKey(const Key('chat')));
    expect(taps, 2);
  });
}
