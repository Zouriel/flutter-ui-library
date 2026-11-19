import 'dart:typed_data';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import 'media_helpers.dart';

const _menu = [
  UiMenuItem(label: 'Change cover', value: 'change'),
  UiMenuItem(label: 'Remove cover', value: 'remove', danger: true),
];

void main() {
  testWidgets('image enables on-media ink; no image uses the page surface and ordinary ink', (tester) async {
    final image = await testImage(tester);
    await pumpUi(tester, UiCoverHero(image: image, child: const UiText('Eid party', variant: UiTextVariant.h2)));
    var context = tester.element(find.byType(UiCoverHero));
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Text>(find.text('Eid party')).style!.color, context.ui.mediaOnScrim);

    await pumpUi(tester, const UiCoverHero(child: UiText('Eid party', variant: UiTextVariant.h2)));
    context = tester.element(find.byType(UiCoverHero));
    expect(find.byType(Image), findsNothing);
    expect(tester.widget<Text>(find.text('Eid party')).style!.color, context.ui.text);
  });

  testWidgets('a failed image falls back cleanly', (tester) async {
    await pumpUi(tester, UiCoverHero(image: MemoryImage(Uint8List.fromList([1, 2, 3])), child: const UiText('Event')));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(tester.widget<Text>(find.text('Event')).style!.color, tester.element(find.byType(UiCoverHero)).ui.text);
  });

  testWidgets('tap, right-click and long-press open the editable cover menu and selection is reported', (tester) async {
    final picked = <String>[];
    final image = await testImage(tester);
    await pumpUi(tester, UiCoverHero(image: image, coverMenu: _menu, onCoverMenuSelected: (item) => picked.add(item.value)));
    await tester.tap(find.bySemanticsLabel('Change cover image'));
    await tester.pumpAndSettle();
    expect(find.text('Remove cover'), findsOneWidget);
    await tester.tap(find.text('Remove cover'));
    await tester.pumpAndSettle();
    expect(picked, ['remove']);

    await tester.tap(find.bySemanticsLabel('Change cover image'), buttons: kSecondaryMouseButton, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('Change cover'), findsOneWidget);
    await tester.tapAt(const Offset(380, 800));
    await tester.pumpAndSettle();
    await tester.longPress(find.bySemanticsLabel('Change cover image'));
    await tester.pumpAndSettle();
    expect(find.text('Change cover'), findsOneWidget);
  });

  testWidgets('top slots mirror in RTL and the body width changes at 600', (tester) async {
    Widget hero(TextDirection direction, double width) => Directionality(
      textDirection: direction,
      child: SizedBox(width: width, child: const UiCoverHero(
        topStart: SizedBox(key: Key('start'), width: 30, height: 20),
        topEnd: SizedBox(key: Key('end'), width: 30, height: 20),
        child: SizedBox(key: Key('body'), height: 20),
      )),
    );
    await pumpUi(tester, hero(TextDirection.ltr, 390));
    var space4 = tester.element(find.byType(UiCoverHero)).ui.space4;
    expect(tester.getTopLeft(find.byKey(const Key('start'))).dx, lessThan(tester.getTopLeft(find.byKey(const Key('end'))).dx));
    expect(tester.getSize(find.byKey(const Key('body'))).width, closeTo((390 - space4 * 2) * 0.85, 0.01));
    await pumpUi(tester, hero(TextDirection.rtl, 700), size: const Size(700, 844));
    space4 = tester.element(find.byType(UiCoverHero)).ui.space4;
    expect(tester.getTopLeft(find.byKey(const Key('start'))).dx, greaterThan(tester.getTopLeft(find.byKey(const Key('end'))).dx));
    expect(tester.getSize(find.byKey(const Key('body'))).width, closeTo((700 - space4 * 2) * 0.69, 0.01));
  });

  testWidgets('golden: cover hero in dark and light themes', (tester) async {
    final image = await testImage(tester, w: 600, h: 340, seed: 1);
    await expectThemedGoldenAfter(
      tester,
      'cover_hero',
      height: 304,
      (context) => UiCoverHero(
        image: image,
        coverMenu: _menu,
        topStart: UiButton(label: 'Your events', variant: UiButtonVariant.ghost, size: UiSize.sm, onPressed: () {}),
        topEnd: UiIconButton(icon: const UiIcon(HugeIcons.strokeRoundedMoreVertical), label: 'Options', size: UiSize.sm, onPressed: () {}),
        actions: UiButton(label: 'Share with client', onPressed: () {}),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, spacing: 4, children: [
          UiText('Eid party', variant: UiTextVariant.h2),
          UiText('Saturday 12 December · Malé', variant: UiTextVariant.caption),
        ]),
      ),
      before: (tester) async {
        await tester.runAsync(() async {
          await precacheImage(image, tester.element(find.byType(UiCoverHero).first));
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });
}
