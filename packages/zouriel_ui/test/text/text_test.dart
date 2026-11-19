import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

void main() {
  testWidgets('headings are announced as headings with their level; heading:false opts out', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpUi(tester, const Column(children: [
      UiText('Title', variant: UiTextVariant.h1),
      UiText('Looks big', variant: UiTextVariant.h2, heading: false),
      UiText('Body'),
    ]));
    final title = tester.getSemantics(find.text('Title')).getSemanticsData();
    expect(title.label, 'Title');
    expect(title.headingLevel, 1);
    expect(tester.getSemantics(find.text('Looks big')).getSemanticsData().headingLevel, 0);
    handle.dispose();
  });

  testWidgets('h6 renders upper-case and code uses the mono font', (tester) async {
    await pumpUi(tester, const Column(children: [UiText('Section', variant: UiTextVariant.h6), UiText('ng build', variant: UiTextVariant.code)]));
    expect(find.text('SECTION'), findsOneWidget);
    final code = tester.widget<Text>(find.text('ng build'));
    expect(code.style!.fontFamily, contains('JetBrains Mono'));
  });

  testWidgets('fontFamily uses an app font as is, or a package font with fontPackage', (tester) async {
    await pumpUi(tester, const Column(children: [
      UiText('app', fontFamily: 'Georgia'),
      UiText('pkg', fontFamily: 'Space Grotesk', fontPackage: 'zouriel_ui'),
    ]));
    expect(tester.widget<Text>(find.text('app')).style!.fontFamily, 'Georgia');
    expect(tester.widget<Text>(find.text('pkg')).style!.fontFamily, 'packages/zouriel_ui/Space Grotesk');
  });

  testWidgets('truncate clips to one line with ellipsis and tone sets muted / onMedia styling', (tester) async {
    await pumpUi(tester, const SizedBox(
      width: 120,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        UiText('A very long name that should truncate nicely', variant: UiTextVariant.label, truncate: true),
        UiText('Muted body', tone: UiTextTone.muted),
        UiText('Hero title', variant: UiTextVariant.h2, tone: UiTextTone.onMedia),
        UiText('Hero date', variant: UiTextVariant.caption, tone: UiTextTone.onMedia),
      ]),
    ));
    final t = tester.element(find.text('Muted body')).ui;
    final trunc = tester.widget<Text>(find.text('A very long name that should truncate nicely'));
    expect(trunc.maxLines, 1);
    expect(trunc.overflow, TextOverflow.ellipsis);

    final muted = tester.widget<Text>(find.text('Muted body'));
    expect(muted.style!.color, t.textMuted);

    final heroTitle = tester.widget<Text>(find.text('Hero title'));
    expect(heroTitle.style!.color, t.mediaOnScrim);
    expect(heroTitle.style!.shadows, isNotEmpty);

    final heroDate = tester.widget<Text>(find.text('Hero date'));
    expect(heroDate.style!.color, t.mediaOnScrim.withValues(alpha: 0.9));
    expect(heroDate.style!.shadows, isNotEmpty);
  });

  testWidgets('golden: text tones and truncation', (tester) async {
    await expectThemedGolden(tester, 'text_tones_truncate', height: 220, (context) {
      final t = context.ui;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: SizedBox(width: 160, child: UiText('A very long label that truncates cleanly with ellipsis', variant: UiTextVariant.label, truncate: true)),
          ),
          const UiText('Centered muted body copy', tone: UiTextTone.muted, textAlign: TextAlign.center),
          Container(
            padding: EdgeInsets.all(t.space3),
            decoration: BoxDecoration(color: t.mediaBg, borderRadius: BorderRadius.circular(t.radius)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
              UiText('On-media heading', variant: UiTextVariant.h3, tone: UiTextTone.onMedia),
              UiText('On-media caption line', variant: UiTextVariant.caption, tone: UiTextTone.onMedia),
            ]),
          ),
        ],
      );
    });
  });

  testWidgets('golden: the type scale', (tester) async {
    await expectThemedGolden(tester, 'text_variants', height: 520, (context) => const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        UiText('Heading 1', variant: UiTextVariant.h1),
        UiText('Heading 2', variant: UiTextVariant.h2),
        UiText('Heading 3', variant: UiTextVariant.h3),
        UiText('Heading 4', variant: UiTextVariant.h4),
        UiText('Heading 5', variant: UiTextVariant.h5),
        UiText('Heading 6', variant: UiTextVariant.h6),
        UiText('Body — the default paragraph style.'),
        UiText('A small muted caption.', variant: UiTextVariant.caption),
        UiText('Label', variant: UiTextVariant.label),
        UiText('inline code', variant: UiTextVariant.code),
        UiText('A blockquote for pull quotes.', variant: UiTextVariant.quote),
      ],
    ));
  });
}
