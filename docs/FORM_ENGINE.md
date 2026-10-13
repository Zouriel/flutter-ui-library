# Form engine (Dart)

The non-UI core of the form builder, ported from the Angular library
(`projects/ui/form-builder/src`). It reads and writes the **same JSON**, so a form built in the web
builder runs and validates identically in Flutter, and answers saved by either can be opened by the
other. The renderer and builder widgets come later and sit on top of this.

Code: `packages/zouriel_ui/lib/src/form_builder/engine/`, exported by
`lib/src/areas/form_engine.dart` (and so by `package:zouriel_ui/zouriel_ui.dart`). It is pure Dart:
no Flutter imports, so it also runs on a server or in a CLI. The only dependencies are `intl` (dates
and non-US number formats) and `http` (the default fetch for lists set up in settings; replaceable).

## Same behaviour, proven by shared fixtures

`packages/zouriel_ui/test/form_engine/fixtures/*.json` hold definitions, answers, steps and
expected outcomes (visible fields, required, errors per page, calculated values, display strings,
saved data, change lists, lint problems, diffs, request URLs...). The same files are copied to the
web repo at `projects/ui/form-builder/src/fixtures/` and run there by `shared-fixtures.spec.ts`.
Both suites pass on identical expectations; **the Angular engine is the reference**: when they
disagree, fix the Dart port, never the fixture.

| File | Covers |
| --- | --- |
| `scholarship.definition.json`, `scholarship.answers.json` | The showcase sample form (`form-builder.sample.ts`) and its saved answers |
| `engine-scholarship.json` | The sample filled in from scratch, edited (saved answers, hidden answers kept until seen, change list), and viewed |
| `engine-rules.json` | Engine cases from `engine.spec.ts` and the other specs: rules, required/disabled/read-only, every built-in check, repeats, jumps, set-value rules, defaults, clear-hidden modes, sourced answers |
| `conditions.json`, `calc.json`, `describe.json` | Every operator (dates, times, files, choices, `{value,label}` answers), every calculation, plain-English wording |
| `values.json`, `slug.json` | Answer coercion, saved choices, paging, display strings (US English), keys from labels |
| `definition.json` | Lint, loops, references, removing references, migration, exact round trip, unique keys, renames, moves, version diffs |
| `http-sources.json` | Request URLs, reading replies (and their error messages), label patterns, the origin allow-list, global settings |

