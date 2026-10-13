import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

void main() {
  test('tokens match the web themes (values resolved from the Angular stylesheets)', () {
    final dark = uiThemeTokens[UiThemeName.dark]!;
    final light = uiThemeTokens[UiThemeName.light]!;
    expect(dark.bg, const Color(0xff000000));
    expect(dark.text, const Color(0xffb3cbdc));
    expect(light.primary, const Color(0xff1b3d59));
    expect(uiThemeTokens[UiThemeName.lightTeal]!.textMuted, const Color(0xff365e57));
    expect(dark.space6, 24);
    expect(dark.sizeMd, 30);
    expect(dark.motionBase, const Duration(milliseconds: 200));
    expect(uiThemeTokens[UiThemeName.darkOrange]!.fontDefault, 'Space Grotesk');
    expect(uiThemeTokens.length, 13);
  });

  test('brightness follows the background', () {
    expect(UiThemeData(name: UiThemeName.dark).brightness, Brightness.dark);
    expect(UiThemeData(name: UiThemeName.lightPink).brightness, Brightness.light);
    expect(UiThemeData(name: UiThemeName.goldBlack).brightness, Brightness.dark);
  });

  test('themes interpolate', () {
    final a = UiThemeData(name: UiThemeName.dark), b = UiThemeData(name: UiThemeName.light);
    final mid = UiThemeData.lerp(a, b, 0.5);
    expect(mid.tokens.bg, Color.lerp(a.tokens.bg, b.tokens.bg, 0.5));
    expect(UiThemeData.lerp(a, b, 0), same(a));
  });

  test('the controller sets and toggles like UiThemeService', () {
    final c = UiThemeController();
    var calls = 0;
    c.addListener(() => calls++);
    c.toggle();
    expect(c.theme, UiThemeName.light);
    c.set(UiThemeName.goldRed);
    c.toggle();
    expect(c.theme, UiThemeName.dark);
    expect(calls, 3);
  });

  testWidgets('a scoped theme repaints its own background and text', (tester) async {
    await tester.pumpWidget(UiApp(
      home: UiThemeScope(theme: UiThemeName.light, child: Builder(builder: (context) => Text('x', key: const Key('t'), style: TextStyle(color: context.ui.text)))),
    ));
    final text = tester.widget<Text>(find.byKey(const Key('t')));
    expect(text.style!.color, uiThemeTokens[UiThemeName.light]!.text);
  });
}
