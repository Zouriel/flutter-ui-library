import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import '../shell.dart' show themeLabels;

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
          demo: Wrap(spacing: t.space2, runSpacing: t.space2, children: [
            for (final e in swatches.entries)
              SizedBox(
                width: 96,
                child: Column(spacing: 4, children: [
                  Container(height: 40, decoration: BoxDecoration(color: e.value, borderRadius: BorderRadius.circular(t.radius), border: Border.all(color: t.border))),
                  UiText(e.key, variant: UiTextVariant.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ]),
          code: 'final t = context.ui;\nContainer(\n  padding: EdgeInsets.all(t.space4),\n  color: t.surface,\n  child: Text(\'Hi\', style: context.uiText.body),\n)',
        ),
        DocSection(
          name: 'Themes',
          widget: 'UiThemeController',
          summary: 'Thirteen themes: Winter Dark and Winter Light (the defaults), ten colour palettes, and Dark Orange with its own fonts. Each tile below renders in its own theme with UiThemeScope. Tap one to switch the whole app; theme changes animate.',
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
          shapes: 'enum UiThemeName { dark, light, lightOrange, lightPink, lightTeal, lightPurple,\n  lightPurpleGold, darkPink, darkTeal, darkPurple, goldBlack, goldRed, darkOrange }',
        ),
        DocSection(
          name: 'Library defaults',
          widget: 'UiConfig',
          summary: 'App-wide defaults, the twin of the web provideUiConfig. animations: false removes the library\'s motion; the Android "remove animations" setting does the same automatically.',
          code: 'UiApp(\n  config: UiConfig(glass: true, radius: true, animations: true),\n  home: ...,\n)',
          api: const [
            ApiRow('glass', 'bool', 'Frosted surfaces on components that support it.', def: 'false'),
            ApiRow('radius', 'bool', 'Rounded corners.', def: 'true'),
            ApiRow('animations', 'bool', 'Library motion.', def: 'true'),
            ApiRow('fontFamily', 'String?', 'Overrides the theme font.'),
          ],
        ),
      ],
    );
  }
}
