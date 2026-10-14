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

## Releasing

Both libraries share one version number. For a release: bump `projects/ui/package.json` in Angular and
`packages/zouriel_ui/pubspec.yaml` in Flutter to the same version, commit both, then:

- Angular: `ng build ui`, `npm publish` from `dist/ui` (GitHub Packages, `@zouriel` scope), tag `vX.Y.Z`, push the tag.
- Flutter: tag `vX.Y.Z` and push it; apps pin it with `ref: vX.Y.Z` in their git dependency.

## Using the library in an app

Always install a released version, never a path or `file:` link to the local checkout. To pick up a
library change in an app, release it first (see "Releasing" in either repo's `AGENTS.md`), then bump
the app's version.

**Angular apps** (`@zouriel/ui` on GitHub Packages):

- `.npmrc` in the app, committed, with the token taken from the environment (never write the token
  value into a file):
  ```
  @zouriel:registry=https://npm.pkg.github.com
  //npm.pkg.github.com/:_authToken=${NODE_AUTH_TOKEN}
  ```
- Install with `NODE_AUTH_TOKEN=$(gh auth token) npm i @zouriel/ui@^X.Y.Z @angular/cdk @hugeicons/angular @hugeicons/core-free-icons`
  (plus `pdfjs-dist` only for the PDF viewer). The token needs the `read:packages` scope.
- Docker builds: pass the token as a build secret (`RUN --mount=type=secret,id=npm_token NODE_AUTH_TOKEN=$(cat /run/secrets/npm_token) npm ci`),
  not as an `ARG`/`ENV`, which stays in the image.
- Load `@zouriel/ui/styles/tokens.css` and `animations.css` globally (without tokens.css nothing has
  colour or spacing), import components from their entry points (`import { UiButton } from '@zouriel/ui/button'`),
  and optionally `provideUiConfig({...})` in the app providers. Full guide: the Angular `README.md` "Quick start".
- `^0.21.0` only accepts 0.21.x: moving to a new minor version is a deliberate bump in the app's `package.json`.

**Flutter apps** (`zouriel_ui`, from GitHub, pinned to a release tag):

- In `pubspec.yaml`:
  ```yaml
  dependencies:
    zouriel_ui:
      git:
        url: https://github.com/Zouriel/flutter-ui-library.git
        path: packages/zouriel_ui
        ref: vX.Y.Z
  ```
  Always pin `ref` to a tag, never a branch; update by changing the tag and running `flutter pub get`.
- Use `UiApp` instead of `MaterialApp` (`UiApp(theme: UiThemeName.dark, home: ...)`), read tokens with
  `context.ui` and text styles with `context.uiText`, switch themes with `UiThemeController`. Don't
  mix in Material widgets for things the library has. Full guide: the Flutter `README.md` "Use".
- Every component, with demos and its API, is in the showcase app (`apps/showcase`) and on
  https://zouriel.com/uilib/ for the Angular side.

## Rules for this repo

- Read `docs/CONVENTIONS.md` before adding or changing a component; record decisions in `docs/PORTING.md`
  and keep `docs/inventory.md` ticked.
- Widgets layer only: no Material imports, no literal colours, icons via `UiIcon` (the
  `style_contract_test` enforces this).
- Toolchain: `source ~/development/flutter-env.sh` first.
