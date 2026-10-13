import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';
import 'fake_video.dart';

void main() {
  late List<UiMediaItem> items;
  late List<String> events;

  Future<void> open(WidgetTester tester, {int at = 0, List<UiMediaAction> actions = const []}) async {
    await pumpUi(tester, Builder(builder: (context) => UiButton(
          label: 'Open',
          onPressed: () => UiMediaLightbox.show(
            context,
            items: items,
            initialIndex: at,
            label: 'Party',
            actions: actions,
            onIndexChanged: (i) => events.add('index $i'),
            onAction: (id, item, i) => events.add('$id $i'),
          ).then((v) => events.add('closed $v')),
        )));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  setUp(() => events = []);

  /// Three real photographs, decoded before use.
  Future<void> photos(WidgetTester tester) async {
    final imgs = [for (var i = 0; i < 3; i++) await testImage(tester, w: 200, h: 150, seed: i)];
    items = [for (var i = 0; i < 3; i++) UiMediaItem.image(imgs[i], alt: 'Photo $i', caption: i == 1 ? 'Cake' : null)];
    await pumpUi(tester, const SizedBox());
    await tester.runAsync(() async {
      for (final i in imgs) {
        await precacheImage(i, tester.element(find.byType(SizedBox).first));
      }
    });
  }

  testWidgets('counter, swipe to step, filmstrip, the label when no caption', (tester) async {
    await photos(tester);
    await open(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Party'), findsOneWidget);
    await tester.fling(find.byType(UiMediaLightbox), const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Cake'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Item 3'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    // Nothing after the last: a swipe does not wrap.
    await tester.fling(find.byType(UiMediaLightbox), const Offset(-200, 0), 1200);
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);
    expect(events, ['index 1', 'index 2']);
  });

  testWidgets('drag down dismisses; a short drag springs back', (tester) async {
    await photos(tester);
    await open(tester, at: 1);
    await tester.drag(find.byType(UiMediaLightbox), const Offset(0, 60));
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsOneWidget);
    await tester.drag(find.byType(UiMediaLightbox), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsNothing);
    expect(events, ['closed 1']);
  });

  testWidgets('close button, back, and Escape close; keys step', (tester) async {
    await photos(tester);
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsNothing);
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(UiMediaLightbox), findsNothing);
  });

  testWidgets('actions show only where they apply and report the item', (tester) async {
    await photos(tester);
    await open(tester, actions: [
      const UiMediaAction(id: 'download', label: 'Download'),
      UiMediaAction(id: 'remove', label: 'Remove', danger: true, when: (item, i) => i == 1),
    ]);
    expect(find.text('Remove'), findsNothing);
    await tester.tap(find.text('Download'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    expect(events, ['download 0', 'index 1', 'remove 1']);
  });

  testWidgets('photographs zoom with a double tap; the chip resets it', (tester) async {
    final img = await testImage(tester, w: 300, h: 200);
    items = [UiMediaItem.image(img, alt: 'Beach')];
    await pumpUi(tester, const SizedBox());
    await tester.runAsync(() => precacheImage(img, tester.element(find.byType(SizedBox).first)));
    await open(tester);
    final center = tester.getCenter(find.byType(UiMediaLightbox));
    await tester.tapAt(center);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(center);
    await tester.pumpAndSettle();
    expect(find.text('250% · Fit'), findsOneWidget);
    await tester.tap(find.text('250% · Fit'));
    await tester.pumpAndSettle();
    expect(find.text('250% · Fit'), findsNothing);
  });

  testWidgets('clips start themselves, the chrome fades while playing and returns on a tap', (tester) async {
    final fake = FakeVideoPlatform.install();
    items = [UiMediaItem.video('https://x/clip.mp4', caption: 'Toast')];
    await open(tester);
    expect(fake.calls, contains('play 1'));
    expect(find.text('2:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    // Bare: the bars are faded and unpressable.
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Toast'), matching: find.byType(AnimatedOpacity)).first).opacity, 0);
    // A tap on the picture pauses the clip and brings the chrome back.
    await tester.tapAt(tester.getCenter(find.byType(UiMediaLightbox)));
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'pause 1');
    expect(tester.widget<AnimatedOpacity>(find.ancestor(of: find.text('Toast'), matching: find.byType(AnimatedOpacity)).first).opacity, 1);
    expect(find.bySemanticsLabel('Play'), findsWidgets);
    // Keys: m mutes, l seeks forward.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyL);
    await tester.pump();
    expect(fake.volume[1], 0);
    expect(fake.calls.last, 'seek 1 10');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    expect(fake.calls, contains('dispose 1'));
  });

  testWidgets('chrome controls meet the touch guidelines', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final handle = tester.ensureSemantics();
    await photos(tester);
    await open(tester, actions: const [UiMediaAction(id: 'download', label: 'Download')]);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('golden: lightbox over a photo with actions and filmstrip', (tester) async {
    final a = await testImage(tester, w: 300, h: 200, seed: 0);
    final b = await testImage(tester, w: 200, h: 200, seed: 1);
    final c = await testImage(tester, w: 200, h: 300, seed: 2);
    final list = [
      UiMediaItem.image(a, caption: 'Sunrise · Aisha'),
      UiMediaItem.image(b),
      UiMediaItem.image(c),
      UiMediaItem.video('x.mp4', thumb: b),
    ];
    FakeVideoPlatform.install();
    await expectThemedGoldenAfter(tester, 'lightbox', height: 640, (context) => ClipRect(
          child: UiMediaLightbox(
            items: list,
            index: 0,
            onIndexChanged: (_) {},
            onClose: () {},
            actions: const [UiMediaAction(id: 'dl', label: 'Download'), UiMediaAction(id: 'rm', label: 'Remove', danger: true)],
          ),
        ), before: (tester) async {
      await tester.runAsync(() async {
        for (final i in [a, b, c]) {
          await precacheImage(i, tester.element(find.byType(UiMediaLightbox).first));
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(const Duration(milliseconds: 400));
    });
  });
}
