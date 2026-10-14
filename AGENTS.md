# Agent instructions: zouriel_ui (Flutter)

## Every change goes into Flutter and Angular

This library is the Flutter port of `@zouriel/ui` at
`/home/zouriel/personal/angularUiLib/ui-workspace` (docs: https://zouriel.com/uilib/). Any change
made here, whether the owner asked for it or an agent from another project needs it, must be made in
the Angular library in the same task:

- Same API, behaviour and look. Follow the Angular repo's `AGENTS.md`.
- Tests in both: `flutter test` in `packages/zouriel_ui` here; `ng test ui` there.
- Docs in both: the page in `apps/showcase` here, and the Angular showcase page there.
- Tokens come from the Angular stylesheets: change them there, then regenerate
  `lib/src/theme/tokens.g.dart` with `tool/gen_tokens.mjs`. Never edit `tokens.g.dart` by hand.
- Form-builder engine changes: add or update the shared JSON fixtures, which run in both suites.

Only skip the Angular side when the change has no meaning there (e.g. a touch-only Android
behaviour), and say so and why in your report. A change made in only one library is not done.

## Rules for this repo

- Read `docs/CONVENTIONS.md` before adding or changing a component; record decisions in `docs/PORTING.md`
  and keep `docs/inventory.md` ticked.
- Widgets layer only: no Material imports, no literal colours, icons via `UiIcon` (the
  `style_contract_test` enforces this).
- Toolchain: `source ~/development/flutter-env.sh` first.
