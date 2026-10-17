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
  variables, new records ("Create record"), notifications, webhooks, your own actions and other
  workflows. "Create record" doesn't offer a field a lifecycle controls (when this workflow or a
  published lifecycle is on that kind of record: the new record starts in its first state), says
  so when the app no longer offers the chosen kind, and later steps read the new id as text.
- **Lifecycles** own a status field: its states and the transitions between them, who may make each
  move, checks, a form, a confirmation, automatic moves on a timer, and steps to run on each move,
  on entering or leaving a state, or when a record stays too long.
  **Applies to** (`lifecycle.appliesWhen`, in the lifecycle settings) limits a lifecycle to some
  records, read from their own fields: a "Passport application" lifecycle for applications whose
  type is Passport, another for visas, and one with no condition for everything else.
  With no condition it covers every record that no other lifecycle on the field covers.
  A lifecycle can also let chosen people **reset** a record (`lifecycle.reset`): its open tasks and
  runs stop, it goes back to the starting state (or another you pick), and the reset's own steps run,
  which can change the record, related records and each item of a list. The builder sets it up under
  "Starting over"; `UiWorkflowRecordPanel` and `UiWorkflowPanel` show the button to those allowed
  (`record.reset`, `api.resetRecord`).
  "Offer it" (`reset.states`) limits it to some states: from a state you pick onwards (that state
  and every state after it, final states included: `wfStatesFrom(def, stateId)`), with a checklist
  to adjust. Without it the reset is offered in every state where it would change something.
  The reset dialog lists what the workflow did since the record last started over
  (`api.resetPreview`): fields it changed on this or other records, records it created, actions,
  messages and webhooks. Everything that can be undone is ticked, except items someone changed
  again since, which start unticked; sent messages and webhooks can't be taken back. People untick
  anything that should stay; the ticked ids go to `resetRecord(..., undo: [...])`, which deletes
  created records, puts fields back and undoes app actions when the app supports it. The reset
  can't be confirmed until the list has arrived; an empty list says "Nothing the workflow did needs
  taking back." If someone changed what the workflow did in the meantime, the engine refuses with
  `resetChanged` and the dialog reads the list again, keeping the person's ticks for the items still
  listed. `UiWorkflowHttpApi.resetPreview` always asks the engine (`GET /records/{entity}/{id}/reset`);
  when that call fails, the dialog says the list couldn't be read and the reset leaves those things
  as they are. A custom API that can't list them throws `UnimplementedError` from `resetPreview`,
  and the dialog then only confirms.
- **Remarks** on negative actions: rejecting an approval, a task's red buttons, red moves (e.g.
  Reject, Withdraw) and Start over all offer a remarks box. Each move has a Remarks setting
  (`transition.comment`: default, not asked, optional or required; the default is optional for red
  moves and not asked otherwise), the reset has one (`reset.comment`, optional by default), and
  approvals and tasks say when remarks are required (`requireComment`: optional, required to reject
  or for red buttons, always). A required remark left empty stops the move ("Add remarks to explain
  this.") or the decision. Remarks are sent trimmed (`applyTransition(..., comment:)`,
  `resetRecord(..., comment:)`, `decide(..., comment:)`), show in the history ("Reject: Review →
  Draft (“Missing transcript”)"), go into the audit log, and steps can use them as "Remarks"
  (`trigger.comment`). `wfRemarksFor`, `wfCommentRequired` and `wfRemarksLabel` give the same
  answers the widgets use.

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
in-memory one, `apps/showcase/lib/pages/workflow_demo_api.dart`). It has the same calls as the REST
client; a few are optional or only needed by some widgets:

- `resetPreview` (optional): lists what a reset would take back. Throw `UnimplementedError` when
  there is no such list; the reset dialog then only asks for confirmation.
