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

**Dialogs from above the navigator (0.44.1):** widgets placed by `UiApp.builder` (an SOS `UiFab` in a
`UiFabHost` that floats over dialogs and drawers) sit above the app's Navigator; the library's dialogs opened
from there (a hold button's tap confirm, `showUiConfirm`, `showUiModal`, `showUiDrawer`, the command
palette) now use the app's navigator through `UiNavigatorScope` (`uiNavigatorOf(context)`), the given
`navigatorKey` or the app's own. Angular has no navigator, so nothing changed there.

**Map search area, swipe screens, SOS button (0.44.0):** `UiMap(area: UiMapArea(center:,
radiusMeters:, tone:, editable: true, minMeters:, maxMeters:), onAreaChanging:, onAreaChanged:,
areaLabel:)` draws a search area in true metres (it scales with the zoom) under the routes and
markers; when editable a round handle on its inline-end edge, with a radius chip ("20 km",
`uiMapFormatRadius`), drags the radius (the map doesn't pan under it; it still pans everywhere
else) and is a slider for keyboards and screen readers. `UiMapState.fitArea()` shows the whole
circle in the visible part. `UiSwipeScreens(screens: [UiSwipeScreen(label: 'Chat', child: chat),
UiSwipeScreen(label: 'Map', edgeSwipeOnly: true, child: map)], index:, onIndexChanged:)` puts
full-size screens side by side: a clearly horizontal drag moves between them (vertical scrolling
inside still works), the first screen's leading 24px are left to the app's own drawer, and a map
screen only swipes back from its leading edge. `UiFabHost(position: UiFabPosition.topCenter, fab:
UiFab(tone: UiFabTone.danger, text: 'SOS', ...))` floats a high-visibility button at the top,
below the status bar (`topOffset:` for an app bar); the host draws it above its child, so in-page
sheets and drawers stay under it. `UiFab(hold: Duration(seconds: 2), confirmTitle:, ...)` is
press-and-hold like `UiHoldButton` (a tap or a screen reader opens a confirm dialog instead).
`UiButton` / `UiIconButton(badge: uiBadgeCount(n), badgeLabel: '2 unread')` show a count bubble at
the top-end corner, read after the name. `UiBottomSheet(footer:)` is a sticky bar at the bottom of
the visible sheet at every snap, and `UiFloatingPanel(insetEnd:)` keeps room at its inline end.

**Map background taps (0.43.1):** `UiMap.onMapTap` receives the tapped `UiLatLng` only for the map
background (the user dot counts as background)—not for a marker, pin, zoom/locate/app control, attribution, preview, drag or
double-tap zoom. In `pinMode`, a background tap keeps calling `onPinChanged` and then also calls
`onMapTap`, so a results map can clear its selected card without breaking location picking.

**Map preview, selected marker, label modes (0.43.0):** `UiMap(preview: true, onPreviewPressed:,
previewLabel:)` is a still picture of the map that is one button (`UiMapPreviewButton`), named
`previewLabel` or `UiStrings.mapOpen` ("Open map"): no gestures, keys or controls, markers drawn but
not tappable, the attribution visible but not a link, and only taps are claimed, so a drag or the
wheel over it scrolls the list around it. Enter or Space press it; a subtle press tint, the focus ring
inside the edge and a 30px round expand badge (`UiMapPreviewBadge`) at the top-end corner. `center`,
`zoom` and `fitPoints` still place it, without animating; `preview: false` gives the full map back.
`selectedMarkerId` draws that marker with a 22px dot (`uiMapSelectedDot`), a white ring and a halo in
its tone, on top, its label shown, `Semantics(selected: true)` (the others `false`).
`markerLabels: UiMapMarkerLabels.all / selected / none` says which labels show; hidden labels still
name their markers.

**Chat bubbles in any parent (0.42.2):** `UiChatBubble` keeps a short word on one line and wraps long
text at 80% of the row whatever its parent: a Column with any `crossAxisAlignment` (as before), an
`IntrinsicWidth` (it threw before: it now reports a width that fits its text) or a Row (unbounded
width: it caps at 80% of the screen instead of overflowing). The web bubble had the column problem
("okay" broke as "ok/ay" in a column aligned to the start) and now takes the whole row too.

**Map controls, a fit that holds, labels off the edge (0.42.1):** a `UiMapState.fitPoints` fit owns
the camera: when `viewInsets` change while it animates or after it (a sheet growing as the route
appears) it is worked out again for the new insets (an animating fit is retargeted, keeping its
progress) instead of panning by the inset difference, until a gesture, `flyTo`, the zoom buttons or a
new `center` / `zoom` moves the map. `UiMap(controls: [UiMapControl(id:, icon:, semanticLabel:,
onPressed:, tooltip:)])` adds the app's own round buttons (`UiMapControlButton`: the locate button's
surface, 38 / 44 on touch with 48dp targets) stacked 8 apart above the locate button at the bottom-end
of the visible part, following `viewInsets`, at the bottom-left in RTL; `onPressed` null shows one
disabled. For "Show both": `onPressed: () => mapKey.currentState!.fitPoints([me, patient])`. Marker
labels sit 12 from the point at the inline end of the dot and flip to the other side near the map's
edge (`uiMapLabelSide`, mirrored in RTL).

