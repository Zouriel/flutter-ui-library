import 'package:flutter/widgets.dart';

import '../docs/doc.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const DocPage(
      eyebrow: 'Introduction',
      title: 'UI Library',
      lead: 'The @zouriel/ui design system for Flutter: the same tokens, themes and components as the Angular library, built on Flutter\'s widgets layer (no Material), accessible, and tested component by component.',
      children: [
        DocSection(
          name: 'Install',
          summary: 'Add the package, then wrap the app in UiApp. UiApp replaces MaterialApp: it provides the theme, text styles, navigation and scrolling.',
          code: "dependencies:\n  zouriel_ui:\n    git: <repo url>\n\nimport 'package:zouriel_ui/zouriel_ui.dart';\n\nvoid main() => runApp(UiApp(\n  theme: UiThemeName.dark,\n  home: HomePage(),\n));",
        ),
        DocSection(
          name: 'Principles',
          summary: 'Tokens only: no hard-coded colours (a test fails on any). Keyboard and screen-reader support on every control. Touch targets of at least 48dp on phones without growing the visual. Motion respects the system "remove animations" setting. Every component has widget tests, accessibility guideline checks and golden images in dark and light.',
        ),
      ],
    );
  }
}