- `updatePermissions`: needed by `UiWorkflowPermissions` to save.
- `me` (optional): who is signed in and what they may do. `UiWorkflowApi.me()` has a default that
  answers null ("not known"); a class that `extends UiWorkflowApi` can leave it out, and one that
  `implements` it can return null. Without an answer the builder and the permissions page offer
  editing and the server decides, showing its answer if it refuses.

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
| `readOnly` | `bool?` | Look without changing anything; null asks `api.me()` whether the person may edit. Shows "View only", hides Save, Publish, Versions and Test, the palette, the + slots, grips and step menus; cards still open in the inspector, whose fields are turned off, and the controller ignores edits. Viewers never count as unsaved, and nothing is checked by the engine or loaded (settings) until `me()` has answered, and never for viewers. |
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
- The duration editor's unit select keeps 108 (direction 96) rather than the web's 88 (76): this select's
  padding and chevron need it to show "minutes" whole. On touch the amount has no steppers (48-wide
  touch steppers don't fit a 64–96 box; a number keyboard takes their place).
- Autosized text areas refit to their width with no extra code (Flutter lays text out per width).
- `me` is optional through a default method on `UiWorkflowApi` that answers null (Dart has no
  optional interface members); `extends UiWorkflowApi` inherits it.
- The tasks drawer pauses polling on `AppLifecycleState` (the app in the background), the web on
  the page's visibility.
- In the reset list a warning is read with its checkbox through the checkbox's semantic label (the
  web adds visually hidden text inside the label).
- "Create record" says the kind is unknown only once the registry has loaded (the web also says it
  while there is no registry yet).

## My tasks drawer (UiWorkflowTasksDrawer)

A "My tasks" button for an app's header. It shows how many tasks are open for the signed-in person
(`api.tasks(UiWfTaskQuery(scope: 'mine', status: ['open'], take: 100))`) and opens the task inbox
(`UiWorkflowTasks`) in a `UiDrawer` titled with the button's label.

- The badge is primary, danger when any open task is overdue, absent at 0, and reads `99+` above 99.
- Screen readers hear the label and the count: "My tasks, 3 open, 1 overdue" or "My tasks, none open".
- One count reads at most 100 open tasks. When more are open, the overdue number is "at least":
  screen readers hear "My tasks, 250 open, 100+ overdue".
