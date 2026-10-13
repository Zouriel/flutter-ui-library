# How to port a component

Read `docs/PORTING.md` first (decisions, toolchain). The Angular source of truth is
`/home/zouriel/personal/angularUiLib/ui-workspace/projects/ui/<entry>/src/*.ts` (template + styles +
inputs), its spec files, and its docs page `projects/showcase/src/app/pages/*.page.ts` (summaries say
exactly what each component does). `docs/inventory.md` lists every class to port.

## Environment
`source ~/development/flutter-env.sh` before any `flutter`/`dart` command (Flutter 3.47.7, JDK 21,
Android SDK). Never `pkill`. Never edit files outside your ownership.

## Code
- Import `package:flutter/widgets.dart` (+ `rendering`, `services`, `foundation`, `gestures`,
  `scheduler` as needed). **Never** `material.dart`, `cupertino.dart` or `material_ui` in the library:
  `test/style_contract_test.dart` fails on it.
- Read tokens with `final t = context.ui;` and text with `context.uiText`. **No literal colours**
  (`Color(0x...)`, `Colors.*`) outside `tokens.g.dart` (only `Color(0x00000000)` transparent is allowed).
  Spacing uses `t.space1/2/3/4/6/8/12/20`; sizes `t.sizeSm/Md/Lg`; radii `t.radius`, `t.radiusXs/Sm/Lg/Pill`;
  motion `t.motionFast/Base/Slow` with `t.easeStandard`/`easeDecelerate`/`easeAccelerate`/`easeSpring`.
  Hover fill `t.surfaceHover` (inside raised panels `t.elevatedHover`), selected `t.selected`,
  focus ring `t.focusRing` (as `boxShadow`), overlay scrim `t.overlay`, shadows `t.shadow1/2/3`.
- Honour `context.uiTheme.config` (`radius`, `glass`) like the web components honour `UiConfig`, and
  `context.uiAnimate` for motion (false → no animation / instant).
- Every tappable thing uses `UiInteractive` (hover/press/keyboard focus ring/Enter+Space/disabled/
  semantics/48dp touch target). Use its `UiStates` to paint. If a control's visual must stay small
  inside a fixed-height parent (like the chip's remove button), reserve the 48dp area in layout on
  touch platforms (`uiTouchPlatform(context)`, `uiMinTouchTarget`), see `UiChip`.
- Icons: `UiIcon(HugeIcons.strokeRoundedX)` (follows IconTheme size/colour). Never emoji or text
  glyphs (✓ ✕ ▾ ← → …) as icons; `style_contract_test.dart` fails on them.
- Inputs become constructor params; Angular `model()` (two-way) becomes `value` + `onChanged`;
  outputs become callbacks; content slots become named `Widget` params. Keep the web names where
  sensible (`UiButtonVariant`, `UiSize`, `UiStatus`). Form controls also work inside
  `UiFormField`/Flutter `Form` (when that exists; until then value/onChanged + `enabled`).
- Text editing: build on `EditableText` (widgets layer) with our own decoration; selection handles via
  `TextSelectionControls` you implement or `emptyTextSelectionControls`; never `TextField`.
- Overlays: `OverlayPortal` + `CompositedTransformTarget/Follower` or the shared helper in
  `lib/src/overlay/` once it exists; keep inside the screen (flip, then shift, 8px margin).
- Accessibility: `Semantics` with the right role/label/value/state; headings via `UiText`; live
  regions for things the web announces; keyboard support the web docs describe.
- Doc comments: one `///` line naming the web counterpart (`ui-x`) and saying what it does, plus
  anything surprising. Match the existing files' tone: plain, short.

## Tests (required for every component before it counts as done)
In `packages/zouriel_ui/test/<area>/`:
1. Behaviour: callbacks, value changes, keyboard, disabled, edge cases.
2. Semantics: labels/roles/values (`tester.ensureSemantics()`, `getSemantics(...).getSemanticsData()`).
3. Guidelines: `meetsGuideline(androidTapTargetGuideline)`, `labeledTapTargetGuideline`,
   `textContrastGuideline` (tests run as Android, so touch padding applies).
4. Layout sanity: assert sizes where a mistake is easy (hug vs stretch, fills, min sizes).
5. A golden via `expectThemedGolden` (`test/helpers.dart`), dark + light side by side.
   Generate with `flutter test --update-goldens test/<area>` then **open every PNG with the Read tool
   and look at it**: spacing, alignment, clipping, contrast, overflow stripes, wrong sizes. Fix and
   regenerate until it looks like the web component. A green golden you didn't look at proves nothing.
Run `flutter analyze` (zero errors/warnings in your files) and `flutter test` (all green) before
finishing.

## Showcase
Each area has a page in `apps/showcase/lib/pages/` (pre-registered in `registry.dart`). Use
`DocPage`/`DocSection`/`ApiRow`/`DocCode` from `lib/docs/doc.dart`: summary (accurate, plain
English), a live interactive demo, a code sample that compiles, and the API rows. Mirror the web page
for the same components.

## Finishing
Tick your classes in `docs/inventory.md` (port / tests / golden / showcase). Commit on your branch
with a clear message. Report: what you ported, tests added, anything not ported and why.
