import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _features = ['25 GB of photos', 'Guest uploads', 'Keep for a year'];

Widget _card({UiTier? tier, String? highlight, bool current = false, String name = 'Gold pass', Widget? action, Widget? fineprint}) => UiPlanCard(
      name: name,
      price: 'MVR 499',
      period: 'per event',
      note: r'about $32',
      tagline: 'For parties',
      features: _features,
      tier: tier,
      highlight: highlight,
      current: current,
      action: action,
      fineprint: fineprint,
    );

Widget _cards() => UiPlanGrid(children: [
      UiPlanCard(name: 'Free', price: 'MVR 0', features: const ['1 GB'], action: UiButton(label: 'Start free', variant: UiButtonVariant.outline, block: true, onPressed: () {})),
      UiPlanCard(
        name: 'Gold pass',
        price: 'MVR 499',
        period: 'per event',
        tier: UiTier.gold,
        features: _features,
        action: UiButton(label: 'Get Gold', tier: UiTier.gold, block: true, onPressed: () {}),
      ),
      UiPlanCard(
        name: 'Platinum pass',
        price: 'MVR 899',
        period: 'per event',
        tier: UiTier.platinum,
        highlight: 'For weddings',
        features: const [..._features, '50 GB', 'Priority help'],
        action: UiButton(label: 'Get Platinum', tier: UiTier.platinum, block: true, onPressed: () {}),
      ),
    ]);

const _plans = [
  UiPlanColumn(key: 'free', name: 'Free'),
  UiPlanColumn(key: 'gold', name: 'Gold', tier: UiTier.gold),
  UiPlanColumn(key: 'platinum', name: 'Platinum', tier: UiTier.platinum),
  UiPlanColumn(key: 'premium', name: 'Premium', tier: UiTier.premium),
];
const _rows = [
  UiPlanRow(label: 'Storage', values: {'free': '1 GB', 'gold': '25 GB', 'platinum': '50 GB', 'premium': '3 GB per event'}),
  UiPlanRow(label: 'Guest uploads', values: {'free': false, 'gold': true, 'platinum': true, 'premium': true}),
  UiPlanRow(label: 'Video', values: {'free': null, 'gold': false, 'platinum': true, 'premium': true}),
];

