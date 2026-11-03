import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';
import '../media/media_helpers.dart';

// 0.53.0: the lightbox's top bar never overflows. Labelled pills when they fit, icon buttons when
// they don't, and a More menu for what still doesn't fit.

const _all = [
  ('save', 'Save to gallery', HugeIcons.strokeRoundedDownload04, false),
  ('share', 'Share', HugeIcons.strokeRoundedShare08, false),
  ('original', 'Download original', HugeIcons.strokeRoundedImage01, false),
  ('remove', 'Remove', HugeIcons.strokeRoundedDelete02, true),
];

List<UiMediaAction> _actions(int n, {required bool icons}) => [
      for (final (id, label, icon, danger) in _all.take(n)) UiMediaAction(id: id, label: label, icon: icons ? UiIcon(icon) : null, danger: danger),
    ];

void main() {
  late List<UiMediaItem> items;

  Future<List<String>> open(WidgetTester tester, {required double width, required List<UiMediaAction> actions, UiThemeName theme = UiThemeName.dark}) async {
    final events = <String>[];
    final img = await testImage(tester, w: 200, h: 150, seed: 1);
    items = [UiMediaItem.image(img, alt: 'Photo 0', caption: 'Aisha, 12 Dec'), UiMediaItem.image(img, alt: 'Photo 1')];
    // Decoded before use, or the spinner never settles.
    await pumpUi(tester, const SizedBox());
    await tester.runAsync(() => precacheImage(img, tester.element(find.byType(SizedBox).first)));
    await pumpUi(
      tester,
      Builder(builder: (context) => UiButton(
            label: 'Open',
            onPressed: () => UiMediaLightbox.show(context, items: items, label: 'Party', actions: actions, onAction: (id, item, i) => events.add(id)),
          )),
      theme: theme,
      size: Size(width, 760),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return events;
  }

  String fitOf(WidgetTester tester) {
    final k = tester.widget<KeyedSubtree>(find.byWidgetPredicate((w) => w is KeyedSubtree && w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('fit:'))).key! as ValueKey<String>;
    return k.value.substring(4);
  }

  for (final theme in [UiThemeName.dark, UiThemeName.light]) {
    for (final width in [320.0, 360.0, 390.0]) {
      for (final n in [2, 3, 4]) {
        for (final icons in [true, false]) {
          testWidgets('${theme.name} $width wide, $n actions ${icons ? 'with' : 'without'} icons: no overflow, every action named and reachable', (tester) async {
            final handle = tester.ensureSemantics();
            final actions = _actions(n, icons: icons);
            final events = await open(tester, width: width, actions: actions, theme: theme);
            expect(tester.takeException(), isNull, reason: 'overflow');
            final fit = fitOf(tester);
            final close = tester.getRect(find.bySemanticsLabel('Close'));
            expect(close.right, lessThanOrEqualTo(width), reason: 'close on screen');
            final inMenu = <UiMediaAction>[];
            for (final a in actions) {
              final b = find.byKey(ValueKey('action:${a.id}'));
              if (b.evaluate().isEmpty) {
                inMenu.add(a);
                continue;
              }
              final r = tester.getRect(b);
              expect(r.left, greaterThanOrEqualTo(0), reason: '${a.label} on screen');
              expect(r.right, lessThanOrEqualTo(close.left), reason: '${a.label} before close');
              // Named by its label, pill or icon.
              expect(find.descendant(of: find.byType(UiMediaLightbox), matching: find.bySemanticsLabel(a.label)), findsOneWidget, reason: a.label);
              if (fit != 'labelled' && icons) {
                expect(find.descendant(of: b, matching: find.text(a.label)), findsNothing, reason: '${a.label} icon only');
                expect(find.ancestor(of: b, matching: find.byWidgetPredicate((w) => w is UiTooltip && w.message == a.label)), findsOneWidget);
              }
            }
            if (inMenu.isEmpty) {
              expect(find.bySemanticsLabel('More actions'), findsNothing);
            } else {
              expect(fit, 'menu');
              // The menu holds the last ones, in order.
              expect(inMenu.map((a) => a.id), actions.sublist(actions.length - inMenu.length).map((a) => a.id));
              await tester.tap(find.bySemanticsLabel('More actions'));
              await tester.pumpAndSettle();
              for (final a in inMenu) {
                expect(find.text(a.label), findsOneWidget, reason: '${a.label} in the menu');
              }
              await tester.tap(find.text(inMenu.last.label));
              await tester.pumpAndSettle();
              expect(events, [inMenu.last.id]);
              expect(tester.takeException(), isNull);
            }
            // Wide labels fit on 390 with two actions; three icons are icon buttons on 360.
            if (width == 390 && n == 2) expect(fit, 'labelled');
            if (width == 360 && n == 3 && icons) expect(fit, 'icons');
            if (!icons && width == 320 && n == 4) expect(fit, 'menu');
            handle.dispose();
          });
        }
      }
    }
  }

  testWidgets('danger keeps its colour as an icon button; pressing it reports the action', (tester) async {
    final events = await open(tester, width: 360, actions: _actions(4, icons: true));
    final remove = find.byKey(const ValueKey('action:remove'));
    if (remove.evaluate().isNotEmpty) {
      final icon = tester.widget<IconTheme>(find.descendant(of: remove, matching: find.byType(IconTheme)).last);
      expect(icon.data.color, tester.element(remove).ui.mediaDanger);
      await tester.tap(remove);
      expect(events, ['remove']);
    } else {
      await tester.tap(find.bySemanticsLabel('More actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      expect(events, ['remove']);
    }
  });

  testWidgets('golden: 360 with three icon actions', (tester) async {
    await open(tester, width: 360, actions: _actions(3, icons: true));
    await expectLater(find.byType(UiMediaLightbox), matchesGoldenFile('goldens/lightbox_actions_360.png'));
  });

  testWidgets('golden: 320 with four actions without icons (a More menu)', (tester) async {
    await open(tester, width: 320, actions: _actions(4, icons: false), theme: UiThemeName.light);
    await expectLater(find.byType(UiMediaLightbox), matchesGoldenFile('goldens/lightbox_actions_320.png'));
  });
}
