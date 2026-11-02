// Renders PNG previews of the transaction chat sheet (customer ride + driver food).
// Skipped unless a target directory is given:
//   flutter test test/chat_sheet_preview_test.dart \
//     --dart-define=CHAT_PREVIEW_DIR=/tmp/chat-preview
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dealgo/core/design_system/theme/dealgo_theme.dart';
import 'package:dealgo/core/design_system/tokens/dealgo_tokens.dart';
import 'package:dealgo/features/chat/presentation/cubit/chat_cubit.dart';
import 'package:dealgo/features/chat/presentation/widgets/transaction_chat_sheet.dart';
import 'package:dealgo/features/driver_card/domain/driver_card.dart';
import 'package:dealgo/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_chat_repository.dart';

const _outDir = String.fromEnvironment('CHAT_PREVIEW_DIR');

Future<void> _loadFonts() async {
  final be = FontLoader('BeVietnamPro');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/BeVietnamPro-$w.ttf').readAsBytesSync();
    be.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await be.load();
  final lucide = FontLoader('packages/lucide_icons_flutter/Lucide')
    ..addFont(
      rootBundle.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
    );
  await lucide.load();
}

Future<void> _shot(
  WidgetTester tester,
  String name, {
  required FakeChatRepository repo,
  required DriverCardRepository cards,
  required ChatThreadKind kind,
  required ChatViewer viewer,
  List<String> typed = const [],
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: chatProviders(
        repo,
        extra: [RepositoryProvider<DriverCardRepository>.value(value: cards)],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: DealGoTheme.light,
          locale: const Locale('vi'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: DealGoColors.canvas,
              body: Center(
                child: TextButton(
                  key: const Key('open'),
                  onPressed: () => showTransactionChatSheet(
                    context: context,
                    kind: kind,
                    resourceId: 'job-1',
                    accessToken: 'tok',
                    currentUserId: 'me',
                    viewer: viewer,
                    onCall: () {},
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open')));
  await tester.pumpAndSettle();
  for (final text in typed) {
    await tester.enterText(find.byKey(const Key('chat-input')), text);
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_outDir/preview-$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('chat sheet previews', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    tester.view
      ..physicalSize = const Size(390, 844)
      ..devicePixelRatio = 1
      ..padding = const FakeViewPadding(top: 47, bottom: 34)
      ..viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);
    await tester.runAsync(_loadFonts);

    final now = DateTime.now();
    DateTime ago(int minutes) =>
        now.subtract(Duration(minutes: minutes)).toUtc();
    final yesterday = DateTime(now.year, now.month, now.day - 1, 21, 40);

    final customer = FakeChatRepository(
      messages: [
        chatMessage('y1', 'me', 'Mai anh đón em sớm nhé', yesterday.toUtc()),
        chatMessage('c1', 'drv', 'Chào chị, em là tài xế DealGo', ago(9)),
        chatMessage('c2', 'drv', 'Em đang tới, khoảng 5 phút nữa ạ', ago(9)),
        chatMessage('c3', 'drv', '📞 Cuộc gọi nhỡ', ago(7)),
        chatMessage('c4', 'me', 'Ok em', ago(6)),
        chatMessage('c5', 'me', 'Chị đứng ở cổng chính toà nhà', ago(6)),
        chatMessage('c6', 'drv', 'Dạ em thấy rồi', ago(1)),
      ],
    )..failBodies.add('Áo xanh, cầm ô nha em');
    customer.failAlways = true;
    await _shot(
      tester,
      'customer',
      repo: customer,
      cards: FakeDriverCards(
        card: const DriverCard(
          driverId: 'drv',
          displayName: 'Nguyễn Văn An',
          vehicleType: 'Honda Vision',
          vehiclePlate: '43A-123.45',
        ),
      ),
      kind: ChatThreadKind.ride,
      viewer: ChatViewer.customer,
      typed: const ['Áo xanh, cầm ô nha em'],
    );

    final driver = FakeChatRepository(
      senderId: 'me',
      messages: [
        chatMessage('d1', 'cus', 'Anh ơi giao tới sảnh B giúp em', ago(4)),
        chatMessage('d2', 'me', 'Dạ, em lấy món xong rồi', ago(3)),
      ],
    )..hangBodies.add('Tôi đang giao tới');
    await _shot(
      tester,
      'driver',
      repo: driver,
      cards: FakeDriverCards(customerName: 'Trần Thị Lan'),
      kind: ChatThreadKind.foodOrder,
      viewer: ChatViewer.driver,
      typed: const ['Tôi đang giao tới'],
    );

    await _shot(
      tester,
      'empty',
      repo: FakeChatRepository(),
      cards: FakeDriverCards(customerName: 'Lê Minh'),
      kind: ChatThreadKind.ride,
      viewer: ChatViewer.driver,
    );
    debugDefaultTargetPlatformOverride = null;
  }, skip: _outDir.isEmpty);
}