void main() {
  group('UiPlanCard', () {
    testWidgets('shows name, tagline, price, period, note and the feature list', (tester) async {
      await pumpUi(tester, _card());
      for (final s in ['Gold pass', 'For parties', 'MVR 499', 'per event', r'about $32', ..._features]) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      expect(find.byType(UiIcon), findsNWidgets(_features.length));
    });

    testWidgets('a long price and its period wrap on a narrow card instead of overflowing (as the web)', (tester) async {
      await pumpUi(tester, Center(child: SizedBox(width: 240, child: UiPlanCard(name: 'Platinum pass', price: 'One payment', period: 'once, for one event', features: const ['10 GB']))));
      expect(tester.takeException(), isNull, reason: 'no RenderFlex overflow');
      final price = tester.getRect(find.text('One payment'));
      final period = tester.getRect(find.text('once, for one event'));
      expect(period.top, greaterThanOrEqualTo(price.bottom - 1), reason: 'the period drops under the price');
      expect(period.right, lessThanOrEqualTo(tester.getRect(find.byType(UiPlanCard)).right));
    });

    testWidgets('a group named by the plan, with the price read as one phrase', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, _card(tier: UiTier.gold));
      expect(find.bySemanticsLabel('MVR 499 per event'), findsOneWidget);
      expect(find.bySemanticsLabel('MVR 499'), findsNothing);
      expect(find.bySemanticsLabel('per event'), findsNothing);
      final group = tester.getSemantics(find.byType(UiPlanCard));
      expect(group.label, 'Gold pass');
      handle.dispose();
    });

    testWidgets('a tier adds the metal strip and a dot; the body stays on the surface', (tester) async {
      await pumpUi(tester, _card(tier: UiTier.platinum));
      final t = tester.element(find.byType(UiPlanCard)).ui;
      final strip = tester.widget<DecoratedBox>(find.descendant(of: find.byKey(const ValueKey('ui-plan-tier-edge')), matching: find.byType(DecoratedBox)));
      expect(((strip.decoration as BoxDecoration).gradient! as LinearGradient).colors, t.gradientTierPlatinum.colors);
      expect(tester.getSize(find.byKey(const ValueKey('ui-plan-tier-edge'))).height, 4);
      expect(find.byWidgetPredicate((w) => w is UiBadge && w.dot && w.tier == UiTier.platinum), findsOneWidget);
      final box = tester.widget<Container>(find.descendant(of: find.byType(UiPlanCard), matching: find.byType(Container)).first);
      expect((box.decoration! as BoxDecoration).color, t.surface);

      await pumpUi(tester, _card());
      expect(find.byKey(const ValueKey('ui-plan-tier-edge')), findsNothing);
    });

    testWidgets('the highlight ribbon and stronger border appear only when set', (tester) async {
      await pumpUi(tester, _card(tier: UiTier.gold));
      expect(find.byKey(const ValueKey('ui-plan-ribbon')), findsNothing);
      expect(tester.widget<Container>(find.descendant(of: find.byType(UiPlanCard), matching: find.byType(Container)).first).foregroundDecoration, isNull);

      await pumpUi(tester, Padding(padding: const EdgeInsets.only(top: 20), child: _card(tier: UiTier.gold, highlight: 'Most popular')));
      final t = tester.element(find.byType(UiPlanCard)).ui;
      expect(find.text('Most popular'), findsOneWidget);
      final card = tester.widget<Container>(find.descendant(of: find.byType(UiPlanCard), matching: find.byType(Container)).first);
      final ring = card.foregroundDecoration! as BoxDecoration;
      expect((ring.border! as Border).top.color, t.tierGoldBorder);
      expect((ring.border! as Border).top.width, 2);
      // Centred on the top edge.
      final ribbon = tester.getRect(find.byKey(const ValueKey('ui-plan-ribbon')));
      final cardRect = tester.getRect(find.byType(UiPlanCard));
      expect(ribbon.center.dy, closeTo(cardRect.top, 0.5));
      expect(ribbon.center.dx, closeTo(cardRect.center.dx, 0.5));
    });

    testWidgets('current shows the "Your plan" badge', (tester) async {
      await pumpUi(tester, _card());
      expect(find.text('Your plan'), findsNothing);
      await pumpUi(tester, _card(current: true));
      expect(find.widgetWithText(UiBadge, 'Your plan'), findsOneWidget);
    });

    testWidgets('action and fineprint slots sit at the bottom, fineprint under the action', (tester) async {
      var taps = 0;
      await pumpUi(tester, _card(action: UiButton(label: 'Buy', block: true, onPressed: () => taps++), fineprint: const Text('Taxes included')));
      await tester.tap(find.text('Buy'));
      expect(taps, 1);
      final t = tester.element(find.byType(UiPlanCard)).ui;
      expect(tester.getRect(find.text('Taxes included')).top, greaterThan(tester.getRect(find.byType(UiButton)).bottom));
      expect(tester.renderObject<RenderParagraph>(find.text('Taxes included')).text.style!.color, t.textMuted);
      // The last feature is above the action.
      expect(tester.getRect(find.byType(UiButton)).top, greaterThan(tester.getRect(find.text(_features.last)).bottom));
    });

    testWidgets('meets the text contrast guideline in light and dark', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      for (final th in [UiThemeName.dark, UiThemeName.light]) {
        await pumpUi(tester, Padding(padding: const EdgeInsets.all(16), child: _card(tier: UiTier.premium, highlight: 'Most popular', current: true)), theme: th);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('UiPlanGrid', () {
    testWidgets('at 390px the cards stack, one per row, with room between them', (tester) async {
      await pumpUi(tester, SingleChildScrollView(child: SizedBox(width: 358, child: _cards())));
      final rects = [for (final e in find.byType(UiPlanCard).evaluate()) tester.getRect(find.byWidget(e.widget))];
      expect(rects.length, 3);
      for (final r in rects) {
        expect(r.width, 358);
      }
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top - rects[i - 1].bottom, 24);
      }
    });

    testWidgets('wide: three columns of equal height with the actions lined up', (tester) async {
      await pumpUi(tester, SizedBox(width: 1200, child: _cards()), size: const Size(1440, 1000));
      final cards = find.byType(UiPlanCard);
      final rects = [for (var i = 0; i < 3; i++) tester.getRect(cards.at(i))];
      expect(rects.map((r) => r.top).toSet().length, 1);
      expect(rects.map((r) => r.height).toSet().length, 1, reason: 'equal heights');
      final buttons = [for (var i = 0; i < 3; i++) tester.getRect(find.byType(UiButton).at(i))];
      expect(buttons.map((r) => r.bottom).toSet().length, 1, reason: 'actions aligned');
      expect(rects[1].left - rects[0].right, 24);
    });

    test('columns: one under 600, two under 912, at most three, never more than cards', () {
      expect(UiPlanGrid.columnsFor(390, 3), 1);
      expect(UiPlanGrid.columnsFor(700, 3), 2);
      expect(UiPlanGrid.columnsFor(1200, 3), 3);
      expect(UiPlanGrid.columnsFor(1200, 5), 3);
      expect(UiPlanGrid.columnsFor(1200, 2), 2);
    });
  });

  group('UiPlanCompare', () {
    Widget compare({double width = 358, String? highlight = 'platinum'}) => SizedBox(
          width: width,
          child: UiPlanCompare(plans: _plans, rows: _rows, highlight: highlight, caption: 'Compare plans'),
        );

    testWidgets('true is a check read "Included", false and null a dash read "Not included", strings as text', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpUi(tester, compare(width: 1000), size: const Size(1100, 800));
      expect(find.text('3 GB per event'), findsOneWidget);
      expect(find.text('25 GB'), findsOneWidget);
      expect(find.bySemanticsLabel('Included'), findsNWidgets(5));
      expect(find.bySemanticsLabel('Not included'), findsNWidgets(3));
      expect(find.bySemanticsLabel('Compare plans'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('headers carry a slim tier underline (the plain border without a tier)', (tester) async {
      await pumpUi(tester, compare(width: 1000), size: const Size(1100, 800));
      final t = tester.element(find.byType(UiPlanCompare)).ui;
      BoxDecoration bar(String k) => tester.widget<Container>(find.byKey(ValueKey('ui-plan-compare-bar-$k'))).decoration! as BoxDecoration;
      expect(bar('free').color, t.border);
      expect(bar('free').gradient, isNull);
      for (final p in _plans.where((p) => p.tier != null)) {
        expect((bar(p.key).gradient! as LinearGradient).colors, p.tier!.gradient(t).colors, reason: p.key);
      }
      expect(tester.getSize(find.byKey(const ValueKey('ui-plan-compare-bar-gold'))).height, 3);
    });

    testWidgets('the highlighted column is tinted, the others are not', (tester) async {
      await pumpUi(tester, compare(width: 1000), size: const Size(1100, 800));
      final t = tester.element(find.byType(UiPlanCompare)).ui;
      Color? head(String k) => (tester.widget<Container>(find.byKey(ValueKey('ui-plan-compare-head-$k'))).decoration! as BoxDecoration).color;
      expect(head('platinum'), Color.alphaBlend(t.selected, t.surface));
      expect(head('gold'), t.surface);
      await pumpUi(tester, compare(width: 1000, highlight: null), size: const Size(1100, 800));
      expect(head('platinum'), t.surface);
    });

    testWidgets('at 390px it scrolls sideways inside itself and keeps the first column in view', (tester) async {
      await pumpUi(tester, compare());
      final box = tester.getRect(find.byType(UiPlanCompare));
      expect(box.width, 358);
      final before = tester.getRect(find.text('Storage'));
      final premiumBefore = tester.getRect(find.text('3 GB per event'));
      expect(premiumBefore.left, greaterThan(box.right), reason: 'the last column starts off screen');
      await tester.drag(find.text('25 GB'), const Offset(-400, 0));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.text('Storage'));
      expect(after.left, closeTo(before.left, 0.5), reason: 'the first column is pinned');
      expect(tester.getRect(find.text('3 GB per event')).left, lessThan(premiumBefore.left));
      // The pinned cell is painted over the cells sliding under it.
      final hit = tester.hitTestOnBinding(after.center);
      expect(hit.path.any((e) => e.target is RenderParagraph && (e.target as RenderParagraph).text.toPlainText() == 'Storage'), isTrue);
    });

    testWidgets('meets the text contrast guideline', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final handle = tester.ensureSemantics();
      for (final th in [UiThemeName.dark, UiThemeName.light]) {
        await pumpUi(tester, compare(width: 1000), size: const Size(1100, 800), theme: th);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
      }
      handle.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  });

  testWidgets('golden: plan cards', (tester) async {
    await expectThemedGolden(tester, 'plan_cards', height: 1400, (context) => SingleChildScrollView(child: _cards()));
  });

  testWidgets('golden: plan cards, wide', (tester) async {
    await expectThemedGolden(tester, 'plan_cards_wide', width: 1000, height: 560, (context) => _cards());
  });

  testWidgets('golden: plan compare', (tester) async {
    await expectThemedGolden(tester, 'plan_compare', height: 260, (context) => const UiPlanCompare(plans: _plans, rows: _rows, highlight: 'platinum'));
  });
}
