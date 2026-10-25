import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'package:hugeicons/hugeicons.dart';

import '../shell.dart' show densityOptions, themeLabels;

class FoundationPage extends StatelessWidget {
  const FoundationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final swatches = <String, Color>{
      'bg': t.bg, 'surface': t.surface, 'surfaceRaised': t.surfaceRaised, 'text': t.text, 'textMuted': t.textMuted,
      'border': t.border, 'primary': t.primary, 'secondary': t.secondary, 'accent': t.accent, 'success': t.success,
      'warning': t.warning, 'danger': t.danger, 'info': t.info, 'selected': t.selected, 'track': t.track,
    };
    return DocPage(
      eyebrow: 'Getting started',
      title: 'Foundation',
      lead: 'Design tokens and themes. Every value comes from the web library\'s stylesheets, resolved for each theme by a generator, so both libraries look the same.',
      children: [
        DocSection(
          name: 'Design tokens',
          widget: 'context.ui',
          summary: 'Components read tokens, never literal values: colours, spacing (4, 8, 12, 16, 24, 32, 48, 80), control sizes (26 / 30 / 38, touch 44), radii, motion and shadows. The swatches show the current theme.',
          demo: DocGrid(minWidth: 88, gap: t.space3, children: [
            for (final e in swatches.entries)
              Column(spacing: 4, children: [
                Container(height: 40, decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(t.radius), border: Border.all(color: t.border))),
                UiText(e.key, variant: UiTextVariant.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
          ]),
          code: 'final t = context.ui;\nContainer(\n  padding: EdgeInsets.all(t.space4),\n  color: t.surface,\n  child: Text(\'Hi\', style: context.uiText.body),\n)',
        ),
        DocSection(
          name: 'Themes',
          widget: 'UiThemeController',
          summary: 'Fifteen themes: Winter Dark and Winter Light (the defaults), ten colour palettes, Dark Orange with its own fonts, and Maldives and Maldives Dark, the sea theme by day and by night with Poppins and its own sea backdrops (see Motion & FX). Each tile below renders in its own theme with UiThemeScope. Tap one to switch the whole app; theme changes animate.',
          demo: DocGrid(minWidth: 168, minColumns: 2, children: [
            for (final th in UiThemeName.values)
              UiThemeScope(
                theme: th,
                child: Builder(builder: (context) {
                  final s = context.ui;
                  return Container(
                    padding: EdgeInsets.all(s.space3),
                    decoration: BoxDecoration(border: Border.all(color: s.border), borderRadius: BorderRadius.circular(s.radius)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: s.space2, children: [
                      UiText(themeLabels[th]!, variant: UiTextVariant.label),
                      UiButton(label: 'Button', size: UiSize.sm, onPressed: () {}),
                      const UiBadge(label: 'Badge', tone: UiStatus.success),
                    ]),
                  );
                }),
              ),
          ]),
          code: 'final themes = UiThemeController(theme: UiThemeName.dark);\nUiApp(controller: themes, home: ...);\nthemes.set(UiThemeName.lightTeal);\nthemes.toggle(); // Winter dark <-> light\n\n// A different theme for one part of a page:\nUiThemeScope(theme: UiThemeName.light, child: ...)',
          api: const [
            ApiRow('set(theme)', 'method', 'Switch the app theme.'),
            ApiRow('toggle()', 'method', 'Winter dark and light; from any other theme goes to dark.'),
            ApiRow('setConfig(config)', 'method', 'Change UiConfig (glass, radius, animations, font).'),
          ],
          shapes: 'enum UiThemeName { dark, light, lightOrange, lightPink, lightTeal, lightPurple,\n  lightPurpleGold, darkPink, darkTeal, darkPurple, goldBlack, goldRed, darkOrange,\n  maldives, maldivesDark }',
        ),
        DocSection(
          name: 'Density',
          widget: 'UiConfig.density',
          summary: 'How big things are drawn (0.45.0). Comfortable, the default, is the library as it always was. Compact makes things smaller, not tighter: body text 14 instead of 15 (small 12, large 16), headings about 10% smaller, controls lower (md 26 and lg 34, 4 less; sm 24, 2 less), icons and the switch, checkbox and radio marks 10% smaller (a 20 icon is drawn at 18). Spacing, corner radii and touch targets do not change: every control keeps its 48dp tap area. Auto is compact below 600 wide and comfortable above, and follows resizes and rotation. Set it in UiConfig, change it at runtime with the controller\'s setConfig, or draw one subtree in another density with UiDensityScope. Try it here, or in the theme sheet from the top bar.',
          demo: Builder(builder: (context) {
            final c = UiThemeController.maybeOf(context);
            final s = context.ui;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: s.space3, children: [
              if (c != null)
                ListenableBuilder(
                  listenable: c,
                  builder: (context, _) => UiSegmented<UiDensity>(
                    label: 'Density',
                    options: densityOptions,
                    value: c.config.density,
                    onChanged: (d) => c.setConfig(c.config.copyWith(density: d)),
                  ),
                ),
              const UiText('Find a nurse', variant: UiTextVariant.h3),
              const UiText('Body text, inputs, chips and buttons follow the density tokens.'),
              const SizedBox(width: 360, child: UiInput(placeholder: 'Search an island')),
              Wrap(spacing: s.space3, runSpacing: s.space2, crossAxisAlignment: WrapCrossAlignment.center, children: const [
                UiChip(label: 'Home visit'),
                UiChip(label: 'Today'),
                UiAvatar(name: 'Aisha Rasheed'),
                UiIcon(HugeIcons.strokeRoundedNotification01),
              ]),
              Wrap(spacing: s.space3, runSpacing: s.space2, children: [
                UiSwitch(value: true, label: 'Notify me', onChanged: (_) {}),
                UiCheckbox(value: true, label: 'Remember', onChanged: (_) {}),
              ]),
              Wrap(spacing: s.space3, children: [
                UiButton(label: 'Book', variant: UiButtonVariant.primary, onPressed: () {}),
                UiButton(label: 'Later', variant: UiButtonVariant.outline, onPressed: () {}),
              ]),
            ]);
          }),
          code: 'UiApp(config: const UiConfig(density: UiDensity.auto), home: ...) // compact on phones\n\n// At runtime:\nthemes.setConfig(themes.config.copyWith(density: UiDensity.compact));\n\n// One subtree:\nUiDensityScope(density: UiDensity.compact, child: ...)',
          api: const [
            ApiRow('UiConfig.density', 'UiDensity', 'comfortable, compact or auto (compact below uiCompactBelow, 600).', def: 'comfortable'),
            ApiRow('UiDensityScope', 'widget', 'Draws its child in another density.'),
            ApiRow('UiThemeData.compact', 'bool', 'Whether compact is drawn (UiApp resolves auto from the window width).'),
            ApiRow('compact values', 'tokens', 'fontSizeSm/Md/Lg 12/14/16; fontSizeH1/H2/H3/H5/H6 36/27/20/15/13; sizeSm/Md/Lg 24/26/34; fontScale 0.93 (text components size in px); densityScale 0.9 (icons, switch, checkbox, radio). Spacing, radii, sizeTouch and sizeXl unchanged.'),
          ],
          shapes: 'enum UiDensity { comfortable, compact, auto }',
        ),
        DocSection(
          name: 'Right to left and Dhivehi',
          widget: 'UiApp.textDirection · UiStrings.dv',
          summary: 'Every component mirrors in right-to-left text (0.46.0): paddings, borders and badges use start and end, drawers on the start side and toasts at the end corner follow the direction, back and forward chevrons flip (play, check and search icons do not), carousels, tabs, sliders and splitters move and take arrow keys the RTL way, and swipe-back comes from the right edge. Maps and one-time-code boxes do not mirror. UiApp(textDirection:) sets the direction (null follows the locale: dv, ar, he, fa, ur are RTL). UiStrings.dv is every built-in word in Dhivehi, with Dhivehi month and day names; switch language at runtime with setStrings, and give the Thaana font with UiConfig.fontFamilyFallback. The RTL · ދިވެހި button in the top bar shows every page this way.',
          demo: Builder(builder: (context) {
            final s = context.ui;
            return Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: s.space3, children: [
              UiText(Directionality.of(context) == TextDirection.rtl ? 'Right to left, ${context.uiStrings.locale.isEmpty ? 'English' : 'Dhivehi'} words' : 'Left to right (use the RTL · ދިވެހި button)'),
              const SizedBox(width: 360, child: UiAlert(message: 'The tone edge sits on the start side.')),
              Wrap(spacing: s.space2, children: [UiChip(label: 'Malé', onRemove: () {}), UiChip(label: 'Hulhumalé', onRemove: () {})]),
              UiPagination(page: 2, total: 5, onChanged: (_) {}),
              const SizedBox(width: 340, child: UiSearchInput()),
            ]);
          }),
          code: '''UiApp(
  textDirection: dhivehi ? TextDirection.rtl : TextDirection.ltr,
  controller: themes, // UiThemeController(config: UiConfig(fontFamilyFallback: ['Faruma', 'Noto Sans Thaana']))
  home: ...,
);

// The language toggle:
themes.setStrings(dhivehi ? UiStrings.dv : const UiStrings());

// A few words of your own on top of the Dhivehi set:
UiStrings.dv.copyWith(close: 'ނިންމާ');''',
          api: const [
            ApiRow('UiApp.textDirection', 'TextDirection?', 'The app\'s direction; null follows locale (uiRtlLanguages).', def: 'null'),
            ApiRow('UiStrings.dv', 'UiStrings', 'Every built-in word in Dhivehi (Thaana), Dhivehi months and days, Sunday-first weeks, day-month-year dates.'),
            ApiRow('UiThemeController.setStrings', 'void', 'Switches the words at runtime; everything reading context.uiStrings rebuilds at once.'),
            ApiRow('UiStrings.copyWith', 'UiStrings', 'A copy with some words replaced.'),
            ApiRow('uiFormatString', 'String', 'Fills {n}, {label}, … placeholders.'),
            ApiRow('UiConfig.fontFamilyFallback', 'List<String>?', 'The app\'s fonts for glyphs the theme font lacks (Faruma for Thaana), on every library text.', def: 'null'),
            ApiRow('UiIcon.matchTextDirection', 'bool', 'Mirror a direction icon in RTL.', def: 'false'),
            ApiRow('date keys', 'UiStrings', 'locale, months, monthsShort, weekdays, weekdaysShort (Sunday first), firstDayOfWeek (0 Sunday; null from the locale), dateFormat, dateFormatShort, monthYearFormat ({d} {month} {y}).'),
          ],
        ),
        DocSection(
          name: 'Library defaults',
          widget: 'UiConfig',
          summary: 'App-wide defaults, the twin of the web provideUiConfig. animations: false removes the library\'s motion; the Android "remove animations" setting does the same automatically.',
          code: "UiApp(\n  config: UiConfig(glass: true, radius: true, animations: true,\n      strings: UiStrings(close: 'ބަންދުކުރޭ', previousPage: 'ކުރީ ޞަފްޙާ')),\n  home: ...,\n)",
          api: const [
            ApiRow('glass', 'bool', 'Frosted surfaces on components that support it.', def: 'false'),
            ApiRow('radius', 'bool', 'Rounded corners.', def: 'true'),
            ApiRow('animations', 'bool', 'Library motion.', def: 'true'),
            ApiRow('density', 'UiDensity', 'How big things are drawn (0.45.0); see Density.', def: 'comfortable'),
            ApiRow('fontFamily', 'String?', 'Overrides the theme font.'),
            ApiRow('fontFamilyFallback', 'List<String>?', 'App fonts for glyphs the theme font lacks (0.46.0), e.g. [\'Faruma\'] for Thaana.', def: 'null'),
            ApiRow('strings', 'UiStrings', 'The library\'s own words (the web provideUiStrings), English by default: close, dismiss, clear, clearAll, clearSearch, previousPage, nextPage, previousMonth, nextMonth, chooseDate, moreActions, uploadLabel, uploadHint, holdHint, confirmTitle, confirm, cancel, zoomIn, zoomOut, placePinAtCentre, mapLocate, mapLocationOff, mapYourLocation, mapOpen, googleSignIn, googleSignUp, googleContinue, googleSignInShort, sidebarToggle, sidebarClose, sidebarLabel. 0.46.0 adds the rest (loading, previous/next, slides, viewers, pagination, OTP, remove, password, pickers, table, …) and the date names; UiStrings.dv is the full Dhivehi set. Read with context.uiStrings.', def: 'UiStrings()'),
          ],
        ),
      ],
    );
  }
}
