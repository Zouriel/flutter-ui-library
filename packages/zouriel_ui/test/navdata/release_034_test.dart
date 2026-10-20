import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

Future<void> _app(WidgetTester tester, Widget home, {UiConfig config = const UiConfig(), EdgeInsets padding = EdgeInsets.zero, Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size * tester.view.devicePixelRatio;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MediaQuery(
    data: MediaQueryData(size: size, padding: padding),
    child: UiApp(config: config, home: home),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('timeline states', () {
    testWidgets('current is read as the current step, upcoming as upcoming and muted; no state is as before', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 320, child: UiTimeline(items: [
        UiTimelineItem(title: 'Requested', state: UiTimelineItemState.done),
        UiTimelineItem(title: 'On the way', state: UiTimelineItemState.current),
        UiTimelineItem(title: 'Visit', state: UiTimelineItemState.upcoming),
        UiTimelineItem(title: 'Plain'),
      ])));
      final hints = <String>[];
      void walk(SemanticsNode n) {
        final h = n.getSemanticsData().hint;
        if (h.isNotEmpty) hints.add(h);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }
      walk(tester.getSemantics(find.byType(UiTimeline)));
      expect(hints, ['Current step', 'Upcoming']);
      final t = uiThemeTokens[UiThemeName.dark]!;
      TextStyle? style(String title) {
        TextStyle? found;
        for (final rt in tester.widgetList<RichText>(find.descendant(of: find.byType(UiTimeline), matching: find.byType(RichText)))) {
          rt.text.visitChildren((span) {
            if (span is TextSpan && span.text == title) found = span.style;
            return found == null;
          });
        }
        return found;
      }
      expect(style('Visit')!.color, t.textMuted);
      expect(style('On the way')!.fontWeight, FontWeight.w600);
      handle.dispose();
    });
  });

  group('floating panel', () {
    testWidgets('16px in from the edges plus the safe area, at the bottom or top, and the page around it stays touchable', (tester) async {
      var taps = 0;
      await _app(
        tester,
        Stack(children: [
          Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++)),
          const UiFloatingPanel(semanticLabel: 'Nurse', child: SizedBox(height: 80, child: Text('Card'))),
        ]),
        padding: const EdgeInsets.only(bottom: 34, left: 4),
      );
      final panel = tester.getRect(find.descendant(of: find.byType(UiFloatingPanel), matching: find.byType(DecoratedBox)).first);
      expect(panel.left, 16 + 4);
      expect(panel.right, 390 - 16);
      expect(panel.bottom, 844 - 16 - 34);
      await tester.tapAt(const Offset(195, 100));
      expect(taps, 1, reason: 'non-modal: the page above it still takes taps');
    });

    testWidgets('top placement, and at most 480 wide, centred, on a wide screen', (tester) async {
      await _app(
        tester,
        const Stack(children: [UiFloatingPanel(placement: UiFloatingPanelPlacement.top, child: SizedBox(height: 60))]),
        size: const Size(1200, 800),
        padding: const EdgeInsets.only(top: 24),
      );
      final panel = tester.getRect(find.descendant(of: find.byType(UiFloatingPanel), matching: find.byType(DecoratedBox)).first);
      expect(panel.top, 16 + 24);
      expect(panel.width, 480);
      expect(panel.center.dx, closeTo(600, 0.5));
    });
  });

  group('row actions', () {
    testWidgets('space2 apart, at the end, wrapping when narrow; start when asked; mirrored in RTL', (tester) async {
      Widget acts({UiRowActionsAlign align = UiRowActionsAlign.end, double width = 300}) => SizedBox(
            width: width,
            child: UiRowActions(align: align, children: [
              UiButton(key: const Key('a'), label: 'View', size: UiSize.sm, onPressed: () {}),
              UiButton(key: const Key('b'), label: 'Edit', size: UiSize.sm, onPressed: () {}),
            ]),
          );
      await pumpUi(tester, acts());
      final a = tester.getRect(find.byKey(const Key('a'))), b = tester.getRect(find.byKey(const Key('b')));
      expect(b.left - a.right, greaterThanOrEqualTo(8 - 0.01));
      expect(b.right, closeTo(300, 0.5), reason: 'at the end');
      await tester.pumpWidget(const SizedBox());
      await pumpUi(tester, acts(width: 90));
      expect(tester.getRect(find.byKey(const Key('b'))).top, greaterThan(tester.getRect(find.byKey(const Key('a'))).top), reason: 'wraps');
      await tester.pumpWidget(const SizedBox());
      await pumpUi(tester, Directionality(textDirection: TextDirection.rtl, child: acts()));
      expect(tester.getRect(find.byKey(const Key('b'))).left, closeTo(0, 0.5), reason: 'the end is the left in RTL');
    });
  });

  group('built-in strings', () {
    testWidgets('English by default; UiConfig.strings replaces some and keeps the rest', (tester) async {
      final handle = tester.ensureSemantics();
      Widget page() => SizedBox(width: 380, child: UiPagination(page: 2, total: 5, onChanged: (_) {}));
      await _app(tester, Center(child: page()));
      expect(find.bySemanticsLabel('Previous page'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await _app(tester, Center(child: page()), config: const UiConfig(strings: UiStrings(previousPage: 'ކުރީ ޞަފްޙާ')));
      expect(find.bySemanticsLabel('ކުރީ ޞަފްޙާ'), findsOneWidget);
      expect(find.bySemanticsLabel('Next page'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('file upload: label and hint, defaulting to the built-in words; empty hint hides it', (tester) async {
      Future<String> shown(UiFileUpload w) async {
        await tester.pumpWidget(const SizedBox());
        await pumpUi(tester, SizedBox(width: 320, child: w));
        return tester.widget<RichText>(find.descendant(of: find.byType(UiFileUpload), matching: find.byType(RichText)).first).text.toPlainText();
      }

      expect(await shown(UiFileUpload(picker: ({required accept, required multiple}) async => [], dropEnabled: true)), 'Tap to upload or drag & drop');
      expect(await shown(UiFileUpload(picker: ({required accept, required multiple}) async => [], dropEnabled: true, label: 'ފައިލް', hint: '')), 'ފައިލް');
      expect(await shown(UiFileUpload(picker: ({required accept, required multiple}) async => [])), 'Tap to upload');
    });
  });
}
