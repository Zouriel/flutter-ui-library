# zouriel_ui (Flutter)

The [@zouriel/ui](https://github.com/Zouriel/angular-ui-library) design system for Flutter: the same
tokens, 15 themes and components as the Angular library, built on Flutter's widgets layer (no
Material), accessible, and tested component by component. Web docs for the Angular version:
<https://zouriel.com/uilib/>.

- **Flutter 3.47** / Dart 3.13. Android first (48dp touch targets, back button, TalkBack), also web.
- **Tokens generated from the web CSS** (`tool/gen_tokens.mjs` resolves every theme in a real
  browser), so colours, spacing, sizes, radii and motion match the Angular library exactly.
- **Form builder:** the engine reads and writes the **same JSON** as the web builder; shared JSON
  fixtures run in both test suites so the two behave identically. Includes the renderer (fill / edit /
  view), the searchable paginated source picker and the editor.
- **Workflow builder:** the builder, lifecycle diagram and runtime widgets (workflow panel with its
  running and stopped workflows, My tasks drawer, audit log, permissions, global settings) read and write the same
  Zouriel Workflows JSON as the web;
  the lifecycle layout runs the same fixtures in both suites. See `docs/WORKFLOW.md`.

## Layout

| Path | What |
| --- | --- |
| `packages/zouriel_ui` | The library (`package:zouriel_ui/zouriel_ui.dart`) |
| `apps/showcase` | Showcase app (Android APK + web): every component with demos, code and API |
| `tool/` | Token generator and the Angular inventory script |
| `docs/` | `PORTING.md` (decisions), `CONVENTIONS.md` (how components are built and tested), `inventory.md` (per-class checklist), `FORM_ENGINE.md`, `WORKFLOW.md` |

## Use

```yaml
dependencies:
  zouriel_ui:
    git:
      url: https://github.com/Zouriel/flutter-ui-library.git
      path: packages/zouriel_ui
      ref: v0.28.0   # a release tag; versions match the Angular @zouriel/ui
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

The map is a separate library on flutter_map (pinned 8.3.2): `import 'package:zouriel_ui/map.dart';`
for `UiMap`. Apps that don't import it don't build it in.

The sea theme comes as a day/night pair, `UiThemeName.maldives` and `UiThemeName.maldivesDark`
(the web's `maldives` and `maldives-dark`): a night toggle is
`controller.set(isNight ? UiThemeName.maldivesDark : UiThemeName.maldives)`. `UiSeaSurface` scopes
`maldives` unless given `theme: UiThemeName.maldivesDark` or `theme: null` (follow the app).

## Develop

```sh
flutter pub get
cd packages/zouriel_ui && flutter test          # widget, semantics, guideline and golden tests
cd apps/showcase && flutter run                 # or: flutter build apk --release --target-platform android-arm64
```

Regenerate tokens after changing the Angular stylesheets:

```sh
node tool/gen_tokens.mjs <angular>/projects/ui/styles packages/zouriel_ui/lib/src/theme/tokens.g.dart <chromium>
```

and the sea shapes after changing the Angular `projects/ui/fx/assets/maldives/*.svg`:

```sh
node tool/gen_sea_shapes.mjs <angular>/projects/ui/fx/assets/maldives packages/zouriel_ui/lib/src/fx/sea_shapes.g.dart
```

### Showcase APK

Build one APK per install target, never `--split-per-abi`: split APKs get different version codes
(1001, 2001, 4001) from the universal one (the plain build number), so swapping between them is
refused as a downgrade. Phones are arm64, so `--target-platform android-arm64` is enough. Release
builds are signed with the key named in `apps/showcase/android/key.properties` (gitignored; on the
owner's machine a link to `~/.config/zouriel-ui-showcase/key.properties`). Keep that one key:
Android will not update an installed app from an APK signed with a different one. Without the file
the build falls back to the machine's debug key.

## License

MIT. Bundled fonts (Roboto, Space Grotesk, Bricolage Grotesque, JetBrains Mono, Poppins) are under the SIL
Open Font License; see `packages/zouriel_ui/fonts/OFL-*.txt`.