Runner format (both sides implement it): an engine case has `definition`/`definitionFile`,
optional `data`/`dataFile`, `mode` and `today`, then `steps`. A step either acts (`set`, `touch`,
`addRow`, `removeRow`, `moveRow`, `next`, `back`, `goTo`, `submit`) or checks (`expect`). Field
instances are written `id` or `id@N` (the N-th entry of the field's repeatable group). The web runner
calls `TestBed.tick()` after every step, which is the state the Dart engine is always in (see
"Reactivity" below).

To change behaviour: change the Angular engine, update the fixture, copy the fixtures folder to the
other repo, and make both suites pass.

```sh
# Flutter
cd packages/zouriel_ui && flutter test test/form_engine
# Angular (needs the library built)
npx ng test ui --watch=false --include projects/ui/form-builder/src/shared-fixtures.spec.ts
```

## API mapping

### Schema (`schema.dart` ← `schema.ts`)

| Angular | Dart |
| --- | --- |
| `UiFormDefinition`, `UiFbPage`, `UiFbSettings` | classes of the same names, `fromJson` / `toJson`, `UiFormDefinition.clone()` |
| `UiFbElement = UiFbField \| UiFbGroup \| UiFbStatic` | `sealed class UiFbElement` with those subclasses; `UiFbElement.fromJson` switches on `kind` |
| `UiFbFieldType`, `UiFbOperator`, `UiFbCalcOp` (string unions) | string-backed extension types: `UiFbFieldType.text`, `UiFbOperator.anyOf`... Unknown values from newer forms are kept, not rejected |
| `UiFbCondition = UiFbConditionGroup \| UiFbConditionRule` | sealed `UiFbCondition`; `UiFbCondition.fromJson` picks the group when `conditions` is present |
| `UiFbOperand = {const}\|{ref}\|{today}` | sealed `UiFbOperand`: `UiFbConstOperand` (`hasValue` false for a stored `{}`), `UiFbRefOperand`, `UiFbTodayOperand` |
| `UiFbToggle = boolean \| {when}` | `UiFbToggle.flag(bool)` / `UiFbToggle.when(cond)`; `isConditional` |
| `UiFbCalcArg` | sealed: `UiFbCalcRefArg`, `UiFbCalcConstArg`, `UiFbCalcNestedArg` |
| `UiFbSourceParamValue` | `typedef` of `UiFbOperand` (`const` or `ref`) |
| `defaultValue?: unknown` | `defaultValue` plus `hasDefaultValue` (a stored `null` default is still a default) |
| `UiFbFileValue`, `UiFormSubmission`, `UiFbChange` | same names; files picked in the session are `UiFbPickedFile` (name, size, type, opaque `handle`) instead of the browser's `File` |

Round trip: `fromJson` keeps every key it doesn't know in `extra` and `toJson` writes it back, so
`UiFormDefinition.fromJson(j).toJson()` equals `j` (structurally) for any form the web builder
writes, including keys added by newer versions. The model classes are mutable; the definition
helpers never mutate what you pass in (they clone first), matching the web's immutable style.
Answers are plain JSON (`Map`/`List`/`String`/`num`/`bool`/`null`), exactly what is saved.

### Rules, calculations, checks (`conditions.dart`, `calc.dart`, `validators.dart`)

| Angular | Dart |
| --- | --- |
| `evaluateCondition(c, ctx)`, `describeCondition`, `conditionComplete`, `resolveOperand`, `isEmptyValue`, `isoDate`, `addDays` | same names. `UiFbConditionContext` is an interface; `UiFbConditionFns` builds one from functions |
| `evaluateCalc`, `describeCalc`, `UI_FB_CALC_OPS`, `calcOpInfo` | same; `uiFbCalcOps`. Results are `int` when whole (as JSON writes them), `double` otherwise, `String` for `concat`. `UiFbCalcFns` builds a context |
| `UiFbValidatorDef` (`validate` may return a Promise) | `UiFbValidatorDef` with `validate` returning `FutureOr<Object?>` (`true`/`null` pass, `false` fails with the message, a `String` is the message) |
| `provideUiFormValidators(...)` | pass `validators: [...]` to `UiFormEngine` |
| `UI_FB_BUILTIN_VALIDATORS`, `UI_FB_IMPLICIT_VALIDATOR`, `UI_FB_PATTERN_PRESETS` | `uiFbBuiltinValidators`, `uiFbImplicitValidator`, `uiFbPatternPresets` |
| `validatorsFor(field, all)` | `validatorsFor(type, format, all)` |
| `formatMessage`, `comparisonWords`, `resolveDateParam`, `describeDateParam`, `todayIso` | same names |
| `UiFbParamSpec.default` | `hasDefault` + `defaultValue` |
| `AbortSignal` | `UiFbAbortSignal` / `UiFbAbortController` |

### Field types and formatting (`field_types.dart`, `format.dart`)

`UI_FB_FIELD_TYPES` → `uiFbFieldTypes`, `UI_FB_STATIC_TYPES` → `uiFbStaticTypes`, `fieldTypeInfo`,
`valueKindOf`, `operatorInfo`, `operatorsFor` (takes a `UiFbSubjectKind`: the value kinds plus
`group`, `repeat`, `page`), `typesCompatible`. `UiFbValueKind` is an enum.

`formatValue(field, value, {locale})`, `formatDate(iso, {locale})`, `optionLabel`. The web uses the
browser's locale; Dart uses `locale` or `Intl.getCurrentLocale()`. For US English (`en_US`, the
default) numbers and money are formatted by our own code that reproduces V8's
`Intl.NumberFormat('en-US')` digit for digit (grouping, half-up rounding on the shortest decimal,
`€`/`£`/`CA$` symbols, `MVR 1,234.50` for codes without one); other locales use `intl`.

### Definition helpers (`definition.dart` ← `definition.ts`)

All of them, same names: `fbUid`, `fbSlug`, `fbKeyValid`, `createDefinition`, `createPage`,
`createField`, `createGroup`, `createStatic`, `indexDefinition` (`UiFbIndexEntry` with `asField`,
`asGroup` helpers), `allElements`, `allFields`, `elementName`, `updateElement`, `updatePage`,
`insertElement`, `removeElement`, `isInside`, `canDrop`, `moveElement` (returns the same instance
when nothing changes, like the web), `duplicateElement` (returns a record `(def:, id:)`),
`uniqueKey`, `renameKey`, `conditionRefs`, `calcRefs`, `sourceRefs`, `referencesTo`, `subtreeIds`,
`externalReferences`, `removeReferences`, `dependencyGraph`, `findCycles`, `lintDefinition`,
`migrateDefinition` (accepts JSON or a `UiFormDefinition`), `diffDefinitions` (`UiFbDiff` with
`toJson`).

