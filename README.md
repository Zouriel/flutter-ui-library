# zouriel_ui (Flutter)

The [@zouriel/ui](https://github.com/Zouriel/angular-ui-library) design system for Flutter: the same
tokens, 13 themes and components as the Angular library, built on Flutter's widgets layer (no
Material), accessible, and tested component by component. Web docs for the Angular version:
<https://zouriel.com/uilib/>.

- **Flutter 3.47** / Dart 3.13. Android first (48dp touch targets, back button, TalkBack), also web.
- **Tokens generated from the web CSS** (`tool/gen_tokens.mjs` resolves every theme in a real
  browser), so colours, spacing, sizes, radii and motion match the Angular library exactly.
- **Form builder:** the engine reads and writes the **same JSON** as the web builder; shared JSON
  fixtures run in both test suites so the two behave identically. Includes the renderer (fill / edit /
  view), the searchable paginated source picker and the editor.

## Layout

| Path | What |
| --- | --- |
| `packages/zouriel_ui` | The library (`package:zouriel_ui/zouriel_ui.dart`) |
| `apps/showcase` | Showcase app (Android APK + web): every component with demos, code and API |
| `tool/` | Token generator and the Angular inventory script |
| `docs/` | `PORTING.md` (decisions), `CONVENTIONS.md` (how components are built and tested), `inventory.md` (per-class checklist), `FORM_ENGINE.md` |

## Use

```yaml
dependencies:
  zouriel_ui:
    git:
      url: https://github.com/Zouriel/flutter-ui-library.git
      path: packages/zouriel_ui
      ref: v0.22.0   # a release tag; versions match the Angular @zouriel/ui
```

```dart
import 'package:zouriel_ui/zouriel_ui.dart';

void main() => runApp(UiApp(
  theme: UiThemeName.dark,
  home: Builder(builder: (context) => UiButton(label: 'Save', onPressed: () {})),
));
```

`UiApp` replaces `MaterialApp`. Read tokens with `context.ui`, text styles with `context.uiText`;
switch themes with a `UiThemeController`; scope a theme with `UiThemeScope`.

## Develop

```sh
flutter pub get
cd packages/zouriel_ui && flutter test          # widget, semantics, guideline and golden tests
cd apps/showcase && flutter run                 # or: flutter build apk --release --split-per-abi
```

Regenerate tokens after changing the Angular stylesheets:

```sh
node tool/gen_tokens.mjs <angular>/projects/ui/styles packages/zouriel_ui/lib/src/theme/tokens.g.dart <chromium>
```

## License

MIT. Bundled fonts (Roboto, Space Grotesk, Bricolage Grotesque, JetBrains Mono) are under the SIL
Open Font License; see `packages/zouriel_ui/fonts/OFL-*.txt`.
