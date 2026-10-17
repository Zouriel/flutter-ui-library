# Workflow builder (Dart)

The Flutter port of `@zouriel/ui/workflow` (see `projects/ui/workflow/README.md` in the Angular
repo): a builder where admins design workflows without code, and the widgets that run them in
your app: a record panel, a task inbox, a run view, an audit log and a settings screen. Workflows
are JSON in the Zouriel Workflows format, run by an engine on your server (the .NET engine first;
Laravel and Go engines follow the same spec and REST API).

Code: `packages/zouriel_ui/lib/src/workflow/` (and `lib/src/canvas/viewport.dart`), exported by
`lib/src/areas/workflow.dart`, so everything comes from `package:zouriel_ui/zouriel_ui.dart`.

```dart
UiWorkflowBuilder          // where admins design workflows
UiWorkflowRecordPanel      // a record's state, moves, tasks and history
UiWorkflowTasks            // the signed-in person's approvals and tasks
UiWorkflowRun              // one run over its workflow, with retry/skip/cancel
UiWorkflowAudit            // the tamper-evident log: filter, export, verify
UiWorkflowGlobalSettings   // working hours, channels, webhooks, retention
UiWorkflowStateBadge       // a state as a coloured chip
UiWorkflowHttpApi          // connects the widgets to the engine's REST API
```

## Two kinds of workflow

- **Automations** start when something happens to a record: it is created or deleted, a field
  changes (from/to chosen values), a date comes up, a schedule fires, someone presses a button, or
  your app reports an event. They run a tree of steps: approvals and tasks for people, waits,
  branches, switches, parallel paths, loops over related records, go-back loops, record updates,
  variables, notifications, webhooks, your own actions and other workflows.
- **Lifecycles** own a status field: its states and the transitions between them, who may make each
  move, checks, a form, a confirmation, automatic moves on a timer, and steps to run on each move,
  on entering or leaving a state, or when a record stays too long.

Every start, step, decision and move is written to a hash-chained audit log.

## Set up

Backend (.NET): add `Zouriel.Workflows.AspNetCore` and `Zouriel.Workflows.EntityFrameworkCore`,
register the entities, fields, actions and events workflows may use, and
`app.MapWorkflowApi("/api/workflows")`.

Flutter: there is no dependency injection, so make one client and pass it to each widget.

```dart
final api = UiWorkflowHttpApi(
  baseUrl: 'https://app.example.com/api/workflows',
  headers: () async => {'Authorization': 'Bearer ${await auth.token()}'},
  // client: your own http.Client (retries, logging, a session header)
);
```

`api.me()` (`GET /me`) returns the signed-in person and what they may do (`UiWfMe`: `canEdit`,
`canPublish`, `canSettings`, `canIntervene`, `canAudit`), for deciding which screens to offer.

The runtime widgets count "2 hours ago" and "due in 3 days" from the device's clock. When the
engine's clock is the one that counts (a sandbox moved forward in time, a server in another time),
put a `UiWorkflowClock(now: () => engineNow(), child: ...)` above them, ideally above your
navigator so dialogs see it too (the web `UI_WORKFLOW_CLOCK`).

Implement `UiWorkflowApi` yourself to talk to an engine some other way (the showcase uses an
in-memory one, `apps/showcase/lib/pages/workflow_demo_api.dart`).

## The builder

```dart
UiWorkflowBuilder(
  definition: workflow,                 // UiWorkflowDefinition.fromJson(json)
  onChanged: (d) => setState(() => workflow = d),
  published: published,
  api: api,
  persist: true,                        // Save and Publish in its header
  onSaved: (d) => reload(),
)
```

