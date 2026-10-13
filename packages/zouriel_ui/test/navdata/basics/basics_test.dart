import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../../helpers.dart';

void main() {
  group('UiLink', () {
    testWidgets('is one link node with its address; external says it leaves the app', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpUi(tester, Column(children: [
        UiLink('Docs', href: 'https://example.com/docs', onTap: () => taps++),
        UiLink('GitHub', external: true, onTap: () {}),
      ]));
      final docs = tester.getSemantics(find.byType(UiLink).first).getSemanticsData();
      expect(docs.flagsCollection.isLink, isTrue);
      expect(docs.label, 'Docs');
      expect(docs.linkUrl, Uri.parse('https://example.com/docs'));
      expect(find.bySemanticsLabel('GitHub (opens outside the app)'), findsOneWidget);
      await tester.tap(find.text('Docs'));
      expect(taps, 1);
      handle.dispose();
    });

    testWidgets('Enter activates a focused link', (tester) async {
      var taps = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpUi(tester, UiLink('Go', focusNode: node, onTap: () => taps++));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(taps, 1);
    });

    testWidgets('underlined, coloured by tone', (tester) async {
      await pumpUi(tester, Column(children: [
        UiLink('P', onTap: () {}),
        UiLink('M', tone: UiLinkTone.muted, onTap: () {}),
      ]));
      final t = uiThemeTokens[UiThemeName.dark]!;
      final p = tester.widget<Text>(find.text('P')).style!;
      expect(p.decoration, TextDecoration.underline);
      expect(p.color, t.primary);
      expect(tester.widget<Text>(find.text('M')).style!.color, t.textMuted);
    });
  });

  group('UiKbd', () {
    testWidgets('sizes from the surrounding text and reads its label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const DefaultTextStyle(style: TextStyle(fontSize: 20), child: Row(mainAxisSize: MainAxisSize.min, children: [UiKbd('K'), UiKbd('Cmd', semanticLabel: 'Command')])));
      expect(tester.getSize(find.byType(UiKbd).first).height, 30); // 1.5em
      expect(tester.getSize(find.byType(UiKbd).first).width, greaterThanOrEqualTo(28)); // min 1.4em
      expect(find.bySemanticsLabel('Command'), findsOneWidget);
      handle.dispose();
    });
  });

  group('UiMeter', () {
    testWidgets('turns warning then danger and says so in text and semantics', (tester) async {
      final handle = tester.ensureSemantics();
      Future<SemanticsData> at(double v) async {
        await pumpUi(tester, SizedBox(width: 300, child: UiMeter(value: v, max: 800, warnAt: 600, label: 'Bundle', valueText: '$v KB')));
        return tester.getSemantics(find.byType(UiMeter)).getSemanticsData();
      }

      var d = await at(200);
      expect(d.label, 'Bundle');
      expect(d.value, '200.0 KB');
      expect(find.textContaining('Getting large'), findsNothing);
      d = await at(700);
      expect(d.value, '700.0 KB, Getting large');
      expect(find.textContaining('Getting large'), findsOneWidget);
      d = await at(900);
      expect(d.value, '900.0 KB, Over the limit');
      expect(const UiMeter(value: 900, max: 800).level, UiMeterLevel.danger);
      expect(const UiMeter(value: 50, dangerAt: 40).level, UiMeterLevel.danger);
      expect(const UiMeter(value: 50, warnAt: 50).level, UiMeterLevel.ok); // "past", not "at"
      handle.dispose();
    });

    testWidgets('the fill covers the value share of the track', (tester) async {
      await pumpUi(tester, const SizedBox(width: 300, child: UiMeter(value: 25, label: 'Disk')));
      final fill = find.descendant(of: find.byType(UiMeter), matching: find.byType(AnimatedContainer));
      expect(tester.getSize(fill).width, 75);
      expect(find.text('25 / 100'), findsOneWidget);
    });
  });

  group('UiProgressCircle', () {
    testWidgets('announces its label and percentage, clamps, and shows the value', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const UiProgressCircle(value: 130, label: 'Upload', showValue: true, size: 56));
      final d = tester.getSemantics(find.byType(UiProgressCircle)).getSemanticsData();
      expect(d.label, 'Upload');
      expect(d.value, '100%');
      expect(find.text('100%'), findsOneWidget);
      expect(tester.getSize(find.byType(UiProgressCircle)), const Size(56, 56));
      handle.dispose();
    });

    testWidgets('indeterminate keeps turning', (tester) async {
      await tester.pumpWidget(const UiApp(home: Center(child: UiProgressCircle())));
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.hasRunningAnimations, isTrue);
    });
  });

  group('UiStatCard / UiEmptyState / UiResult', () {
    testWidgets('a stat card is read as one sentence including the direction', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, const SizedBox(width: 200, child: UiStatCard(label: 'Revenue', value: r'$12.4k', delta: '8%', trend: UiTrend.down)));
      expect(find.bySemanticsLabel(r'Revenue, $12.4k, down 8%'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('result titles are headings; empty state and result centre their actions', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, SizedBox(width: 390, child: Column(children: [
        UiResult(status: UiResultStatus.notFound, title: 'Page not found', actions: [UiButton(label: 'Home', onPressed: () {})]),
        UiEmptyState(description: 'Nothing yet', actions: [UiButton(label: 'Add', onPressed: () {})]),
      ])));
      final title = tester.getSemantics(find.text('Page not found')).getSemanticsData();
      expect(title.flagsCollection.isHeader, isTrue);
      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(tester.getCenter(find.text('Add')).dx, closeTo(195, 1));
      expect(tester.getCenter(find.text('Home')).dx, closeTo(195, 1));
      handle.dispose();
    });

    testWidgets('meet the tap-target, label and contrast guidelines', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      try {
        await pumpUi(tester, Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            UiLink('Read the docs', onTap: () {}),
            UiLink('Muted link', tone: UiLinkTone.muted, onTap: () {}),
          ]),
        ));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // The pixel-sampling contrast check reads the faint underline as the text colour, so link
        // (and key cap) contrast is checked on the colours themselves.
        for (final th in UiThemeName.values) {
          final t = uiThemeTokens[th]!;
          double ratio(Color a, Color b) {
            final la = a.computeLuminance(), lb = b.computeLuminance();
            return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
          }
          expect(ratio(t.primary, t.bg), greaterThanOrEqualTo(4.5), reason: '$th primary link');
          expect(ratio(t.textMuted, t.bg), greaterThanOrEqualTo(4.5), reason: '$th muted link');
          // The key cap's border outnumbers its glyph pixels too.
          expect(ratio(t.text, t.surfaceRaised), greaterThanOrEqualTo(4.5), reason: '$th kbd');
        }
        await pumpUi(tester, const Padding(
          padding: EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 8, children: [
            SizedBox(width: 300, child: UiMeter(value: 700, max: 800, warnAt: 600, label: 'Bundle')),
            SizedBox(width: 200, child: UiStatCard(label: 'Revenue', value: '12k', delta: '8%')),
            UiEmptyState(description: 'Nothing to show'),
            UiResult(title: 'Saved', subtitle: 'All good', status: UiResultStatus.success),
          ]),
        ));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      } finally {
        handle.dispose();
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  testWidgets('golden: link, kbd, meter, progress circle, stat card', (tester) async {
    await expectThemedGolden(tester, 'basics', height: 470, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiLink('Primary link', onTap: () {}),
          UiLink('Muted', tone: UiLinkTone.muted, onTap: () {}),
          UiLink('External', external: true, onTap: () {}),
        ]),
        const Row(spacing: 4, children: [UiKbd('Ctrl'), UiKbd('Shift'), UiKbd('K'), SizedBox(width: 8), UiText('opens search', variant: UiTextVariant.caption)]),
        const UiMeter(value: 212, max: 800, warnAt: 600, label: 'Bundle size', valueText: '212 KB of 800 KB'),
        const UiMeter(value: 690, max: 800, warnAt: 600, label: 'Bundle size', valueText: '690 KB of 800 KB'),
        const UiMeter(value: 860, max: 800, warnAt: 600, label: 'Bundle size', valueText: '860 KB of 800 KB'),
        const Row(spacing: 16, children: [
          UiProgressCircle(value: 72, showValue: true, size: 48),
          UiProgressCircle(value: 35, tone: UiStatus.success),
          UiProgressCircle(value: 90, tone: UiStatus.danger, size: 28, strokeWidth: 3),
          UiProgressCircle(value: 0),
        ]),
        const Row(spacing: 12, children: [
          Expanded(child: UiStatCard(label: 'Revenue', value: r'$48.2k', delta: '12.5%', icon: UiIcon(HugeIcons.strokeRoundedDollar01))),
          Expanded(child: UiStatCard(label: 'Churn', value: '2.1%', delta: '0.4%', trend: UiTrend.down)),
        ]),
      ],
    ));
  });

  testWidgets('golden: empty state and result', (tester) async {
    await expectThemedGolden(tester, 'empty_result', height: 900, (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UiEmptyState(
          icon: const UiIcon(HugeIcons.strokeRoundedInbox),
          heading: 'No messages',
          description: 'When someone writes to you, the conversation shows up here.',
          actions: [UiButton(label: 'New message', size: UiSize.sm, onPressed: () {}), UiButton(label: 'Refresh', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () {})],
        ),
        const UiDivider(),
        UiResult(
          status: UiResultStatus.success,
          title: 'Payment received',
          subtitle: 'We emailed the receipt to you.',
          actions: [UiButton(label: 'Done', size: UiSize.sm, onPressed: () {})],
        ),
        Wrap(alignment: WrapAlignment.center, children: [
          for (final st in [UiResultStatus.error, UiResultStatus.warning, UiResultStatus.info, UiResultStatus.notFound, UiResultStatus.serverError])
            SizedBox(width: 118, child: UiResult(status: st, title: st.name)),
        ]),
      ],
    ));
  });
}
