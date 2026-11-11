import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

void main() {
  test('splits every built-in theme into current and legacy, with none in both', () {
    expect(uiCurrentThemes.toSet().intersection(uiLegacyThemes.toSet()), isEmpty);
    expect({...uiCurrentThemes, ...uiLegacyThemes}, UiThemeName.values.toSet());
    expect(uiCurrentThemes.length + uiLegacyThemes.length, UiThemeName.values.length);
    expect(uiCurrentThemes, hasLength(19));
    expect(uiLegacyThemes, hasLength(12));
  });

  test('lists the themes in the web order (UI_CURRENT_THEMES, UI_LEGACY_THEMES), web names camelCased', () {
    String web(UiThemeName t) => t.name.replaceAllMapped(RegExp('[A-Z]'), (m) => '-${m[0]!.toLowerCase()}');
    // Only the hyphenated web names (x-dark) are camelCased; the palette names were camelCase on the web too.
    final hyphenated = {'navyDark', 'maldivesDark', 'ruggedDark', 'glacierDark', 'oxbloodDark', 'graphiteDark', 'cocoaDark', 'violetDark'};
    expect([for (final t in uiCurrentThemes) hyphenated.contains(t.name) ? web(t) : t.name], [
      'dark', 'light', 'navy', 'navy-dark', 'darkOrange', 'maldives', 'maldives-dark',
      'rugged', 'rugged-dark', 'glacier', 'glacier-dark', 'oxblood', 'oxblood-dark',
      'graphite', 'graphite-dark', 'cocoa', 'cocoa-dark', 'violet', 'violet-dark',
    ]);
    expect([for (final t in uiLegacyThemes) t.name], [
      'winterDark', 'winterLight', 'lightOrange', 'lightPink', 'darkPink', 'goldBlack', 'goldRed',
      'lightTeal', 'darkTeal', 'lightPurple', 'darkPurple', 'lightPurpleGold',
    ]);
    for (final t in uiLegacyThemes) {
      expect(isLegacyTheme(t), isTrue, reason: t.name);
    }
    for (final t in uiCurrentThemes) {
      expect(isLegacyTheme(t), isFalse, reason: t.name);
    }
  });

  test('resolves winterDark and winterLight to exactly the tokens of navyDark and navy, as dark and light do', () {
    // The token map is const, so two entries built from the same values are the same object.
    expect(identical(uiThemeTokens[UiThemeName.winterDark], uiThemeTokens[UiThemeName.navyDark]), isTrue);
    expect(identical(uiThemeTokens[UiThemeName.dark], uiThemeTokens[UiThemeName.navyDark]), isTrue);
    expect(identical(uiThemeTokens[UiThemeName.winterLight], uiThemeTokens[UiThemeName.navy]), isTrue);
    expect(identical(uiThemeTokens[UiThemeName.light], uiThemeTokens[UiThemeName.navy]), isTrue);
    expect(identical(uiThemeTokens[UiThemeName.navy], uiThemeTokens[UiThemeName.navyDark]), isFalse);
  });

  test('Navy: Midnight canvas and Powder ink on dark, Midnight ink and a deepened Sunflower primary on light', () {
    final dark = uiThemeTokens[UiThemeName.navyDark]!;
    final light = uiThemeTokens[UiThemeName.navy]!;
    expect(dark.bg, const Color(0xff0f1433));
    expect(dark.text, const Color(0xffc9d6ff));
    expect(dark.secondary, const Color(0xffc9d6ff));
    expect(dark.primary, const Color(0xffffc93c));
    expect(light.bg, const Color(0xffeef2ff));
    expect(light.text, const Color(0xff0f1433));
    expect(light.accent, const Color(0xffffc93c));
    expect(light.primary, const Color(0xff7a5800));
    // Powder Blue is never a large surface on dark.
    for (final c in [dark.bg, dark.surface, dark.surfaceRaised, dark.surfaceSubtle, dark.surfaceHover]) {
      expect(c, isNot(const Color(0xffc9d6ff)));
    }
  });

  group('toggle', () {
    const pairs = {
      UiThemeName.light: UiThemeName.dark,
      UiThemeName.navy: UiThemeName.navyDark,
      UiThemeName.winterLight: UiThemeName.winterDark,
      UiThemeName.maldives: UiThemeName.maldivesDark,
      UiThemeName.rugged: UiThemeName.ruggedDark,
      UiThemeName.glacier: UiThemeName.glacierDark,
      UiThemeName.oxblood: UiThemeName.oxbloodDark,
      UiThemeName.graphite: UiThemeName.graphiteDark,
      UiThemeName.cocoa: UiThemeName.cocoaDark,
      UiThemeName.violet: UiThemeName.violetDark,
    };
    for (final e in pairs.entries) {
      test('${e.key.name} <-> ${e.value.name}', () {
        final c = UiThemeController(theme: e.key);
        c.toggle();
        expect(c.theme, e.value);
        c.toggle();
        expect(c.theme, e.key);
      });
    }
    test('goes to dark from a theme with no pair', () {
      for (final t in [UiThemeName.darkOrange, UiThemeName.lightTeal, UiThemeName.goldBlack]) {
        final c = UiThemeController(theme: t);
        c.toggle();
        expect(c.theme, UiThemeName.dark, reason: t.name);
      }
    });
  });

  test('liquid themes carry their brand colours, a lit glass rim and a brand label; legacy skins do not light the rim', () {
    const brand = {
      UiThemeName.rugged: [0xffd8c3a0, 0xff5b5e3c, 0xffffd21f],
      UiThemeName.ruggedDark: [0xff1e2015, 0xff5b5e3c, 0xffffd21f],
      UiThemeName.glacier: [0xfff1f3f4, 0xff9cc6e0, 0xffe4002b],
      UiThemeName.glacierDark: [0xff0e1a24, 0xff2f5670, 0xffff2d4f],
      UiThemeName.oxblood: [0xfff2eadb, 0xff2b2b2e, 0xff7a0c1e],
      UiThemeName.oxbloodDark: [0xff1c1c1f, 0xff3a3633, 0xffa3162e],
      UiThemeName.graphite: [0xffecedef, 0xff5a5f6b, 0xffe84a00],
      UiThemeName.graphiteDark: [0xff1a1b1f, 0xff5a5f6b, 0xffff5a0a],
      UiThemeName.cocoa: [0xffeee4d6, 0xff3a2a21, 0xffe3173e],
      UiThemeName.cocoaDark: [0xff1f1612, 0xff3a2a21, 0xfff2385a],
      UiThemeName.violet: [0xffe9ecef, 0xff111316, 0xff7b4dff],
      UiThemeName.violetDark: [0xff111316, 0xff2a2d33, 0xff8f6bff],
    };
    for (final e in brand.entries) {
      final t = uiThemeTokens[e.key]!;
      expect([t.liquidMain, t.liquidSecond, t.liquidAccent], [for (final v in e.value) Color(v)], reason: e.key.name);
      expect(t.glassHighlightTop.a, greaterThan(t.glassHighlightEdge.a), reason: e.key.name);
      expect(t.glassHighlightEdge.a, greaterThan(0), reason: e.key.name);
      expect(t.gradientBrandContrast, isNotNull, reason: e.key.name);
    }
    for (final t in [...uiLegacyThemes, UiThemeName.darkOrange, UiThemeName.maldives, UiThemeName.maldivesDark, UiThemeName.dark, UiThemeName.light]) {
      expect(uiThemeTokens[t]!.glassHighlightTop.a, 0, reason: t.name);
      expect(uiThemeTokens[t]!.glassHighlightEdge.a, 0, reason: t.name);
    }
  });
}
