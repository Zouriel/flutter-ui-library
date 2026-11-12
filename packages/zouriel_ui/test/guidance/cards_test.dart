import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

const _items = [
  UiChecklistItem(id: 'name', label: 'Add your name and photo', done: true),
  UiChecklistItem(id: 'event', label: 'Start an event', description: 'Pick a design, add guests, send.'),
  UiChecklistItem(id: 'guests', label: 'Add your guests', done: true),
  UiChecklistItem(id: 'send', label: 'Send it or share the link'),
  UiChecklistItem(id: 'photo', label: 'Get your first photo'),
];

/// A blank 320 x 200 picture, like the apps' empty-page art.
class _Art extends StatelessWidget {
  const _Art();
  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return SizedBox(
      width: 320,
      height: 200,
      child: DecoratedBox(
        decoration: BoxDecoration(color: t.surfaceSubtle, borderRadius: BorderRadius.circular(t.radiusLg)),
        child: Center(child: Container(width: 120, height: 90, decoration: BoxDecoration(color: t.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(t.radius)))),
      ),
    );
  }
}

void main() {
  group('UiOfferCard', () {
    testWidgets('buttons, × and Turn off tips report; nothing shows that is not asked for', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <String>[];
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: UiOfferCard(
            heading: 'New to invites.blog?',
            body: 'Take a quick tour.',
            art: UiIcon(HugeIcons.strokeRoundedIdea01),
            primaryLabel: 'Show me',
            onPrimary: () => log.add('primary'),
            secondaryLabel: 'Not now',
            onSecondary: () => log.add('secondary'),
            onDismiss: () => log.add('dismiss'),
            onTipsOff: () => log.add('off'),
          ),
        ),
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text('Show me'));
      await tester.tap(find.text('Not now'));
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.tap(find.text('Turn off tips'));
      expect(log, ['primary', 'secondary', 'dismiss', 'off']);
      expect(tester.getSemantics(find.text('New to invites.blog?')).getSemanticsData().flagsCollection.isHeader, isTrue);

      // The card's own text on its tint. Small text in a 48px touch area (the sm buttons, the
      // Turn off tips link) makes the checker read mostly background and report ~1.3:1, a false
      // alarm: measured on the golden, the link is 6.2:1 on the dark tint.
      await pumpUi(tester, const SizedBox(width: 360, child: UiOfferCard(heading: 'New to invites.blog?', body: 'Take a quick tour.')));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await pumpUi(tester, const SizedBox(width: 360, child: UiOfferCard(heading: 'New to invites.blog?', body: 'Take a quick tour.')), theme: UiThemeName.light);
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await pumpUi(tester, const SizedBox(width: 360, child: UiOfferCard(heading: 'Just a heading')));
      expect(find.bySemanticsLabel('Dismiss'), findsNothing);
      expect(find.text('Turn off tips'), findsNothing);
      expect(find.byType(UiButton), findsNothing);
      handle.dispose();
    });

    testWidgets('fits a 360px phone: the card is the column width and nothing overflows', (tester) async {
      await pumpUi(
        tester,
        SizedBox(
          width: 360,
          child: UiOfferCard(
            variant: UiOfferVariant.role,
            heading: 'Aminath added you to "Aisha & Ibrahim" as a celebrant.',
            body: "You can see who's coming and all the photos.",
            art: const SizedBox(width: 80, height: 60),
            primaryLabel: 'Open event',
            onPrimary: () {},
            secondaryLabel: 'Show me around',
            onSecondary: () {},
            onDismiss: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(UiOfferCard)).width, 360);
      // The role picture is a 56px tile.
      expect(tester.getSize(find.ancestor(of: find.byType(FittedBox), matching: find.byType(SizedBox)).first), const Size(56, 56));
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(tester, 'offer_card', width: 360, height: 400, (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiOfferCard(
                heading: 'New to invites.blog?',
                body: 'Take a quick tour.',
                art: UiIcon(HugeIcons.strokeRoundedIdea01),
                primaryLabel: 'Show me',
                onPrimary: () {},
                secondaryLabel: 'Not now',
                onSecondary: () {},
                onDismiss: () {},
                onTipsOff: () {},
              ),
              const SizedBox(height: 16),
              UiOfferCard(
                variant: UiOfferVariant.role,
                heading: 'Aminath added you to "Aisha & Ibrahim" as a celebrant.',
                body: 'You can manage it with them.',
                art: Builder(builder: (context) => Container(width: 56, height: 56, color: context.ui.accent)),
                primaryLabel: 'Open event',
                onPrimary: () {},
                secondaryLabel: 'Show me around',
                onSecondary: () {},
                onDismiss: () {},
              ),
            ],
          ));
    });
  });

  group('UiChecklist', () {
    testWidgets('counts done items, ticks them in any order, reports taps, and closes', (tester) async {
      final handle = tester.ensureSemantics();
      final taps = <String>[];
      var closed = 0;
      await pumpUi(tester, SizedBox(width: 360, child: UiChecklist(heading: 'Getting started', items: _items, onItemTap: (i) => taps.add(i.id), onDismiss: () => closed++)));
      expect(find.text('2 of 5'), findsOneWidget);
      expect(find.text('Start an event'), findsOneWidget);
      await tester.tap(find.text('Start an event'));
      await tester.tap(find.text('Add your name and photo'));
      expect(taps, ['event', 'name']);
      expect(find.bySemanticsLabel('Add your name and photo, Done'), findsOneWidget);
      expect(find.bySemanticsLabel('Start an event, Not done yet'), findsOneWidget);
      final done = tester.widget<Text>(find.text('Add your guests'));
      expect(done.style!.decoration, TextDecoration.lineThrough);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).value, 40);
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      expect(closed, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // Done in a different order: the count follows.
      await pumpUi(tester, SizedBox(width: 360, child: UiChecklist(heading: 'Getting started', items: [for (final i in _items) UiChecklistItem(id: i.id, label: i.label, done: !i.done)])));
      expect(find.text('3 of 5'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('all done shows the finished state, with a success bar', (tester) async {
      await pumpUi(tester, SizedBox(width: 360, child: UiChecklist(heading: 'Getting started', items: [for (final i in _items) UiChecklistItem(id: i.id, label: i.label, done: true)])));
      expect(find.text('5 of 5'), findsOneWidget);
      expect(find.text('All set'), findsOneWidget);
      expect(find.text('Start an event'), findsNothing);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).tone, UiStatus.success);
      expect(tester.widget<UiProgressBar>(find.byType(UiProgressBar)).value, 100);
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(tester, 'checklist', width: 360, height: 560, (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              UiChecklist(heading: 'Getting started', items: _items, onItemTap: (_) {}, onDismiss: () {}),
              const SizedBox(height: 16),
              UiChecklist(heading: 'Getting started', items: [for (final i in _items) UiChecklistItem(id: i.id, label: i.label, done: true)]),
            ],
          ));
    });
  });

  group('UiEmptyState with art and starters', () {
    testWidgets('the art sits above the heading at most 320 x 200, scaled down when narrow', (tester) async {
      await pumpUi(tester, const SizedBox(width: 390, child: UiEmptyState(heading: 'Your feed is quiet', art: _Art())));
      final art = tester.getRect(find.byType(_Art));
      expect(art.size, const Size(320, 200));
      expect(art.bottom, lessThan(tester.getRect(find.text('Your feed is quiet')).top));
      await pumpUi(tester, const SizedBox(width: 232, child: UiEmptyState(heading: 'Your feed is quiet', art: _Art())));
      final small = tester.getRect(find.byType(_Art));
      // 232 - 2 x 16 padding = 200 wide, and the same 8:5 shape.
      expect(small.width, closeTo(200, 0.5));
      expect(small.height, closeTo(125, 0.5));
    });

    testWidgets('starters stack on a phone and go 2-3 across on wider screens', (tester) async {
      Widget page(double w, int n) => SizedBox(
            width: w,
            child: UiEmptyState(
              heading: 'Your feed is quiet',
              starters: [for (var i = 0; i < n; i++) UiStarterCard(heading: 'Starter $i', description: 'One line', onTap: () {})],
            ),
          );
      double x(int i) => tester.getRect(find.byType(UiStarterCard).at(i)).left;
      double y(int i) => tester.getRect(find.byType(UiStarterCard).at(i)).top;

      await pumpUi(tester, page(390, 3));
      expect(x(0), x(1));
      expect(y(1), greaterThan(y(0)));
      expect(tester.getSize(find.byType(UiStarterCard).first).width, 390 - 32);

      await pumpUi(tester, page(1000, 3), size: const Size(1200, 800));
      expect(y(0), y(1));
      expect(y(1), y(2));
      expect(tester.getSize(find.byType(UiStarterGrid)).width, 720);

      await pumpUi(tester, page(1000, 2), size: const Size(1200, 800));
      expect(y(0), y(1));
      expect(tester.getSize(find.byType(UiStarterCard).first).width, (720 - 12) / 2);

      await pumpUi(tester, page(600, 3), size: const Size(800, 800));
      expect(y(0), y(1));
      expect(y(2), greaterThan(y(0)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the old constructor still works', (tester) async {
      await pumpUi(tester, const UiEmptyState(heading: 'Nothing', description: 'Here'));
      expect(find.text('Nothing'), findsOneWidget);
      expect(find.byType(UiStarterGrid), findsNothing);
    });

    testWidgets('golden', (tester) async {
      await expectThemedGolden(tester, 'empty_state_art', width: 390, height: 560, (context) => UiEmptyState(
            heading: 'Your feed is quiet',
            description: 'Events you host or are invited to show up here.',
            art: const _Art(),
            starters: [
              UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedAdd01), heading: 'Start an event', description: 'Pick a design and add guests', onTap: () {}),
              UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedImage01), heading: 'See an example event', description: 'A sample wedding', onTap: () {}),
            ],
          ));
    });
  });

  group('UiStarterCard', () {
    testWidgets('is one button named by its heading; disabled does nothing', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await pumpUi(tester, SizedBox(width: 300, child: UiStarterCard(icon: UiIcon(HugeIcons.strokeRoundedAdd01), heading: 'Start an event', description: 'Pick a design', onTap: () => taps++)));
      final data = tester.getSemantics(find.byType(UiStarterCard)).getSemanticsData();
      expect(data.label, 'Start an event');
      expect(data.hint, 'Pick a design');
      expect(data.flagsCollection.isButton, isTrue);
      await tester.tap(find.byType(UiStarterCard));
      expect(taps, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await pumpUi(tester, SizedBox(width: 300, child: UiStarterCard(heading: 'Start', onTap: () => taps++, enabled: false)));
      await tester.tap(find.byType(UiStarterCard), warnIfMissed: false);
      expect(taps, 1);
      handle.dispose();
    });
  });
}