Differences: `createDefinition({title, defaults})` and `createField(type, {def, label})` /
`createGroup({def, repeat})` take named arguments. `fbSlug` folds accents with a generated NFKD table
(`slug_table.g.dart`, from `tool/gen_slug_table.py`) because Dart has no Unicode normalisation.

### Option sources (`option_sources.dart`, `http_sources.dart`, `global_settings.dart`)

| Angular | Dart |
| --- | --- |
| `UiFbOptionSourceDef` | `abstract interface class UiFbOptionSourceDef`; `UiFbOptionSource(...)` implements it with a `search` function returning `FutureOr<UiFbSourcePage>` |
| `provideUiFormOptionSources(...)` | pass `optionSources: [...]` to `UiFormEngine` (and later to the renderer/builder) |
| `UiFbSourceItem`, `UiFbSourcePage`, `UiFbSourceQuery`, `UiFbSourceParamSpec`, `UiFbChoice` | same names. A saved choice in answers is the JSON map `{value, label}` |
| `isChoice`, `optionValueOf`, `toChoice`, `sourceHasMore`, `UI_FB_SOURCE_FIELD_TYPES` | same; `toChoice` returns the JSON map; `uiFbSourceFieldTypes` |
| `UiFbHttpSourceConfig` | class with `fromJson`/`toJson` (unknown keys kept) |
| `provideUiFormHttpSources({ fetch, allowedOrigins })` | `UiFbHttpSourcesOptions(fetch:, allowedOrigins:, baseUrl:, ownOrigin:)`. The web reads the page's address and origin from `location`; Dart has none, so pass `baseUrl` / `ownOrigin` (on Flutter web: `Uri.base`) |
| `UiFbSourceFetch(url, {signal})` | `Future<Object?> Function(String url, UiFbAbortSignal signal)` returning decoded JSON. Default: a GET with `package:http`. Inject your own to add auth or for tests |
| `sourceUrl(c, q)` | `sourceUrl(c, query:, page:, pageSize:, params:, baseUrl:)`; serialises the query exactly like `URLSearchParams` |
| `readSourceReply`, `readPath`, `fillPattern`, `originOf`, `originAllowed`, `httpOptionSource`, `sourceFetch` | same names; errors are `UiFbSourceError` with the same wording |
| `UiFormGlobalSettings`, `createGlobalSettings`, `sourcesFromSettings` | same names; settings JSON round-trips |

### The engine (`engine.dart` ← `engine.ts`)

```dart
final engine = UiFormEngine.fromJson(
  storedDefinitionJson,          // migrated to the current schema
  data: savedAnswers,            // omit for a new form (mode create)
  mode: UiFormMode.edit,         // create | edit | view (default: edit with data, else create)
  validators: [studentIdExists], // app checks; built-ins are always on
  optionSources: [students],
);
engine.addListener(() => setState(() {}));
engine.setValue('f_name', null, 'Aminath');
engine.instanceState('f_name', null); // visible, disabled, required, value, errors, warnings, pending
final submission = engine.submit();   // null (and moved to the first page with problems) or the data
```

