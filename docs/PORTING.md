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
