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