| Parameter | Type | Notes |
| --- | --- | --- |
| `definition` / `onChanged` | `UiWorkflowDefinition` | The workflow being edited. Create one with `createWorkflow('automation' or 'lifecycle', title:, entity:)`. |
| `controller` | `UiWorkflowBuilderController?` | Selection, undo/redo, problems from outside. |
| `published` | `UiWorkflowDefinition?` | Locks the record type. |
| `api` | `UiWorkflowApi?` | Registry, checks, saves, versions, tests. |
| `schema` | `UiWorkflowSchema?` | Registry and step outputs, when there is no API. |
| `settings` | `UiWorkflowSettings?` | Global settings, when there is no API. |
| `persist` | `bool` | Save and Publish through the API. |
| `onProblemsChanged` | `List<UiWfProblem>` | The engine's problems after each check. |
| `onSaved` | `UiWorkflowDefinition` | After a successful save. |
| `readOnly` | `bool?` | Look without changing anything; null asks `api.me()` whether the person may edit. Shows "View only", hides Save, Publish, Versions and Test, turns controls off and skips the engine check. |
| `onDirtyChanged` | `bool` | Whether there are edits not yet saved through the API (with `persist`). |
| `actions` | `Widget?` | Your own buttons in the header. |

Layout by its own width: wide (1100+) shows the step picker, canvas and settings side by side;
medium (720+) opens the picker in a dialog; narrow opens the picker and the settings in bottom
sheets. Grips drag at once (with a 1px slop so they beat scroll views on phones); a card or a
picker type drags after a long press on touch and after a small move with a mouse. The lifecycle
diagram sits on `UiCanvasViewport` (pan, pinch, wheel and trackpad zoom, `+` `-` `0`, a fit that
keeps re-fitting until the person pans or zooms, and a minimap when it is at least 520x340).

The lifecycle diagram sits on `UiCanvasViewport`, which keeps fitting the diagram until the person
pans or zooms (a refit that comes up mid-drag waits for the pointer to lift) and never fits below
60% (`fitMinZoom`): a larger diagram starts at its top-left corner and the minimap shows the rest.

## Running workflows in your app

```dart
UiWorkflowRecordPanel(api: api, entity: 'application', entityId: app.id, onChanged: (_) => reloadApp())
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.sideDrawer)
UiWorkflowTasks(api: api, onDecided: (_) => refresh())
UiWorkflowRun(api: api, instanceId: runId, canIntervene: isAdmin)
UiWorkflowAudit(api: api, entity: 'application', entityId: app.id, onExport: (bytes, format) => save(bytes))
UiWorkflowGlobalSettings(api: api)
```

`UiWorkflowPanel` is the record's workflow to attach to its page, like the web `ui-workflow-panel`:
the states as a stepper (green for passed, dark for not reached), what happened in each, and in the
current state the person's moves, tasks and manual workflows (or "Nothing for you to do here right
now."). `layout` picks `vertical`, `horizontal`, `sideDrawer` or `bottomDrawer`. The drawer layouts
put a rail of dots on the screen's edge through the overlay, wherever the widget sits: a mouse hover
opens a `UiDrawerPeek` over the page (moving away closes it), a tap opens a regular `showUiDrawer`.

## Working with definitions in code

Every type is a typed view over the JSON itself (`def.json` is the stored map), so unknown keys
survive a round trip, and every helper returns a new definition, keeping untouched parts identical:
`createWorkflow`, `createStep`, `insertStep`, `moveStep`, `removeStep`, `indexSteps`, `listSteps`,
`tokensAt`, `describeTrigger` / `describeStep`, and `autoLayout`.

## Same behaviour as the web

- `test/workflow/fixtures/layout.json` is the Angular `src/fixtures/layout.json`; both suites must
  lay out every case identically. Change the Angular layout first, then copy the fixture.
- `definition_test.dart` and `store_test.dart` port `definition.spec.ts` and `store.spec.ts`.

## Differences from the web, and why

- No dependency injection: every runtime widget takes `api`.
- The audit export hands the bytes to `onExport` (no browser download); the button shows only then.
- Time zones are a fixed list of common IANA zones (Dart has no `Intl.supportedValuesOf`).
- Token pickers read "Group › Label" (the library's select has no option groups).
- Arrows in sentences are drawn as an icon: the bundled fonts have no arrow glyph.
- `optionLabel` is `wfOptionLabel` (the form engine already exports `optionLabel`).
- The web `ui-drawer` has `modal=false`; Flutter drawers are routes, which always block the page, so
  the non-modal drawer is a separate widget, `UiDrawerPeek` (an overlay with no barrier or focus grab).
- The web stepper's orientation is explicit; here `axis` stays optional (horizontal when it fits), and
  the workflow panel passes `Axis.vertical` for step bodies.