| Angular (signals) | Dart |
| --- | --- |
| `new UiFormEngine({ definition, data, mode, validators, optionSources, today, injector })` | `UiFormEngine(definition:, data:, mode:, validators:, optionSources:, today:, now:)` or `UiFormEngine.fromJson(json, ...)`. No injector; `now` stamps `submittedAt` |
| `path()`, `page()`, `step()`, `isLastPage()`, `pageIndex()` / `.set()` | getters `path`, `page`, `step`, `isLastPage`, `pageIndex` (settable) |
| `data()`, `dirty()`, `changes()` | getters `data`, `dirty`, `changes` |
| `touched()`, `attempted()` | read-only `touched`, `attempted` sets |
| `settings` | `settings` (`UiFbEngineSettings`) |
| `instanceState`, `rows`, `rawValue`, `answerFor`, `field`, `optionSource`, `errorsShown`, `instancesOn`, `pageErrors`, `pagePending`, `instanceLabel`, `dataPath` | same |
| `setValue`, `markTouched`, `canAddRow`, `canRemoveRow`, `addRow`, `removeRow`, `restoreRow`, `moveRow`, `next`, `back`, `goTo`, `submit`, `setFiles` | same (`setFiles(id, row, picked, {uploaded})`) |
| `files: Map<string, File[]>` | `files: Map<String, List<UiFbPickedFile>>` |
| `destroy()` | `dispose()` |
| renderer's `sourceParams` computed | `engine.sourceParams(id, row)`: a sourced field's params with other answers filled in |
| `coerceValue`, `requiredMessage`, `addrOf` | same |
| (none) | `addListener` / `removeListener` |

**Reactivity.** The web engine is lazy signals plus two effects (set-value rules, async checks)
that run on change detection. The Dart engine is eager: every change re-evaluates the form, runs
set-value rules to a fixed point (a rule fires when its condition *becomes* true, never on load),
starts async checks (debounced, newest wins, a crashing check never blocks), then calls listeners.
That is exactly the state a running web form is in after change detection, which is why the web
fixture runner ticks after each step. It also matters for one rule: an answer that was saved, is
hidden by a rule, and was never shown in this session is kept on save; once it has been on screen
and is hidden again, it is cleared.

Async checks use `dart:async` timers. In widget tests drive them with `tester.pump(duration)`; in
plain tests, wait for the debounce (400ms by default, `debounceMs` per check).

## JavaScript semantics

The web rules lean on JavaScript conversions (`String(10)` is `"10"`, `Number(" 12 ")` is `12`,
`!!"0"` is true, `Math.round(-2.5)` is `-2`, strings compare by UTF-16 code units). `js.dart`
reproduces these for JSON values, and the engine uses them wherever the web does, so comparisons,
messages and saved values match. The fixtures pin the edge cases.

Known, deliberate gaps (not reachable from forms the builder makes):
- `new Date(y, m, d)` maps years 0-99 to 1900-1999 on the web; Dart doesn't.
- Non-US locales are formatted by `intl`, whose rounding and symbols can differ slightly from the
  browser's `Intl`.
- Option values that aren't strings in stored JSON are read as strings.

## Not here yet

- The builder widgets (a later, tablet phase). The renderer is done: see "Renderer" below.
- The builder store (undo/redo, selection) lives with the builder UI.

## Renderer (`lib/src/form_builder/renderer/`, `lib/src/form_builder/sources/`)

`UiFormRenderer` (web `ui-form-renderer`), `UiFbFieldView` (`ui-fb-field`) and `UiFbSourcePicker`
(`ui-fb-source-picker`), exported by `lib/src/areas/form_renderer.dart`.

| Angular | Flutter |
| --- | --- |
| `[definition]` | `definition:` a `UiFormDefinition` or its JSON map |
| `[data]`, `[mode]`, `[validators]`, `[optionSources]`, `[globalSettings]`, `[today]` | same names; `httpSources:` replaces `provideUiFormHttpSources` |
| `[uploader]` `(file, field) => Promise` | `uploader:` `(UiPickedFile, UiFbField) => Future<UiFbFileValue>` |
| the browser's file dialog | `filePicker:` a `UiFilePicker` from the app (file_picker / file_selector) |
| `(submitted)`, `(cancelled)`, `(valueChange)`, `(dirtyChange)` | `onSubmitted`, `onCancelled`, `onValueChanged` (only when the data actually changes), `onDirtyChanged` |
| `submit()`, `reset()`, `engine()` | `GlobalKey<UiFormRendererState>`: `submit()`, `reset()`, `engine` |

Same JSON: `test/form_renderer/e2e_test.dart` fills the sample form in through the widgets and
compares the submission with the Angular engine's output in `engine-scholarship.json`, and saves
the sample answers back unchanged in edit mode.

Mobile differences: the 12-column grid collapses to one column at 560px or less, as on the web;
`labelPlacement: inside` draws an outlined floating label that rests on the box's border (the web
moves it inside a taller box); after Continue the page scrolls back to the form's top, and focus
moves into the first field only with a hardware keyboard (on touch it would pop the keyboard up);
the error summary's links are underlined on hover/focus rather than at rest (contrast check).
