import 'package:dealgo/core/ui/keyboard_dismiss.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe {
  var pressed = 0;
  var sent = 0;
}

Future<_Probe> _pump(WidgetTester tester) async {
  final probe = _Probe();
  await tester.pumpWidget(
    MaterialApp(
      scrollBehavior: const DealGoScrollBehavior(),
      builder: (context, child) => KeyboardDismissOnTapOutside(child: child!),
      home: Scaffold(
        body: Column(
          children: [
            const TextField(key: Key('a')),
            const TextField(key: Key('b')),
            ElevatedButton(
              key: const Key('button'),
              onPressed: () => probe.pressed++,
              child: const Text('Tiếp tục'),
            ),
            TextFieldTapRegion(
              child: IconButton(
                key: const Key('send'),
                onPressed: () => probe.sent++,
                icon: const Icon(Icons.send),
              ),
            ),
            // Stand-in for a map: pans must not close the keyboard.
            GestureDetector(
              key: const Key('map'),
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (_) {},
              child: const SizedBox(height: 120, width: 300),
            ),
            Expanded(
              child: ListView(
                key: const Key('list'),
                children: [
                  for (var i = 0; i < 40; i++)
                    SizedBox(height: 40, child: Text('Dòng $i')),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return probe;
}

bool _focused(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
      ),
    )
    .focusNode
    .hasFocus;

void main() {
  final mobile = TargetPlatformVariant.mobile();

  testWidgets('tap on empty space closes the keyboard', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    expect(_focused(tester, 'a'), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tapAt(const Offset(390, 590));
    await tester.pump();
    expect(_focused(tester, 'a'), isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  }, variant: mobile);

  testWidgets('a button outside still fires, then the keyboard closes', (
    tester,
  ) async {
    final probe = await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('button')));
    await tester.pump();
    expect(probe.pressed, 1);
    expect(_focused(tester, 'a'), isFalse);
  }, variant: mobile);

  testWidgets('tapping another field moves focus, keyboard stays', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('b')));
    await tester.pump();
    expect(_focused(tester, 'b'), isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: mobile);

  testWidgets('composer send (TextFieldTapRegion) keeps focus', (tester) async {
    final probe = await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('send')));
    await tester.pump();
    expect(probe.sent, 1);
    expect(_focused(tester, 'a'), isTrue);
  }, variant: mobile);

  testWidgets('panning a map keeps the keyboard', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    await tester.drag(find.byKey(const Key('map')), const Offset(80, 0));
    await tester.pump();
    expect(_focused(tester, 'a'), isTrue);
  }, variant: mobile);

  testWidgets('dragging a list closes the keyboard', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('a')));
    await tester.pump();
    await tester.drag(find.byKey(const Key('list')), const Offset(0, -200));
    await tester.pump();
    expect(_focused(tester, 'a'), isFalse);
  });
}
