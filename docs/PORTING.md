# Porting @zouriel/ui to Flutter

The Angular library (`/home/zouriel/personal/angularUiLib/ui-workspace/projects/ui`, v0.20.0) is the
source of truth. This repo recreates it for Flutter mobile. `docs/inventory.md` is the per-class
checklist (generated from the Angular source by `tool/angular_inventory.py`); this file holds the
decisions and the plan.

## Toolchain (researched 2026-10-13)

| Thing | Version | Notes |
| --- | --- | --- |
| Flutter | 3.47.7 stable (2026-10-08) | Dart 3.13.5. Installed at `~/development/flutter`. |
| JDK | Temurin 21 | Only for Gradle when building the APK. `~/development/jdk21`. |
| Android SDK | cmdline-tools, platform 36, build-tools 36 | `~/Android/Sdk`. Flutter 3.47 template: compile/target 36, min 24, AGP 9.1, Gradle 9.3.1, Kotlin 2.4. |

Flutter 3.47 facts that shape the design:
- Material and Cupertino moved to standalone packages (`material_ui` 1.x, `cupertino_ui`); the core
  SDK copies are deprecated in the November 2026 stable. **The library builds on
  `package:flutter/widgets.dart` only** (no Material import), so it is unaffected and looks like our
  design, not Material. The showcase app may use `material_ui` only where it saves real work.
- Impeller is the renderer everywhere; avoid effects that only worked with Skia.
- `MediaQueryData.highContrast`/`invertColors` are detected on Android: honour them.
- `BlockSemantics` now also blocks focus: use it for modal layers.
- Widget Previews are stable (`@Preview`), handy while building components.

## Repo layout

```
flutterUiLib/
  pubspec.yaml               # pub workspace root
  packages/zouriel_ui/       # the library (package:zouriel_ui)
    lib/zouriel_ui.dart      # barrel; also one library per area (lib/button.dart ...)
    lib/src/theme/           # tokens (generated), UiTheme, themes
    lib/src/<area>/          # components
    test/                    # widget + golden tests, mirrors lib/src
  apps/showcase/             # the showcase app (Android APK + web)
  tool/                      # generators: tokens from CSS, inventory
  docs/                      # this file, inventory.md
```

## Design decisions

**Tokens and themes.** `tool/gen_tokens.py` reads the Angular `styles/tokens.css`,
`theme-palettes.css` and `theme-dark-orange.css` and writes `lib/src/theme/tokens.g.dart`: every
`--ui-color-*`, spacing (1/2/3/4/6/8/12/20 → 4..80 px), radius, size (sm/md/lg/touch), font sizes,
motion durations and easings, for all 15 themes. `UiTokens` is a `ThemeExtension`-style immutable
class with `lerp` so theme changes animate. Nothing in a widget hard-codes a colour or spacing; a
test fails on literal `Color(0x...)` in `lib/src` outside the generated file (mirror of the Angular
style-contract spec).

**Theme access.** `UiTheme` (InheritedWidget) + `UiTheme.of(context)`; `UiThemeScope` for scoped
themes (the `ui-theme-provider` equivalent); `UiThemeController` (ChangeNotifier) = `UiThemeService`
(set/toggle, persisted by the app). `UiApp` wraps `WidgetsApp` with the theme, text direction, default
text style and focus/scroll behaviour, since we don't use `MaterialApp`.

**Fonts.** Default: the platform font (Roboto on Android), like `system-ui` on web. Dark Orange uses
its own families; bundle them as package assets (OFL fonts) rather than fetching at runtime.
Golden tests load real fonts in `flutter_test_config.dart` so goldens are readable.

**Icons.** `hugeicons` (pub 1.2.x), the same free Hugeicons set as the Angular library. Never emoji or
text glyphs as icons.

**Components API mapping (Angular → Flutter).**
- `input()` → constructor parameter. `model()` (two-way) → `value` + `onChanged` (controlled), and for
  text-like controls an optional controller. `output()` → `ValueChanged`/`VoidCallback` callbacks.
- Content projection slots (`[card-header]`) → named widget parameters (`header:`, `footer:`, `leading:`).
- Form controls (ControlValueAccessor) → controlled widgets plus `UiFormField<T>` (wraps Flutter's
  `FormField`) for validation, `disabled`, error text, label association.
- Directives (`uiTooltip`, `uiSwipe`, `uiReveal`...) → wrapper widgets (`UiTooltip(child:)`).
- CDK Overlay → `OverlayPortal` + our own anchored positioning with flip/shift (same rules as the
  Angular overlays: preferred side, flip to the opposite, keep 8px inside the screen).
- Focus trap → `FocusScope` + `BlockSemantics` + `ModalBarrier`; restore focus on close.
- Keyboard: `Shortcuts`/`Actions`/`FocusableActionDetector`, same keys as the Angular docs say
  (hardware keyboards and TalkBack still matter on Android).

**Accessibility.** Every interactive widget: `Semantics` with role/label/value/state, focusable,
visible focus ring (token), touch target ≥ 48dp on mobile (Android guideline; Angular uses 44 on
touch and 24 on desktop). Tests use Flutter's built-in guideline matchers:
`androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline`.
Respect `MediaQuery.disableAnimations` (reduced motion), text scaling up to 200% without clipping.

**Testing (per component, before it's ticked off).**
1. Widget tests: behaviour, callbacks, keyboard, disabled state, semantics.
2. Accessibility guideline matchers (tap target, labels, contrast).
3. Golden images in dark and light themes (plus states), reviewed by eye when created.
4. A showcase page section, checked on the web build and on Android.

**Maldives theme and sea backdrops (0.31.0).** `theme-maldives.css` is generated into
`UiThemeName.maldives` like every theme; its brand colours (`oceanDeep`, `lagoon`, `coral`, `sand`,
`mist`) are nullable tokens, present only in maldives, so the sea widgets fall back to theme roles
elsewhere (`uiSeaTone`). Poppins is bundled (400–700) and picked up from the theme's font tokens.
The silhouettes come from the Angular library's shared SVGs (`projects/ui/fx/assets/maldives`):
`tool/gen_sea_shapes.mjs` turns them into `lib/src/fx/sea_shapes.g.dart` (path opcodes, no SVG
dependency, drawn with CustomPainter); never edit the generated file. Positioned web components
(`ui-wave-footer`, the decor) fill the space they are given and draw at the bottom / in their
corner, so in a `Stack` they go in `Positioned.fill`. The web's signature motion in
`theme-animations.css` had no Flutter twin; for parity in this theme the fx.css classes are now
widgets (`UiGradientText`, `UiGlow`, `UiPulse`) and only maldives' keyframes are ported (`ui-fx-tide`
as a gradient ebb, `ui-fx-shimmer` as a glow lift: Flutter strengthens the glow shadow rather than
filtering brightness). The other palettes' sheen/breathe/aurora motion is still web-only.
`[uiTide]` becomes `UiTide(index:, delay:, step:)`; its wait is the front of one controller run, so
tests never leave a timer pending.