**Map routes and fit to points (0.42.0):** `UiMap(routes: [UiMapRoute(id:, points:, tone:
UiMapRouteTone.primary, semanticLabel: 'Route, 1.2 km')])` draws lines along the road (from OSRM, say)
in the theme's `mapRoute*` colour over `mapRouteCasing`, round-capped, 5 over 9px close in and thinner
zoomed out, above the tiles and below the pulse, the dot, the markers and the pin; a new list redraws
on the same map and an empty one removes them. `UiMapState.fitPoints(points, padding:, maxZoom:,
animate:)` shows every point inside the part `viewInsets` leave visible (24 to spare, a whole zoom up
to 17; one point is centred at 17), animated unless reduced motion. Marker labels size to their text
up to 320 (or the map less 32) and wrap to two lines; the zoom buttons (`UiMapZoomButton`) share the
locate button's raised surface and shadow2.

**Clear glass, drawers on the keyboard, sheet cover (0.41.3):** `glassStrength` on
`UiBottomSheet` and `UiFloatingPanel`, `UiGlassStrength.clear` by default: over a map in the theme's
own brightness the map plainly shows through (`glassClearBg`, a 12% tint, over a light blur,
`glassClearBlur`, squeezed into the theme's `glassClearFloor`..`glassClearCeiling` and saturated by
`glassClearSaturate` so water and parks stay apart). The range is set per theme only as far as text,
muted text, primary and status colours (4.5:1) and icons and warning (3:1) need over the colours
MapTiler's dataviz / dataviz-dark draw Male in, so 43-75% of the map's contrast comes through.
`UiGlassStrength.frosted` is the 0.41.2 recipe below (AA over anything): use it over photos or a map
in the other brightness. A bottom `UiDrawer` now rests on the on-screen keyboard (before, the
keyboard covered it and its footer). `UiBottomSheet.onCoverChanged` / `onHeightChanged` now follow
every change of the resting top (new snaps at the same index, the keyboard, the room), once per
change, after the frame.

**Glass bottom sheet and floating panel (0.41.2):** `UiBottomSheet(glass: true)` and
`UiFloatingPanel(glass: true)` are see-through, for a form and a status card over a full-screen map:
the theme's surface at 60% (`glassSheetBg`) over the content behind, which a `BackdropFilter` blurs
(`glassSheetBlur`) and squeezes into the theme's `glassSheetFloor`..`glassSheetCeiling` range first
(`uiGlassSheetFilter`). The range is set per theme so text, muted text, primary and status colours
keep WCAG AA over anything, pure white and pure black included. Fields and buttons inside keep their
solid fills, and the shadow is drawn only around the surface (`UiOutsetShadow`), never under it.
Flutter has no reduce-transparency setting, so under `MediaQuery.highContrast` it is the solid
surface (`uiGlassSheetSolid`). The sheet's glass is off by default whatever `UiConfig.glass` says;
the panel's still defaults to `UiConfig.glass`, and now uses this recipe.

**Image and PDF viewers can fill the page (0.41.1):** `UiImageViewer(fill: true)` and
`UiPdfViewer(fill: true)` take all the height their parent gives (an `Expanded` under a page title, a
full route) with no frame: the photo or page is fitted (contain, centred; 100% is fitted), pinch,
double tap, Ctrl+wheel and the buttons zoom, a zoomed photo pans, and the controls float over the
bottom as a pill on the glass panel surface, above `MediaQuery.paddingOf(context).bottom`, instead of
a bar of their own. The PDF viewer adds a Fit button. In an unbounded parent `fill` falls back to
`maxHeight`. Without `fill` nothing changes, except that a picture smaller than the stage is now fitted
up to it like a larger one is fitted down (the zoom clamp already assumed it was).

**Fixed header and footer in drawers and sidebars (0.41.0):** `showUiDrawer` takes `headerBuilder`
and `footerBuilder` (`UiDrawer.header` / `footer`), placed outside the body's scroll view: title bar,
fixed header, the scrolling body, fixed footer (above the home indicator and, on a left or right
drawer, the keyboard). The body is `builder` (wrapped in a scroll view) or `bodyBuilder:
(context, controller) => ListView.builder(controller: controller, padding:
UiDrawer.bodyPadding(context), ...)` for a paging list. `UiSidebarLayout` takes `sidebarHeader` and
`sidebarFooter`, fixed around `sidebar` docked and in the drawer (with `scrollSidebar: false` the
sidebar can be the app's own `ListView`); the safe area goes on the outer parts. A hairline shows
under the header and over the footer while the body is scrolled out of sight on that side; Tab and
screen readers go header, body, footer. Without them nothing changes. `UiScrollFade` gains
`onEdgesChanged`, and `size: 0` draws no fade.

**Feature card colours follow the active theme (0.40.2):** a web fix (a card created while the
app's stylesheet was still loading kept the dark pair on a light theme). `UiFeatureCard` already takes
dark or light from the `UiApp` theme (its surface), never the platform brightness, on the very first
frame; tests now pin that, with a device in dark mode and a light `UiApp` (fixed or controller).

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