- The count refreshes on start, when the API changes, when the drawer opens and closes, after a
  decision in the drawer, and every `refreshSeconds` while the app is in the foreground. Polling
  pauses while it is in the background (`AppLifecycleState` hidden or paused, the web's hidden page)
  and counts again as soon as it comes back. A slower, older answer never overwrites a newer one,
  and an error keeps the last count instead of showing 0.
- `hide()` closes the drawer's own route, even when a dialog (a decision) is open on top of it.

```dart
// In the app bar.
UiWorkflowTasksDrawer(api: api, onDecided: (_) => reloadPage())

// Opened by your own control: the drawer follows `open` and reports changes (the web `[(open)]`).
UiWorkflowTasksDrawer(
  api: api,
  showButton: false,
  open: tasksOpen,
  onOpenChanged: (v) => setState(() => tasksOpen = v),
)

// Or through a GlobalKey.
final drawer = GlobalKey<UiWorkflowTasksDrawerState>();
UiWorkflowTasksDrawer(key: drawer, api: api);
drawer.currentState!.show();     // also hide() and refresh(); isOpen, count, overdue, polling
```

| Option | Type | Default | |
| --- | --- | --- | --- |
| `api` | `UiWorkflowApi?` | | Nothing loads while it is null. |
| `open` | `bool?` | null | Whether the drawer is open, when the host controls it; null leaves it to the button. |
| `onOpenChanged` | `ValueChanged<bool>?` | | When it opens (button, `open` or `show()`) or closes (any way). |
| `label` | `String` | `'My tasks'` | The button's and the drawer's title. |
| `side` | `UiDrawerSide` | `right` | The edge the drawer comes from. |
| `size` | `UiSize` | `sm` | The button's size. |
| `variant` | `UiButtonVariant` | `outline` | The button's look. |
| `showButton` | `bool` | `true` | Off when the app opens the drawer from its own control. |
| `refreshSeconds` | `int` | `60` | How often the count refreshes while the app is in the foreground; 0 only on start, open, close and decisions. |
| `pageSize` | `int` | `25` | Tasks per page in the inbox. |
| `onDecided` | `ValueChanged<UiWfTask>?` | | After a task was decided in the drawer. |

There is no read-only mode: the inbox shows only the person's own tasks, and a task they may not
decide (`canDecide` false) is listed without "Your turn" and can't be opened, as in `UiWorkflowTasks`.

## Permissions (UiWorkflowPermissions)

One settings page for who may do what in every published, non-archived workflow (sorted by title):
who may make each lifecycle move, start a record over, press a start button, and decide each approval
or task. Each row is edited with the builder's assignees editor. Saving publishes a new version that is
the current one plus only those changes, so admins can change people without opening the builder.

- `permissionRows(def)` lists the rows in reading order:
  - lifecycle moves, except hidden ones, which are never offered to anyone (detail "From → To";
    "Any state" for `from: '*'`). Automatic moves stay: the engine still offers them by hand, early,
    to the people in their `who`;
  - the reset (node `reset`, detail "Back to <state>");
  - a manual trigger (node `trigger`, label "“<label>” button");
  - approval and task steps (node = step id, detail = the step type's label).
- An empty "who" says what it means for each kind of row (`emptyWhoText(kind)`): a start button,
  "Anyone who can see the record."; a move, "Nobody by hand: only automatically, or from other
  workflows."; the reset, "Nobody."; a step, "Nobody yet." (in the editor: "add the people who
  decide", since the engine refuses an approval or task nobody can decide).
- Changed rows are marked with a bar on the left, and screen readers hear "Changed". Setting a row
  back to the published value is no longer a change, in any order (`sameWho`: chip order and key
  order don't count).
- Each workflow's footer has a note ("Why", kept with the version), Undo (which also clears the
  note) and "Save N changes".
  - An approval or task left with nobody can't be saved: the footer says "Add someone to “…”".
  - Only one save runs at a time, across all workflows.
  - Before saving, the page checks that the published version is still the one it loaded. If
    someone else published since, it says so and offers Reload instead of overwriting their change.
  - After saving, the definition is reloaded, "Saved: version N is now in use." shows, and `onSaved`
    fires. Once published, the changes are never offered again: if the reload fails, the rows show
    what was saved and the note asks to reload for the latest.
  - A refusal from the server shows under the footer and keeps the changes.
- The search field (the library's `UiSearchInput`) filters by workflow title (all its rows) or by a
  row's label or detail; rows with unsaved edits always stay, so every counted change is visible.
- Rows stack (label above editor) below 560 wide.
- Without an API the page says "No workflow API is connected" rather than "nothing is published".

```dart
UiWorkflowPermissions(api: api, onSaved: (summary) => refresh())

// The rows for your own page:
for (final row in permissionRows(def)) print('${row.label}: ${row.detail}');
```

| Option | Type | |
| --- | --- | --- |
| `api` | `UiWorkflowApi?` | Loads `definitions()`, `schema()`, `me()` and each `definition(id)`; saves with `updatePermissions`. `me` is optional: without an answer, editing is offered and the server decides. |
| `onSaved` | `ValueChanged<UiWfDefinitionSummary>?` | After a workflow's permissions were saved (the new version's summary). |

Saving calls
`api.updatePermissions(id, [(node: 't1', who: [UiWfAssignee.role('head')])], note: 'Heads only')`,
which the HTTP client sends as `POST /definitions/{id}/permissions`:

```json
{ "changes": [{ "node": "t1", "who": [{ "role": "head" }] }], "note": "Heads only" }
```

`node` is a transition or step id, `reset` or `trigger`; `note` is null when empty. The engine
publishes a new version and applies the same changes to the draft, if there is one.

Read-only: when `me().canPublish` is false, every row shows its people as a sentence (for example
"Ana Lee and Head of office", with people named, looked up once each with `api.user`) instead of an
editor, and the page says "You can see who may do what; changing it
needs the right to publish workflows." There are no Save buttons. If `me()` fails, editing is offered
and the server's answer decides.