**0.37.0 additions.** `UiSidebarLayout`: `bar`, `fill`, `scrollSidebar`, RTL (the sidebar is on the
start side through `Directionality`, `BorderDirectional` and `AnimatedPositionedDirectional`),
`UiSidebarLayout.of(context)` (an InheritedWidget with `compact`, `open`, `toggle`, `close`; the web
exposes `compact` as a readonly signal), focus back to the opener on close, and the words in
`UiStrings`. The web drawer has a "Close navigation" button that shows when focused; Flutter gives
screen readers the same control as the backdrop (a labelled button, like Material's ModalBarrier)
plus `onDismiss` on the drawer. `fill` handles the safe area itself: the page column pads top,
bottom and the far side with `MediaQuery.paddingOf`, the sidebar pads top, bottom and its own side
inside its background, and both remove those insets for their children so a nested SafeArea doesn't
pad twice. `scrollSidebar` (default: `fill`) exists only in Flutter: CSS `overflow-y: auto` never
breaks a flex child, but a `SingleChildScrollView` breaks a `ListView` sidebar, so it can be
turned off. `UiFeatureCard` (web `ui-feature-card`): Flutter has no `href`; the card is one
`UiInteractive` button named "title, action label" with the description as its hint, and the action
is only drawn. The title is a header only on a static card (an interactive card is one button
node). The surface wash is 3% of the tone (6% failed AA for primary text on lightOrange and
lightPurple); textContrastGuideline samples the card's one merged node as a whole, so a dedicated test
checks every drawn text colour against the washed surface in every theme. The action keeps to the
bottom only under a tight height (a stretched row); a loose height (Align, Center) hugs the content.
The web's `UiGoogleAuthorization` (an OAuth access token for extra scopes through Google Identity
Services' token client) has no Flutter twin: a Flutter app asks for scopes with the `google_sign_in`
package's `authorizationClient` (`authorizeScopes`), and there is no widget for the library to add.

**0.38.0 additions.** `UiFeatureCard`: `size: UiSize.sm` is now the compact tile (it counted as md
before; 16 padding, 40 badge with a `t.radiusSm` corner, 20 icon, body-strong title, `fontSizeSm`
description). `surface` is the enum `UiFeatureSurface { standard, tinted }` (web `'default' |
'tinted'`; `default` is a Dart keyword). The web `radius: boolean | 'control'` is two fields here:
`radius` (bool?, on/off as before) and `controlRadius` (bool, `t.radius` instead of `t.radiusLg`),
since Dart has no bool-or-enum union; both sides keep the corners square when `UiConfig.radius` is
off, like a text field. `trailingArrow` + `onPressed` without `actionLabel` names the one button
"title, description" with no hint (the web: `aria-labelledby` title + description, no
`aria-describedby`); on the web `trailingArrow` alone makes the card interactive, in Flutter it still
needs `onPressed`. The arrow sits at the end of the badge row in the vertical layout (the title keeps
its full width on a narrow tile) and at the end of the title row when horizontal or without an icon.
`descriptionLines` is `maxLines` + `TextOverflow.ellipsis` (web `line-clamp`). Without an action row
the card no longer wraps its content in a `LayoutBuilder` (it only decides whether the action keeps
to the bottom), so tiles can be made equal height with `IntrinsicHeight`; the look is unchanged.
Tinted colours: the fill is `lerp(lerp(surface, text, .04), tone, .08)` (neutral `lerp(surface, text,
.05)`), muted and primary words are `lerp(x, text, .25)`, the primary badge tint is 18%; the web uses
the same numbers through `color-mix` (premultiplied alpha, so translucent text-muted differs by a
hair; both suites check AA in every theme).

**0.36.0 additions.** `UiGoogleSignInButton` (web `ui-google-button`) draws Google's sign-in
button to https://developers.google.com/identity/branding-guidelines: the colours are Google's
(`UiGoogleBrand`), the one file `style_contract_test` lets use literal colours; 40 high, 12 before
the G, 10 between G and text, 12 after (measured from the outer edge, so the 1px stroke comes out of
the padding), 4px corners or a pill. The G is Google's four-path mark from the guideline's sample
SVG, path data kept verbatim and drawn by a tiny parser (no flutter_svg dependency). The newer asset
bundle draws the G with a Figma conic-gradient `foreignObject`, which only a browser can render, so
the classic flat four-colour G is used in both libraries. The guideline now names Google Sans
Medium 14/20; the library doesn't bundle Google's font, so Flutter draws the bundled Roboto Medium
(then the app font for scripts Roboto lacks), and the web asks for Google Sans, then Roboto, then the
library font. `auto` follows `UiThemeData.brightness`. The library does not depend on
`google_sign_in`: the app wires `onPressed` to it. The web's `ui-google-sign-in` (a wrapper around
Google Identity Services' own button) has no Flutter twin: native sign-in comes from the plugin.

**0.39.1 fixes.** UiBottomSheet's `PopScope` used `canPop: !isOpen`, and a sheet with no 0 snap is
always open, so it swallowed every Back and the page could never be left (found by the Dhirumi
app). Back now only waits while there is something to undo: for a `persistent` sheet (smallest snap
above 0) that is being above its smallest snap, where Back collapses it there (`close()` goes to
the smallest snap and keeps focus); at the smallest snap `canPop` is true. Escape follows the same
rule and is left unhandled at the smallest snap, so it reaches the page. The web has no Back to
trap (the sheet never touches `history`); its Escape does the same as here.
`maxWidth` wraps the DraggableScrollableSheet in `Align(bottomCenter)` + `ConstrainedBox`, inside
the full-screen LayoutBuilder, so `room` (and the reported cover) is unchanged, the backdrop stays a
full-screen sibling, and the sides beside a capped sheet hit-test to the page (Align only tests its
child). The web gives `.sheet` `max-width` and `margin-inline: auto` (fixed with left/right 0, so
the auto margins split the rest); both are symmetric, so RTL needs nothing. Measured in Chromium at
1280 and 390 px, LTR and RTL: 560 wide at left 360, full width at 390.

**0.44.2. Glass sheet footer, early fits, one-row textarea, toast font.** Found by the Dhirumi apps. The glass
sheet footer is frosted on both sides (web: `--ui-glass-sheet-bg` and `--ui-glass-sheet-filter` on `.ft`, solid
under the same no-backdrop-filter / reduced-transparency rules as the sheet; Flutter: `uiGlassSheetTint` /
`uiGlassSheetFilter` at `UiGlassStrength.frosted`). A fit asked before the map exists is stored and applied on
ready with `animate: false` (web: when Leaflet has loaded; Flutter: `onMapReady`). The one-row textarea is
Flutter only: the web's target rule (`audit:ui`, WCAG 2.5.8, 24px) passes at 41px and the web has no 48dp
layout margin, so nothing changed there. Flutter worked its touch margin out from font size x 1.5 x
`scale(1)`; non-linear scaling, a `textStyle` height and line rounding made that too tall (as low as 40dp), so
`uiFieldLineHeight` now measures the line with the editor's forced strut and the text scaler. Toast font:
Flutter `UiToastHost.textStyle` (merged with `uiMergeFieldStyle`, drawn with `inherit: false` so an app family
isn't package-prefixed, the action label too); web `--ui-toast-font` on `ui-toast-host`, as `--ui-field-font`
on the fields. Map markers (web only): `.ui-map .ui-map-marker { position: relative }` (0.35.1, for the hit
area's `::before`) beat Leaflet's `.leaflet-marker-icon { position: absolute }`, so icons stacked in flow and
each was ~16px lower than the last; now `absolute`, lifted 12px (half the 24px box) so the dot's centre is on
the point, hit area recentred. flutter_map positions each `Marker` independently (centred), so Flutter only
gained a test.

**0.46.0. RTL completeness and built-in Dhivehi.** Decisions: (1) Direction comes from `Directionality`;
`UiApp.textDirection` (null = from the locale's language) wraps the whole app including `builder`, because
WidgetsApp's default localizations are always LTR and `dv` has no Flutter localizations. (2) `start`/`end` were
added to `UiDrawerSide` and `UiToastPosition` with `resolve(TextDirection)`; widgets resolve once and keep their
physical code. Adding enum values breaks exhaustive `switch`es in apps (the library's own and two tests were
updated). (3) `UiStrings` moved to `theme/strings.dart`, generated from the shared key table (same keys as the
web `UiStrings`, plus Flutter-only `today`, `notSet`, `chooseMonth`, `chooseYear`, `opensCalendar`,
`opensTimePicker`, `hours/minutes/seconds`, text-selection menu words, `fieldRequired`/`thisField`,
`sheetSmaller/Larger`, `navigationOpen`, `currentStep`, `upcoming`, `openImage`, `image`, `meter`, `chosenFiles`,
`slider`; reported to the web side). It has `==`, `copyWith` and `toMap`. (4) Words switch at once: the theme
tween's `transform` and `lerp` take the new strings at t = 0 (Tween.transform returns `begin` untouched at 0).
(5) `intl` has no Dhivehi, so names come from `UiStrings.months`/`weekdays` and formats from `dateFormat`
patterns; the first weekday comes from `UiStrings.firstDayOfWeek` or `intl` date symbols. (6) Typography names
bundled families with their `packages/zouriel_ui/` prefix instead of `package:`, so `UiConfig.fontFamilyFallback`
isn't prefixed too. (7) OTP cells are forced LTR (codes read left to right), as the web group's `dir="ltr"`; so is the code in
`UiCodeBlock` and `UiCodeViewer` (with its line numbers), as the web `pre dir="ltr"`.
(8) Not moved to UiStrings: form builder, workflow and canvas/sequencer editor text, window chrome
(Restore/Minimize/Maximize), file-viewer extras (Copy/Copied, Mute, Full screen, Media viewer, Current folder),
tree-table Expand/Collapse, anchor picker point names, side nav and choice grid default names.

**0.45.2. Queued Leaflet events after teardown.** The web map can unmount while Leaflet is finishing an
animated pan; its queued `moveend` used to read the cleared map field and throw. The listener now checks
that its map instance is still current, and `visibleCenter()` safely returns null after teardown. Flutter's
`UiMap` already scopes `MapController` to `UiMapState` and disposes the controller with the state, so no
Flutter runtime change or new test is needed. The Flutter version and showcase note stay aligned at 0.45.2.

**0.45.0. Compact density.** The web drives it with CSS: a `[data-density="compact"]` token block (and the
same block under `@media (max-width: 599.98px)` for `auto`), `zoom: var(--ui-density-scale)` on every
`hugeicons-icon` and on the switch track, checkbox box and radio dot, and `calc(Npx * var(--ui-font-scale))`
for text components size in px (13px and up; smaller text stays, the floor is 11px). Flutter mirrors it: the
generator reads the compact block into `uiCompactDensityTokens` / `UiTokens.withCompactDensity()`,
`UiThemeData(compact:)` applies it (keeping `baseTokens` so `UiDensityScope` can switch a subtree), `UiApp`
resolves `auto` from the view's width with a metrics observer (it sits above WidgetsApp's MediaQuery),
`UiIcon` multiplies every size by `densityScale` (so `IconTheme` sizes keep their comfortable values, like the
web zoom), and literal `fontSize: N` (13 and up) became `N * fontScale`. The Google sign-in button keeps
Google's 14px in both (branding rules). Compact sm is 24, not 22: with a mouse there is no 44px touch area, so
sm stops at WCAG 2.5.8's 24px minimum. Web only: on iOS (`@supports (-webkit-touch-callout: none)`) compact
keeps typed text at 16px, because Safari zooms into any focused field under 16px; Flutter has no such zoom.
The web segmented options and password toggle also gained hit areas that stay 24px when compact paints them
20px; Flutter's `UiInteractive` already gives 48dp.

**0.44.3. Sheet body ends at the footer (web only).** On the web a nested `backdrop-filter` inside the glass
sheet barely blurs in light themes, so text scrolling under the footer stayed readable; the web body's scroll box
now ends at the footer's top. Flutter's footer BackdropFilter blurs fully, so the Flutter sheet keeps scrolling
under its frosted footer (re-laying out the body on every drag frame would cost more than it buys).

**0.44.1. Dialogs from above the navigator (Flutter only).** `UiApp.builder` content sits above the
Navigator, so `Navigator.of` failed for a held FAB's tap confirm there. `UiApp` now keeps a navigator key (the
app's or its own) in `UiNavigatorScope`, and `uiNavigatorOf` falls back to it; confirm, modal, drawer and the
command palette use it. The web overlays are not tied to a navigator, so Angular only bumps its version.

**0.44.0. Map search area, swipe screens, top and SOS FAB.** For Dhirumi: the map is a second
screen to the right of the chat, the person widens or narrows the search area on it, the nurse app
sets her job radius the same way, and SOS floats at the top.

- Area. Both libraries draw the circle themselves rather than with the engine's metre circle
  (Leaflet `L.circle`, flutter_map `CircleLayer(useRadiusInMeter)`): the radius in px is
  `radiusMeters / uiMapMetersPerPx(center.lat, zoom)` (the accuracy halo's formula), and the handle
  sits exactly `r` px east of the centre (west in RTL), so the knob is always on the drawn edge and a
  drag's px distance from the centre maps straight back to metres. Drag radii and key steps are
  rounded (`uiMapNiceRadius`: 10 m under 1 km, 100 m under 10 km, else 1 km) so apps never get
  20437.2. Flutter's handle uses an eager recognizer (accepted on pointer down) so flutter_map's
  scale recognizer never pans under it; Leaflet's dragging is disabled for the duration of the
  handle drag. `onAreaChanged` fires on every release (unchanged included); the chosen radius stays
  drawn until the app passes a new area (as the web keeps it locally until the input changes).
- Swipe screens. Flutter: one `HorizontalDragGestureRecognizer` subclass around all screens that
  gives up once the pointer has moved more vertically than sideways (half the touch slop) and only
  starts past the slop even when it wins the arena by default (`onlyAcceptDragOnThreshold`). An
  `edgeSwipeOnly` screen takes no drags from that recognizer; an opaque 24px strip over its leading
  edge carries its own back-only one, so the map under the rest never competes. Hidden screens are
  `Offstage` (state kept, not painted, hit or read), `ExcludeFocus`, `TickerMode` off; the shape of
  each screen's wrapper never changes. The web uses `touch-action: pan-y` and pointer events (mouse
  drags swipe too), `inert` + `aria-hidden` on hidden screens and a polite live region.
- FAB. New placements top-start/center/end and bottom-start/center/end (the web keeps its physical
  values), `tone: danger` (danger fill, a 3px raised-surface ring and a 6px danger halo at 30%,
  outside the button so its size doesn't change) and an extended `text` pill. The web's
  `aboveOverlays` lifts it over sheets and drawers by z-index; Flutter has no z-index, so the docs
  say where to put `UiFabHost` (around the page, or in `UiApp.builder` to sit above routes).
- Visit UX additions (L1-L4). FAB `hold`: `UiHoldButton`'s gesture, keys and dialog moved into
  `UiHoldActivator`, which both use (the hold button's tests and golden are unchanged). `topOffset`
  is on `UiFabHost` here (the web puts it on `ui-fab`, which positions itself). Button badges reuse
  the bottom nav's badge look; the badge's own text is excluded from semantics and the name is
  "label, badgeLabel". The sheet footer is laid over the panel inside the DraggableScrollableSheet's
  builder, whose box is the live visible height, so it stays pinned while dragging; the footer's and
  header's heights are measured after layout and an open snap shorter than both is raised (indices
  are unchanged, so `snap` / `onSnapChanged` mean the same). The body (a `child`) gets the footer's
  height as bottom padding; a `builder` reads `UiBottomSheetState.footerHeight`. `insetEnd` widens
  the panel's end gutter (physical right in LTR, left in RTL).
- Web differences: hold on the web is the `UiFabHold` directive (`ui-fab[hold]`, from
  `@zouriel/ui/hold-button`, emitting `(confirmed)`), because the button entry can't import the
  dialog entry; the template API matches `UiFab.hold` here. The web also exports `uiSwipeTarget`
  and a fixed 8px swipe slop (`UI_SWIPE_SLOP`); Flutter uses the platform's touch slop from
  MediaQuery gesture settings.

**0.43.1. Map background tap.** The web `(mapTap)` and Flutter `onMapTap` report a background tap as
`UiLatLng`. Leaflet's map `click` already excludes a drag and foreground Marker clicks; flutter_map's
`MapOptions.onTap` excludes a drag and double-tap, while marker/control tap recognizers win its
gesture arena. Fixed pins, non-selectable markers and attribution explicitly consume their own tap without
gaining a semantic action. The user dot does not: its accuracy halo can be 240 px across, and a tap
there must still place the pin, so it counts as background. Preview's whole-map button stays above the engine.
In pin mode the existing pin update runs first and the background event also fires; keyboard Enter
moves the pin but is not a tap. The selected-marker and full results demos clear their card from it.

**0.43.0. Map preview, selected marker, label modes.** For Dhirumi's chat result cards (a Cards |
Map switch whose Map tab is a small still map that opens the full one).

- Preview. The web lays a native `<button class="ui-map-preview">` over the whole map (z-index above
  Leaflet's panes and controls), turns every Leaflet handler off, removes the zoom control and makes
  the canvas `inert` + `aria-hidden`; the button never cancels `wheel` and has `touch-action:
  manipulation`, so the page scrolls. Enter and Space are the button's own click (no key handler of
  ours, which would press twice). Flutter lays `UiMapPreviewButton` (a `UiInteractive`, so Enter /
  Space / focus / cursor come with it) over the map in the Stack; being on top and opaque to hits it
  takes every pointer before flutter_map could, but its only recognizers are tap (and press), so a
  drag past the touch slop goes to the scrollable around it and pointer signals (the wheel) are not
  claimed. The map below is `ExcludeFocus` + `ExcludeSemantics` and gets `InteractiveFlag.none` with
  `KeyboardOptions.disabled()`. An `IgnorePointer` around the map was tried and removed: with the
  button on top it changed nothing a test could see. Press look: an 8% text-colour wash on both (not
  the controls' 0.96 scale, which on a whole map reads as a jolt). Focus ring: the web's
  `--ui-focus-ring` written as two inset shadows (2px page colour, then 2px border-focus; `inset
  var(--ui-focus-ring)` only insets the first); Flutter draws the same as two borders.
- Selected marker. 22px dot (16 x 1.35, rounded), `locationRing` (#fff in every theme) ring, a 6px
  spread at 30% of the tone. Web: `data-selected` + `zIndexOffset` 500, `aria-pressed` true/false (none
  without a selection), updated in place by an effect, no marker rebuild. Flutter: the selected
  marker is moved to the end of the MarkerLayer list (painted last), `Semantics(selected:)` true/false
  (null without a selection).
- Label modes: `all | selected | none`; 'none' hides the selected marker's label too (the brief's
  "label always shown" is read as "in all and selected"). Hidden labels: web `data-label-hidden` +
  an explicit `aria-label` on every marker; Flutter drops the chip but keeps the Semantics label.

**0.42.2. Chat bubble in any parent.** The Dhirumi nurse web app put `ui-chat-bubble` in a column
with `align-items: flex-start/flex-end`; the host shrank to its text, the bubble's `max-width: 80%`
resolved against that shrunk host, and `overflow-wrap: anywhere` let min-content collapse to a
letter, so "okay" broke as "ok/ay" (48 px, 2 lines in Chromium at 390). Web: the host now takes the
row whatever the parent aligns (`align-self` and `justify-self: stretch`, `width: 100%`,
`min-width: 0` so a grid or row can still shrink it, `box-sizing: border-box`), and the bubble uses
`overflow-wrap: break-word` (a word breaks only where it would overflow; min-content stays whole
words). `npm run audit:chat-wrap` checks it in Chromium at 390: flex columns aligned
start/end/center/stretch, a row, a grid with `justify-items: start`, LTR and RTL, yours and theirs;
a short word on one line at its own side, a 200-character URL inside 80%. Flutter never had the
column problem (the bubble's LayoutBuilder + Align took the column's max width whatever its
`crossAxisAlignment`), but two parents broke it: an `IntrinsicWidth` threw (LayoutBuilder can't
answer intrinsic sizes), and in a Row (unbounded width) the 80% cap became infinite and a long URL
overflowed the Row by ~1300 px. The LayoutBuilder is now `_RenderBubbleRow`: the row's full width
when bounded, the bubble at most 80% of it at its inline side, intrinsic widths the bubble's over
0.8 (plus 0.01 so 0.8 x width can't round under the text's width), so an IntrinsicWidth keeps short
text on one line; with unbounded width it caps at 80% of `MediaQuery` width and sizes to the
bubble. `chat_bubble_fit_test.dart` covers each Column alignment in LTR and RTL, IntrinsicWidth
and Row at 390. There is no web equivalent of an inline-block or float parent guard: a parent that
shrink-wraps by its own rules still sizes from the text (CSS can't size a host to its text / 0.8).

**0.42.1.** From the Dhirumi nurse app, which carries workarounds for all three until this ships.

- fitPoints vs changing insets. Flutter: the route made the sheet's peek taller just as the fit
  started; `didUpdateWidget` then ran the inset pan, which stored the map's centre in px at the zoom
  of that moment while the fit's own animation went on changing the zoom, and `_onPan` unprojected
  those px at the new zoom (a short route at zoom 17 ended ~900 px off; the tests saw far worse). Now
  the last fit is held (`_fit`) and owns the camera: an inset change (or a direction change) works it
  out again for the new insets; a fit in flight is retargeted (`_flyTo` / `_flyZoomTo` swapped, its
  progress kept, so a sheet growing frame by frame doesn't restart it), one that has landed moves
  again, animated unless reduced motion. It is let go by any camera move that isn't the map's own
  (`MapEventWithMove` and the start events from a gesture, not `nonRotatedSizeChange`), `flyTo`, the
  zoom buttons and a new `center` / `zoom`. The inset pan itself no longer works in px: it keeps a
  point (`_panPoint`) and eases the shift, `move(point, zoom, offset: shift)`, so a zoom change while
  it runs can't send it to another scale; a pan already running is continued from where it got to.
  Web: the same hold (`fit`), with `applyInsets` calling `applyFit` instead of `panBy`. Leaflet's
  `_tryAnimatedZoom` silently drops a `setView` made during a zoom animation (`_animatingZoom`), so a
  refit asked for then is queued (`refitPending`) and run on `zoomend` / `moveend`. Released by
  `dragstart`, `boxzoomend`, `wheel`, `dblclick`, a two-finger `touchstart`, the arrow and +/- keys on
  the map, the zoom buttons, `flyTo` and a moving `center` / `zoom`. jsdom has no CSS transitions, so
  the web suite holds `_animatingZoom` by hand to test the queue.
- Controls. `controls` / `UiMapControl` in both: Flutter `{id, icon, semanticLabel, onPressed,
  tooltip}` (onPressed null is disabled, like every Flutter control here), web `{ id, icon, label,
  tooltip?, disabled? }` with `(controlPress)` (the library's outputs pattern; per-item callbacks in a
  bound array would be odd in Angular templates). Drawn as a column above the locate button: Flutter
  an `AnimatedPositionedDirectional` pulled out by the touch slop like the locate button, its bottom
  one button plus space2 higher when `locateControl` is on, `spacing: space2 - 2 * slop` so the
  visible gap stays 8 on touch; web `.ui-map-controls` with the same `bottom` calc plus
  `var(--ui-size-lg | --ui-size-touch) + space2` under `[data-locate]`, `inset-inline-end` (RTL-safe)
  and `gap: space2`. `UiMapControlButton` / `.ui-map-control` reuse the locate surface
  (`uiMapControlDecoration`; the same CSS values, compared by the spec). Their tooltips face into the
  map (left; right in RTL; the locate button's stays as it was). No built-in `fitControl`: the handler
  is one `fitPoints` call, and only the app knows which points and words ("Show both", "Show the
  route") it means, so a generic control is the smaller API.
- Labels near the edge. One rule in both, `uiMapLabelSide(x, labelWidth, mapWidth, rtl)`: the inline
  end (right; left in RTL, so RTL now starts on the left, mirrored) if `x + 12 + w <= width - 8` (or
  `x - 12 - w >= 8` on the left), else the other side if it fits, else the roomier side. Flutter
  measures the chip with a `TextPainter` (the label style, two lines, labelMax less the padding and
  border; `TextWidthBasis.parent` gives the same width the `Text` lays out to) and reads the marker's
  screen x from `MapCamera.of(context)`, so the chip rebuilds and re-picks as the map moves. Its
  `Marker` box is now centred on the point, `2 * (labelMax + 24)` wide, with the dot's 48dp target in
  the middle and the label on either side (it was `labelMax + 48` aligned centerRight). Web: the label
  is absolutely positioned beside the dot (`left: calc(100% + 4px)`, or `right:` under
  `[data-side="left"]`), so flipping needs no margin sums; the map sets `data-side` from the label's
  `offsetWidth` on `move`, `zoomend`, `resize` and after drawing markers. The `map_pulse` golden
  changed: its "Aminath Hassan, RN" label used to run off the right edge and now sits left of its dot.

**0.42.0.** Map routes, fit to points and map polish (Dhirumi nurse map: "detailed and easy to
navigate", the route to the patient shown from the moment she accepts).

- Routes. Flutter: a `PolylineLayer` (flutter_map 8.3.2) between the tiles and the pulse, wrapped in
  `IgnorePointer`; each `Polyline` has the tone colour, `borderColor` `mapRouteCasing` and round caps
  and joins. flutter_map paints the border as one stroke `strokeWidth + borderStrokeWidth` wide, so
  `borderStrokeWidth` is casing - line (4 = 2 each side). Widths follow the zoom through
  `MapCamera.of(context)` (`uiMapRouteWidth`: 5 over 9 from zoom 14, 60% at zoom 10 and out). Web:
  two Leaflet polylines per route (casing then line) in their own pane, z-index 420 (above overlays
  400, below the pulse 450, the dot 500 and markers 600), `interactive: false`, the colours from CSS
  (`.ui-map-route-line[data-tone]`, which beats Leaflet's `stroke` attribute) and widths set with
  `setStyle` on `zoomend`. Updates move the same layers (`setLatLngs`) on the web and rebuild the layer
  widget on the same map in Flutter. Names: one per route; the web puts `role="img"` + `aria-label`
  on the line path (the casing is `aria-hidden`), Flutter one image `Semantics` node for the layer
  with the labels joined (flutter_map has no per-line semantics). The web takes `[lat, lng]` tuples as
  well as `{ lat, lng }` (`UiMapPoint`); Flutter takes `UiLatLng`, the library's point type
  everywhere (latlong2's `LatLng` is not part of the public API).
- Route colours: new tokens `--ui-map-route-casing` (surface-raised) and `--ui-map-route-primary /
  -muted / -success / -warning / -danger`, defaulting to the theme's primary, text-muted and status
  colours. Each must hold 3:1 over the casing and over every colour covering more than 0.2% of real
  MapTiler streets-v2 / streets-v2-dark and dataviz / dataviz-dark tiles of Male and Hulhumale (zoom
  15-16) in the theme's brightness; where the theme colour didn't (lightOrange primary 2.91, maldives
  success / danger 2.96 / 2.92, the dark palettes' shared success / danger and translucent muted,
  darkPink / darkPurple primary, Winter Dark muted 2.91) the theme sets its own, the nearest lightness
  of the same hue that passes. The worst ground is streets-v2's water (84caf9) in light themes and
  its roads (365485) and grey (545454) in dark ones.
- fitPoints. One sum in both (`uiMapFitView`): Web Mercator unit coordinates, the bounds' span at zoom
  0 x 256, zoom = floor(log2(min(free width / span x, free height / span y))) clamped to 1..maxZoom
  (a whole zoom: Leaflet snaps to whole zooms anyway, and both stay identical), and the map's own
  centre = the bounds' middle less half the (left - right, top - bottom) difference of the free area
  (the insets, resolved for the direction, plus the padding). A test in each pins the same numbers.
  Flutter animates centre and zoom with one AnimationController (motionSlow, easeStandard; hence
  TickerProviderStateMixin), the web `setView` with `animate`; both jump under reduced motion or
  `animate: false`. Unlike flyTo, fitPoints animates in Flutter too.
- Marker labels: the web drops the marker's `white-space: nowrap` and gives `.ui-map-label`
  `width: max-content; max-width: var(--ui-map-label-max)` with a two-line clamp; the map sets
  `--ui-map-label-max` = min(320, canvas width - 32) from its ResizeObserver. Flutter reads the same
  from a LayoutBuilder around the FlutterMap (not around the whole widget: that hid the map's
  semantics node from `getSemantics(find.byType(UiMap))`) and sizes each `Marker` box to
  labelMax + 48. Both use `radiusLg`, which clamps to a pill on one line.
- Zoom buttons: Flutter used `UiIconButton(variant: outline)`, see-through over the tiles (the washed
  out +/- in the Dhirumi screenshot). New `UiMapZoomButton` with the locate button's decoration
  (`uiMapControlDecoration`: opaque surfaceRaised, border, shadow2), 38px / 44px on touch with the
  48dp padded target, pulled out by the touch slop so the squares stay put and 4px apart. Web: the
  Leaflet buttons go from size-md with shadow-1 to size-lg with shadow-2, as the locate button.
- The "solid darker band" under the floating panel in the Dhirumi screenshot is not in the library:
  those shots come from widget tests, where `debugDisableShadows` is true by default and every
  shadow is drawn as a hard, unblurred shape (UiOutsetShadow draws only the part outside the glass,
  so a 16px-offset hard band shows under it). Rendered with `debugDisableShadows = false` (as
  `expectThemedGolden` does) the shadow is the soft one devices draw; screenshot harnesses should set
  it false too.

**0.41.3.** From the owner's phone test of Dhirumi: "filling out fields in the bottom drawer in the
mobile app is weird cause the keyboard hides the drawer and doesnt push it up. the over the map drawer
isnt transparent in neither versions", and the nurse app's stale map insets.

- Keyboard. Root cause: `UiDrawer(side: bottom)` (showUiDrawer: the nurse app's cancel reason,
  coming form, work summary, SOS, profile forms; the customer app's medicine search) read
  `viewInsets` only for left/right drawers, so a bottom drawer stayed at the screen edge and the
  keyboard covered its fields and footer (reproduced on an API 35 emulator with Gboard, and in a
  widget test). Now it is padded by `viewInsets.bottom` and its height is 80% of the space left
  (max 320). `UiBottomSheet` in Find a nurse was checked on the same emulator with the real app (fake
  backend): it already rose onto the keyboard (the app's PageFrame lifts the body and removes the
  insets, the sheet rests on its offset footer). Web twin: `ui-drawer side="bottom"` was
  `position: fixed; bottom: 0`, behind the keyboard wherever the browser shrinks only the visual
  viewport (Chrome's default `interactive-widget=resizes-visual`, iOS Safari); it now reads the visual
  viewport as `ui-bottom-sheet` does (`--ui-drawer-keyboard`, `--ui-drawer-room`, `.on-keyboard`).
- Clear glass. 0.41.2's glass holds AA over pure white and black, which on a light theme leaves the
  backdrop range 0.87-1 under a 60% tint: over real dataviz tiles nothing showed through. New
  `glassStrength` (`UiGlassStrength.clear` default, `.frosted` = 0.41.2) and tokens
  `--ui-glass-clear-tint` 0.12, `--ui-glass-clear-blur` 3px, `--ui-glass-clear-saturate` 1.8 (root),
  per theme `--ui-glass-clear-floor` / `-ceiling`, derived `--ui-glass-clear-bg` and
  `--ui-glass-clear-filter` (the same contrast+brightness squeeze, then `saturate()`). Flutter builds
  saturate after the squeeze in one colour matrix (its rows sum to 1, so the grey offset passes).
  The ranges were solved per theme as the widest that keeps text, muted, primary, success, danger
  (4.5:1) and warning, icon (3:1) over every colour covering more than 0.2% of real dataviz /
  dataviz-dark Male tiles at zoom 15-16 (light: water d1e6e9, buildings dedede ...; dark up to
  323232). The binding colours are the status colours and maldives' Lagoon icon, tuned to just pass
  on a white surface, so light themes keep 43-57% of the map's contrast and dark ones 44-75% (frosted:
  5-17%). A strong blur would erase roads, so clear uses a light one; the contrast comes from the
  squeeze, not the tint. Light maps stay pale under any recipe that keeps those colours AA.
- Sheet cover. `UiBottomSheet` reported its cover only on snap changes (and once on first layout):
  new snaps at the same index (the nurse app's content-sized peek growing for SOS), the keyboard
  and the room changing left `onCoverChanged` stale. It now reports after every layout when the
  resting height or cover changed, once per frame and per change. The web `coverChange` was already a
  signal effect over the same inputs; a spec now covers it.

**0.41.2.** Glass bottom sheet and floating panel (Dhirumi Find a nurse, a full-screen map with the
form in a bottom sheet: "use a transparent drawer on the map"). Both libraries: `glass` on
`UiBottomSheet` / `ui-bottom-sheet` (new, default false, not driven by `UiConfig.glass`) and the
existing `glass` on `UiFloatingPanel` / `ui-floating-panel` now share one recipe, new tokens in
tokens.css: `--ui-glass-sheet-tint` (0.6) and `--ui-glass-sheet-blur` (20px) on `:root`, and per theme
`--ui-glass-sheet-floor` / `--ui-glass-sheet-ceiling`, the range every backdrop channel is mapped into
before the tint (light themes floor 0.70-0.95, ceiling 1; dark themes floor 0, ceiling 0.11-0.43).
`--ui-glass-sheet-bg` is `color-mix(surface, tint)`; `--ui-glass-sheet-filter` is `blur()
contrast((c - f) / (c + f)) brightness(c + f)`, which maps v to f + v (c - f) per channel (checked in
Chromium by pixel readback: sRGB, as modelled). Flutter builds the same with
`ImageFilter.compose(ColorFilter.matrix(diag c - f, offset f * 255), blur(sigma = blur / 2))`
(`glass_sheet.dart`); `gen_tokens.mjs` reads tint/floor/ceiling as numbers and skips the filter
string. The floor and ceiling were chosen so text, text-muted, primary, success, danger (4.5:1) and
warning, icon (3:1) hold over pure white and pure black with ~0.03 to spare; with these themes'
primary and status colours only just AA on the solid surface, the colourful light palettes end up
with a narrow range (lightPurple 0.95-1), so the map shows through faintly there. The floating panel's
glass used `--ui-glass-panel-bg` (web) and `glassBg` (Flutter), which differed and didn't hold AA over
black; both now use the sheet recipe, with the surface tint. Fallbacks: web, solid surface without
`backdrop-filter` (`@supports not`) and under `prefers-reduced-transparency: reduce` or
`prefers-contrast: more`; Flutter has no reduce-transparency flag, so `MediaQuery.highContrast` (iOS
Increase Contrast) gives the solid surface. Flutter-only: a `BoxShadow` paints under its whole box,
which darkened the map under the glass, so glass surfaces draw `shadow3` with `UiOutsetShadow`
(clipped to outside the rounded box, like CSS `box-shadow`); the pixel test caught it.

**0.41.1.** Image and PDF viewers can fill the page (Dhirumi nurse app: the payment slip "is opening
in a weird window": a fixed-height framed box with its zoom bar under it and the page empty below).
Both libraries: `fill` on `UiImageViewer` / `ui-image-viewer` and `UiPdfViewer` / `ui-pdf-viewer`.
The viewer takes the parent's height (web: `height: 100%` with the cap and spacer removed; Flutter:
`box.maxHeight`, `maxHeight` when unbounded), has no frame (PDF: radius 0, `bg` instead of
`surface`), and the controls are a pill on `glassPanelBg` with `glassBlur`/`shadow2`, centred
`space3` above the bottom plus the safe area (web `env(safe-area-inset-bottom)`, Flutter
`MediaQuery.paddingOf(context).bottom`; `viewer_overlay.dart`, not exported). The picture is fitted
into the whole stage: web `img`/`video` are `position: absolute; inset: 0; width/height: 100%;
object-fit: contain` and the pan clamp uses the contained size from `naturalWidth/Height`
(`fitContain`, the twin of `uiFitContain`); Flutter wraps the `Image` in `SizedBox.expand` (it was
`Center`, so a small picture stayed small while the clamp assumed it was fitted). That fitting applies
without `fill` too. PDF fill: each page is fitted whole into the area above the overlay (web: the
scroller's content box, whose bottom padding reserves the bar; Flutter: `overlayReserve`), zoom is
relative to that fit (100% = fitted, 40-400%), and a Fit button (`Fit page`) resets it. Web-only
changes with no Flutter counterpart needed: without `fill` the web viewers used to collapse to a
200 px stage in a parent with no definite height (`height: 100%` of auto); a stage `::before` spacer
(`--ui-image-viewer-min-height` / `--ui-pdf-viewer-min-height`, default 60svh) now gives them that
height while a parent with a height still wins (Flutter already took 70% of the screen when
unbounded and the full height in an `Expanded`). The web PDF viewer gains Ctrl+wheel and two-finger
pinch zoom (live CSS scale, one re-render on release), which Flutter had through `InteractiveViewer`,
and one render at a time (a newer render cancels the previous); the web image viewer takes `+ = - 0`
like Flutter's, and is focusable (role group, named by `alt`) in fill.

**0.41.0.** Fixed header and footer in drawers and sidebars (Dhirumi: "My nurse visits" and the
profile must stay in the viewport, not sit at the end of the chats list). Web: `ui-drawer` gets
`[drawer-header]` / `[drawer-footer]` slots (`.dh` / `.df` around `.bd`, kebab names like
`[modal-footer]`), `ui-sidebar-layout` gets `[sidebar-header]` / `[sidebar-footer]`; the aside is now a
flex column whose `.sb-bd` scrolls instead of the aside itself, with the edge padding carried in
`--sb-pt/-pb/-ps` so the safe area lands on the first and last part (`:has()` drops the body's
bottom inset when a footer follows). Empty slots are `display: none`, so nothing changes without them.
Flutter: `UiDrawer.header` / `footer` / `bodyBuilder` (`showUiDrawer(headerBuilder:, footerBuilder:,
bodyBuilder:)`, `UiDrawerPeek(headerBuilder:, footerBuilder:)`) and `UiSidebarLayout.sidebarHeader` /
`sidebarFooter`, both through an internal `UiPinnedEdges` column (not exported). Each part keeps a
1px border (no height change) coloured only while the body has content hidden on that side; both
sides measure it with the scroll fade (`uiScrollFade` exportAs + size 0 on the web,
`UiScrollFade.onEdgesChanged` + size 0 here), and the hairline's first appearance on open is drawn at
once in Flutter (later changes fade over motionFast, like the web's border-color transition).
Differences that have no counterpart: `bodyBuilder(context, ScrollController)` exists only in Flutter,
because a `ListView` must be the scroll view itself (on the web the body element scrolls and a paging
list inside it just works, e.g. with `uiIntersect`); the Flutter left/right drawer also keeps its
footer above the keyboard (`max(padding.bottom, viewInsets.bottom)`; the browser resizes the visual
viewport itself). Focus order: DOM order on the web; in Flutter each part is a `FocusTraversalGroup`
with an `OrdinalSortKey` semantics container, because reading order alone tabbed to the footer
before rows scrolled out of sight below it (a test fails without the groups).

**0.40.2.** Feature-card colours and the theme: on the web the card read the theme tokens with
`getComputedStyle` once, when `colors` was set, and again only on `data-theme` mutations; a
critical-CSS build (Angular's default) inlines only the `:root` (Winter Dark) tokens and loads the
stylesheet with the `[data-theme]` rules afterwards, so a card created in between kept the dark pair.
The web now shares `uiWatchTheme` (re-read after render and on data-theme / class / style changes up
the tree, stylesheets added or loaded, `prefers-color-scheme` changes) for the feature card, the
Google button's auto theme and the map's dark tiles. Flutter needs no change: the card resolves its
colours in `build` from `context.uiTheme` (dark = the theme surface's luminance < 0.2), which is the
`UiApp` theme from the first frame and never `MediaQuery.platformBrightness`; two tests pin it
(device dark + `UiApp(theme: maldives)`; device dark + a `UiThemeController` switched to
maldivesDark and back), and fail when the card is made to use the platform brightness.

**0.40.1.** Touch targets: `UiMapLocateButton` no longer opts out of `UiInteractive`'s touch
padding, so on touch platforms its 44dp circle gets a 48dp `UiTouchTarget` around it; the map pulls
its `AnimatedPositionedDirectional` out by `UiMapLocateButton.touchSlop` (2dp) so the circle stays at
`space8` / `space3` from the visible corner. The zoom buttons were already padded (UiIconButton). The
web gives `.ui-map-locate` and the zoom links a centred 48px `::before` under `(pointer: coarse)`
(and its coarse zoom rule now matches the base rule's `:first-child` / `:last-child` specificity,
which had kept the zoom links at 30px on touch). Attribution: the `Text` has
`textDirection: TextDirection.ltr` while its `AnimatedPositioned` corner still flips with
`Directionality`; the web sets `dir="ltr"` on Leaflet's attribution container and
`direction: ltr; unicode-bidi: isolate` in map.css (the canvas was already `direction: ltr`, so the
web was mostly unaffected; the attribute guards against app CSS).

**0.40.0 additions.** Dark tiles: one `TileLayer` whose `urlTemplate` is `uiMapTileUrl(tileUrl,
tileUrlDark, dark)` (dark = the theme's brightness), so a theme change swaps the URL on the same
layer state; the web does the same with Leaflet `setUrl` on the same layer (a new layer only when
size, offset, attribution or referrer change) and leaves the dimming filter off with
`data-dark-tiles`. `{r}`: flutter_map's `retinaMode` (server mode, `@2x`) is on when the URL has
`{r}` and the device pixel ratio is above 1; Leaflet fills `{r}` from `Browser.retina` itself. The
web's `tileSize` maps to flutter_map's `tileDimension`. The tile provider is shared by both URLs, so
`tileHeaders` (a Referer for a key restricted to a web origin) go with the dark tiles too; the web
sends the browser's own Referer under `tileReferrerPolicy`. The locate button is `UiMapLocateButton`
(UiInteractive, a circle, 38px or `sizeTouch` 44px on touch), positioned with
AnimatedPositionedDirectional at `viewInsets.bottom + space8` / `viewInsets.end + space3`; the web
is a `<button>` over the canvas at `calc(var(--ui-map-inset-bottom) + var(--ui-space-8))` and
`inset-inline-end`. "Location is off" is a `UiTooltip` (its message merges into the button's
semantics node as its tooltip) and `aria-description` plus `uiTooltip` on the web. The dot is a
MarkerLayer between the pulse and the markers whose halo reads `MapCamera.of(context).zoom`; on the
web a divIcon in its own pane (z-index 500, between the pulse's 450 and the markers' 600) redrawn
on `zoomend`. The halo sum `uiMapAccuracyPx` is the same in both (Web Mercator, 256 px at zoom 0,
rounded, clamped 28..240). The colours are new tokens (`--ui-color-location` #1a73e8 and
`--ui-color-location-ring` #fff, the same in every theme), so the generated tokens carry them.
`flyTo` moves without animation in Flutter (as `center` does) and animates on the web unless
reduced motion.

Bottom sheet: the web bug (Dhirumi, a phone browser with `interactive-widget=resizes-content`) was an
app whose snaps were sized to the window: the keyboard shrank it, the app's snaps lost a step, the
sheet's index then pointed past the end, read as height 0 (closed), went `inert`, the field lost
focus, the keyboard closed, the snaps came back and the sheet re-opened: over and over. Both
libraries now read the index clamped to the snaps, and when `snaps` changes while `snap` doesn't,
move to the snap nearest the old resting fraction and report it (Flutter through `onSnapChanged`
after the frame; Flutter used to throw a RangeError there). `expandOnFocus` raises once per field:
focus coming back to the field that raised it within 600 ms of leaving it is ignored (a Timer in
Flutter, the focus event's timeStamp on the web).

**0.39.0 additions.** The map pulse is a `MarkerLayer` between the tiles and the markers holding
`UiMapPulseRings` (one AnimationController repeating 2.4s and a CustomPainter; ring i starts i/3 of
a loop late, as the web's animation-delay, using the controller's elapsed time). It exists only
while `active`, so turning it off or leaving the page disposes its controller; with
`context.uiAnimate` false (reduced motion, or the library's animations off) the controller never
starts and the painter draws one 72px halo. The web draws the same rings with CSS animations on a
Leaflet divIcon in its own pane (z-index 450, between overlays and markers, pointer-events none).
`viewInsets` uses flutter_map's `move(..., offset:)` for centring and a pixel-space tween (one
AnimationController, `motionSlow`, `easeStandard`) for the re-centre when the insets change; the
web uses Leaflet `panBy` over 0.32s. Leaflet pans by whole pixels, so the web's reported centre is
within a pixel of the requested one. Zoom buttons zoom around the middle of the visible part
(flutter_map `move` with the offset; Leaflet's zoom control is given `setZoomAround` on the web).
The web's pin anchor was 7px below its drawn point (a 22px square turned 45deg ends 27px down, not
34); fixed there so the pin's point sits in the pulse's middle. `UiMapBlankTiles` decoded to
rgba(0, 0, 255, 0.5) and tinted every blank map; it is a transparent grey-alpha pixel now.
`UiFloatingPanel.onCoverChanged` measures the panel with a RenderProxyBox after layout (the entry
slide is a paint transform, so it never counts); the web measures offsetTop/offsetHeight with a
ResizeObserver for the same reason.

The feature card's `colors` are resolved by one function in each library (`uiResolveFeatureColors`,
`feature_colors.dart` / `feature-colors.ts`) with whole-channel rounding at every step, so both
pick identical colours (a test compares the Flutter result with values measured in Chrome).
Dark is decided by the theme surface's luminance (< 0.2) in both. Flutter takes `Color`s
(`UiFeatureCardColors`) with `tryParse` for the web's strings; the web warns in dev mode on an
invalid string, Flutter's `tryParse` prints in debug builds and returns null. `enter` is a
private `_FeatureEnter` wrapper whose Opacity/Transform shape never changes (so the card's hover and
focus state survive the end of the entrance); it starts in the first `didChangeDependencies` only,
so a rebuild or theme change never replays it. The web uses a CSS animation with `backwards` fill,
so the hover lift still works after it.

**0.35.1 fixes.** UiInteractive sets its pressed/hover/focus state through `_set`, which defers to
the end of the frame when called while the tree builds: a recognizer cancels its tap when a rebuild
disables it (a hold button disabled by its own onConfirmed with the finger still down threw
"setState() called during build"). UiMap no longer has its own focusable Focus: with two focusable
nodes the map split in two for screen readers and flutter_map's tappable surface had no name; its
key handler (Enter places the pin) now sits on a non-focusable Focus the key bubbles to. Markers
are 48dp targets centred on the dot. The web map loads Leaflet lazily and needed a destroyed-while-
loading guard; Flutter's map has no lazy load (flutter_map is compiled in), so nothing to guard.
`UiMapBlankTiles` is exported for tests without the network.

**0.35.0 additions.** `UiSize.xl` (56) is a new enum value, so every switch on UiSize handles it:
buttons, icon buttons, toggles and avatars have their own xl look; other controls take its height
with lg text. (The web keeps `UiSize` at sm/md/lg and adds `UiButtonSize = UiSize | 'xl'` for the
controls that have an xl look.) `UiHoldButton` wraps UiButton: a Listener drives the fill (outside
the gesture arena, so the button's own tap still arrives); the button's tap is the fallback that
opens `showUiConfirm` unless it ends a completed hold or a press that lasted past 300ms, which is
measured from the fill's progress so tests with a fake clock agree. Keyboard holds use the button's
FocusNode `onKeyEvent`, which runs before the button's activation shortcuts. UiButton gained
`semanticHint` for it. The map is its own library, `package:zouriel_ui/map.dart` (not exported from
`zouriel_ui.dart`), on flutter_map 8.3.2 and latlong2 0.10.1, pinned. flutter_map has no zoom
control or draggable marker: the zoom buttons are UiIconButtons, and the pin follows a pan gesture
through `screenOffsetToLatLng`. The map itself lays out LTR (tiles are physical); its controls follow
the app's direction.

**0.34.0 additions.** `UiStrings` is `UiConfig.strings` (the web `provideUiStrings`, same keys),
read with `context.uiStrings`; the web default "Click to upload" is "Tap to upload" here. The old
`UiFloatingPanel` (the menu and popover surface) is renamed `UiOverlayPanel`, because the web
`ui-floating-panel` (a card floating over a map) now has that name; no app used the old one. The
new `UiFloatingPanel` is a `Positioned`, so it goes straight into a Stack. Timeline states: the
web marks the current step with `aria-current="step"`; Flutter semantics has no such flag, so
current and upcoming items carry a hint ("Current step", "Upcoming"). `UiRowActions` is a Wrap.
Buttons, toggle and split buttons, and the switch already had `semanticLabel` here, which is what
the web's new `ariaLabel` inputs match.

**Page transitions (0.34.0).** `UiPageRoute` takes `transition: UiPageTransition` (fade, the old
default; slideFromStart; slideFromEnd). The web twin is `uiSlideTransition` on a region or router
outlet, which uses the View Transitions API: Flutter's equivalent of a view change is a route push,
so the API lives on the route. The page beneath doesn't move (the web's old view gives way by 30%),
since a route can't know whether the route covering it slides. The iOS/macOS swipe back is a
strip on the edge the page slid away from with its own HorizontalDragGestureRecognizer fed from a
Listener, as in Cupertino; `popGestureEnabled` is checked when a finger lands, not in
buildTransitions, because it turns false while a gesture runs and checking it there tore the
detector down mid-swipe. The finger drives the animation linearly until the release settles.

**0.33.1 fixes.** The field placeholder is a `Text`, which merges its style into the ambient
DefaultTextStyle; that merge re-applied the library's font package to an already resolved family
('packages/zouriel_ui/packages/zouriel_ui/Poppins', and an app's 'Faruma' fallback prefixed too). It is
now drawn with `inherit: false`. UiTextarea's text node covered only its lines (about 254x21 at one
row): UiTextEditor takes a `padding` that sits inside its own tap and semantics area, the textarea
always draws its box behind the editor, and on touch screens lays out at least 48dp tall with the box
centred (as single-line fields do). UiHint above or below never falls back to the sides of its anchor
(it slides along its side; the opposite side only when there is no room). It already followed a moving
anchor: `OverlayPortal.overlayChildLayoutBuilder` lays the hint out again whenever the anchor's paint
transform changes, which a test now covers. The web needed a frame loop for the same.

**Field slots, dir and textStyle (0.33.0).** The web `[textarea-leading]` / `[textarea-trailing]`
(and `[input-…]`) are `leading` / `trailing` widgets. UiInput puts them in a Row inside its fixed-height
frame, which on touch screens is already laid out 48dp tall, so a slot's UiIconButton gets its full
touch target. UiTextarea draws the frame behind a Row of [slot, text, slot] aligned to the bottom,
each slot as tall as the last line box; on touch screens it adds a transparent margin above and
below (`uiSlotTouchMargin`) because a hit test stops at a widget's bounds, so a 48dp button centred
on a ~40px line box would otherwise lose taps at its edges. The visible box keeps its height. A tap
on a slot's empty space focuses the field (a GestureDetector that loses the arena to any button
inside). `dir` is `UiTextDir` (ltr, rtl, auto: the first strong character, as the web resolves
`dir="auto"`), applied with a Directionality so the slots swap too. `textStyle` is merged with
`uiMergeFieldStyle`, not `TextStyle.merge`: merge keeps the base style's package and would turn an
app font like `'Faruma'` into `'packages/zouriel_ui/Faruma'`. A one-row textarea's text area is
still shorter than 48dp (as before; the slots are not).

**UiHint (0.33.0).** The web `[uiHint]` directive is a wrapper widget: `open` + `onOpenChanged` for
the model, `onClosed` for the output. It reuses UiTooltipLayout (preferred side, opposite, then the
perpendicular ones) with a 10px gap; the layout records the side and the anchor centre's offset in a
notifier the arrow painter reads, so the arrow keeps pointing at the anchor after a shift. Escape
comes from a HardwareKeyboard handler that never consumes the key (the hint never has focus), and a
tap on the anchor from a Listener, which is outside the gesture arena so the anchor's own tap still
fires. The text is set 30ms after the bubble appears, as on the web, so the live region announces it.

**Dialog close fade (0.33.0).** On the web 0.32 drawer the backdrop's short leave fade ended before
the panel's slide, Angular (22.2) dropped the leave class, and the backdrop flashed back to full for a
frame or two. Flutter routes fade the barrier with the route animation, so it can only fall during a
close (`close_flicker_test.dart` checks drawer and modal frame by frame). UiBottomSheet's backdrop
used to vanish at once; it now fades out and stays mounted at 0, ignoring touches.

**Maldives Dark (0.32.0).** The web's `[data-theme="maldives-dark"]` (a second block in
`theme-maldives.css`) is `UiThemeName.maldivesDark`: `gen_tokens.mjs` camelCases a hyphenated web
name for the enum value. It has maldives' full token set, the brand tokens included, with values
for a dark page (`oceanDeep` is the light Foam ink, `mist` the night canvas), and the same sea
signature motion (`_seaMotion` in `fx/utilities.dart`). `UiSeaSurface` still scopes `maldives` by
default; pass `theme: UiThemeName.maldivesDark` (or `null` to follow the app) for the night sea.

**Theme icon colour (0.31.0).** The web's `--ui-color-icon` is `UiTokens.icon`, set only by maldives.
On the web one global rule colours every `hugeicons-icon` with it and filled or state-coloured
components reset it to `currentColor`; here `UiApp`/`UiThemeScope` default `IconTheme` to
`icon ?? text` and the neutral slots (ghost and outline buttons, inactive nav/tab/segment items,
input adornments, list, menu and palette icons, empty state, stat card) use `icon` too, while
filled, selected, danger and toned ones keep their foreground. `UiThemeController.maybeOf(context)`
(provided by `UiApp`) is the twin of injecting `UiThemeService`. `UiSectionLabel` has the web's
`variant` (`auto` = bracket on Dark Orange, eyebrow elsewhere).

## What maps how (from inventory.md)

- **Port 1:1:** buttons (button, icon, group, segmented, toggle, split, dropdown, FAB), every form
  control, combobox/multi-select, date/range pickers + calendar, alert, badge, chip, avatar(+group),
  card, stat card, accordion, list, table, tree, tree table, timeline, description list, code block,
  progress bar/circle, meter, spinner, skeleton, divider, text, link, kbd, tabs, stepper, pagination,
  breadcrumbs, bottom nav, side nav (as drawer content), navbar (app bar), anchor nav, tooltip,
  popover, menu, modal, drawer, bottom sheet, confirm dialog, toasts, snackbar, backdrop, empty state, result,
  carousel, gallery, image picker, file viewers (image/video/audio/text/code/PDF), FX (reveal,
  marquee, split text, drift, glyph field, grain, intro loader, scroll progress, magnetic → press
  tilt), theme service/provider, config.
- **Already native in Flutter (thin wrapper or docs only):** click-outside (TapRegion), intersect
  (visibility via scroll notifications), infinite scroll, virtual list (ListView.builder), ripple,
  resize observer (LayoutBuilder/SizeChangedLayoutNotifier), copy (Clipboard), draggable/resizable
  primitives, scroll area.
- **Mobile adaptation:** context menu → long-press menu; menubar → overflow menu in the app bar;
  command palette → full-screen search sheet; splitter → tablet only; cursor FX → not applicable
  (touch has no cursor), replaced by touch feedback.
- **Tablet / later phase:** window system (floating windows), design tools (transform box, path
  editor, sequencer, scrubber), file explorer split view, form builder editor UI.
- **Form builder:** the engine (definition schema, conditions, calculations, validators, formats,
  diff/lint, option sources incl. HTTP) ported to pure Dart with the **same JSON**; the renderer as
  widgets. Shared fixtures: JSON definitions + answers + expected results exported from the Angular
  specs, run by both test suites so the two stay identical.
- **Workflow builder:** see `docs/WORKFLOW.md`. The model is typed views (extension types) over
  the spec JSON instead of classes with `extra`, because the definition helpers are spread-based
  and must keep object identity exactly like `definition.ts` (`identical(next, def)` means "no
  change"); unknown keys survive by construction. The lifecycle layout runs the shared
  `layout.json` fixtures. `optionLabel` is `wfOptionLabel` here (the form engine already exports
  an `optionLabel`). There is no DI: every runtime widget takes `api`.

## Phases

1. Foundation: workspace, token generator, themes, `UiApp`, test harness (fonts, goldens, a11y
   helpers), showcase shell (navigation, theme picker), APK build pipeline, Telegram delivery.
2. Everyday components, one by one, each with tests + goldens + showcase section.
3. Overlays and dialogs.
4. Data display and navigation.
5. Media and file viewers.
6. Form engine + renderer (shared JSON), then builder for tablets.
7. FX and tablet extras.

Progress is tracked by ticking `docs/inventory.md`.
