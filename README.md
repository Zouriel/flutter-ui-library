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
for `UiMap`. Apps that don't import it don't build it in. `UiMapMarker.semanticLabel` names a
marker without exposing its id; `pinDraggable: false` shows a read-only pin; `tileHeaders` adds
request headers. Widget tests can pass `UiMapBlankTiles()` to avoid the network without adding
flutter_map as a direct dependency. Map control words are in `UiStrings`.

**Sign in with Google:** `UiGoogleSignInButton` draws Google's branded button (light, dark,
neutral or `auto` from the theme; rectangular or pill; `loading`; `expand`). The library doesn't
sign anyone in: add the `google_sign_in` package to the app, call
`GoogleSignIn.instance.initialize(serverClientId: <web client ID>)` once, and in `onPressed` call
`authenticate()` and send `authentication.idToken` to your API. The words (`googleSignIn`,
`googleSignUp`, `googleContinue`, `googleSignInShort`) are in `UiStrings`. Its text is the bundled
Roboto Medium (Google's guideline now uses Google Sans, which the library doesn't ship).

**App shell and feature card (0.37):** `UiSidebarLayout` puts the sidebar on the start side (the
right in right-to-left text, sliding in from the right) and takes its words from `UiStrings`
(`sidebarToggle`, `sidebarClose`, `sidebarLabel`). For an app with its own top bar, `bar: false`
drops the built-in bar and menu button, `fill: true` gives the body all the space (no padding, no
scroll view: put a list and a docked composer in it) and keeps clear of the safe area, and
`UiSidebarLayout.of(context)` gives `compact` (drawer mode), `open`, `toggle()` and `close()` so the
app shows its own menu button only in drawer mode. `UiFeatureCard` is a product card for a landing
page: an icon in a tinted badge, eyebrow, title, description and an action, with `tone` (primary,
accent, brand, neutral), `layout` (vertical, horizontal) and `size` (md, lg); with `onPressed` the
whole card is one button.

**Compact tinted feature card (0.38):** `UiFeatureCard` gains `size: UiSize.sm` (16 padding, 40 badge,
20 icon, body-strong title), `surface: UiFeatureSurface.tinted` (a soft wash in the tone, no border,
shadow only on hover), `controlRadius` (a text field's corners), `trailingArrow` (with `onPressed` and
no `actionLabel`, the whole card is one button named "title, description" with an arrow that points
the reading way) and `descriptionLines` (clamp with an ellipsis). Two of them in an
`IntrinsicHeight` + stretched `Row` under a `UiInput` make a start screen's shortcut tiles, exactly
the field's width and equal in height.

**Full-screen map pages (0.39):** `UiMap` gains `pulse: UiMapPulse(lat:, lng:, tone:, active:)` (soft
rings radiating from a point while the app searches: three staggered rings, 2.4s, up to 120px,
geo-anchored under the markers and pin, a still halo under reduced motion, silent for screen
readers), `viewInsets: EdgeInsetsDirectional` (how much of each edge a sheet or card covers: the
map draws edge to edge, but its centre, the pin's centre, `onCenterChanged`, zoom-button zooming,
the zoom buttons and the attribution use the part between them; when the insets change the map pans
so the middle of the visible part stays in the middle) and `fill` (square corners).
`UiFloatingPanel.onCoverChanged` and `UiBottomSheet.onCoverChanged` give the numbers for
`viewInsets`. `UiMapBlankTiles` is now truly transparent (it used to tint the map blue).

**Persistent bottom sheets (0.39.1):** a `UiBottomSheet` whose smallest snap is above 0 (e.g.
`snaps: [0.3, 0.55, 1]`, peek/half/full with no closed state) is `persistent`. Back (Android back,
or `Navigator.maybePop` from a header Back button) and Escape collapse it to its smallest snap
first; once it rests there Back is not consumed and the route pops as usual, as Material resting
sheets do. A sheet with a 0 snap keeps closing on Back before the route pops. `maxWidth: 560`
caps the sheet on wider screens: its surface, handle, title row and body are that wide and centred,
the backdrop still covers the whole screen, and `onCoverChanged` still reports the covered height.

**48dp map controls on touch, LTR attribution (0.40.1):** on touch platforms `UiMapLocateButton`
keeps its 44dp circle in the same place with a 48dp hit area around it (it meets
`androidTapTargetGuideline`, like the zoom buttons), and the `UiMap` attribution is laid out LTR, so
English credits keep their © signs in place in RTL while its corner still flips.

**Map tiles, my location, a sheet that holds still (0.40):** `UiMap` gains `tileUrlDark` (tiles drawn
for dark themes, shown undimmed and swapped live with the theme; `tileHeaders` go with both),
`tileSize` / `zoomOffset` (512 px tiles: 512, -1) and `{r}` retina URLs (`@2x` on a high-density
screen); `locateControl` (a round "Show my location" button at the bottom-end of the visible part,
just above a bottom sheet, with `locating` (spinner) and `locateOff` (struck through, "Location is
off") states, `onLocate`), `userLocation: UiMapUserLocation(lat, lng, accuracy:)` (the "you are here"
dot, tokens `location` / `locationRing`, over a halo sized in metres) and `UiMapState.flyTo`.
`UiBottomSheet` reads an index past the end of `snaps` as the last snap (it threw a RangeError),
stays at the same height when `snaps` changes, and `expandOnFocus` raises it once per field.

**Feature card colours and motion (0.39):** `UiFeatureCard` gains `badgeTone` (the badge in its own
tone), `colors: UiFeatureCardColors(surface:, accent:, surfaceDark:, accentDark:)` (or
`UiFeatureCardColors.tryParse` from hex/rgb strings: an app's own surface and accent, with the dark
pair derived and every colour contrast-checked by `uiResolveFeatureColors`, the same sums as the
web), and `enter` / `enterDelay` (a one-time fade and 8px rise, staggered). On hover, focus and press
the badge icon lifts and the arrow nudges towards the end; no motion when animations are off.

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
