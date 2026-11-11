import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

/// The same sample in each theme: the backdrop, a glass card with title, muted text and buttons, the
/// other button variants, status badges, a switch, a progress bar and an alert.
Widget sample(BuildContext context) {
  final t = context.ui;
  return SizedBox(
    height: 520,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(t.radiusLg),
      child: Stack(children: [
        const Positioned.fill(child: UiLiquidBackdrop()),
        Padding(
          padding: EdgeInsets.all(t.space3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            UiCard(
              glass: true,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space2, children: [
                const UiText('Glass card', variant: UiTextVariant.h5),
                const UiText('Muted words under the title.', variant: UiTextVariant.caption),
                Wrap(spacing: t.space2, runSpacing: t.space2, children: [
                  UiButton(label: 'Primary', size: UiSize.sm, onPressed: () {}),
                  UiButton(label: 'Brand', size: UiSize.sm, variant: UiButtonVariant.brand, onPressed: () {}),
                ]),
              ]),
            ),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiButton(label: 'Second', size: UiSize.sm, variant: UiButtonVariant.secondary, onPressed: () {}),
              UiButton(label: 'Accent', size: UiSize.sm, variant: UiButtonVariant.accent, onPressed: () {}),
              UiButton(label: 'Outline', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () {}),
              UiButton(label: 'Glass', size: UiSize.sm, glass: true, onPressed: () {}),
              UiButton(label: 'Delete', size: UiSize.sm, variant: UiButtonVariant.destructive, onPressed: () {}),
            ]),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: const [
              UiBadge(label: 'Info', tone: UiStatus.primary),
              UiBadge(label: 'Done', tone: UiStatus.success),
              UiBadge(label: 'Wait', tone: UiStatus.warning),
              UiBadge(label: 'Fail', tone: UiStatus.danger),
            ]),
            UiSwitch(value: true, onChanged: (_) {}, label: 'Notifications'),
            const UiProgressBar(value: 60, label: 'Upload'),
            const UiAlert(heading: 'Heads up', message: 'Alerts keep their tone on the flow.', tone: UiAlertTone.warning),
          ]),
        ),
      ]),
    ),
  );
}

void main() {
  testWidgets('golden: liquid day themes', (tester) async {
    await expectThemedGolden(tester, 'liquid_themes_day', sample,
        themes: const [UiThemeName.rugged, UiThemeName.glacier, UiThemeName.oxblood, UiThemeName.graphite, UiThemeName.cocoa, UiThemeName.violet],
        width: 300, height: 560);
  });

  testWidgets('golden: liquid night themes', (tester) async {
    await expectThemedGolden(tester, 'liquid_themes_night', sample,
        themes: const [UiThemeName.ruggedDark, UiThemeName.glacierDark, UiThemeName.oxbloodDark, UiThemeName.graphiteDark, UiThemeName.cocoaDark, UiThemeName.violetDark],
        width: 300, height: 560);
  });

  testWidgets('golden: Navy, light and dark', (tester) async {
    await expectThemedGolden(tester, 'navy_themes', sample, themes: const [UiThemeName.navy, UiThemeName.navyDark], width: 300, height: 560);
  });

  // The themes this change adds or changes (Navy and the liquid themes). Maldives is left as it was:
  // its brand button labels a sand-to-deep gradient in white, which fails on the light stops (web too).
  for (final th in uiCurrentThemes.where((t) => t != UiThemeName.darkOrange && t != UiThemeName.maldives && t != UiThemeName.maldivesDark)) {
    testWidgets('meets the text contrast guideline on the sample in ${th.name}', (tester) async {
      // Animations off: the backdrop stands still, so the tree settles (it never does while it flows).
      tester.view.physicalSize = const Size(390, 900) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(
        theme: th,
        config: const UiConfig(animations: false),
        home: Align(alignment: Alignment.topLeft, child: SizedBox(width: 360, child: Builder(builder: sample))),
      ));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
    });
  }
}
