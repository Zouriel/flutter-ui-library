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
