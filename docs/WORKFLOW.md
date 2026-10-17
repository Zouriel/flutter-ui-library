# Workflow builder (Dart)

The Flutter port of `@zouriel/ui/workflow` (see `projects/ui/workflow/README.md` in the Angular
repo): a builder where admins design workflows without code, and the widgets that run them in
your app: a workflow panel (with the record's running and stopped workflows), a My tasks drawer, an
audit log, a permissions page and a settings screen. Workflows
are JSON in the Zouriel Workflows format, run by an engine on your server (the .NET engine first;
Laravel and Go engines follow the same spec and REST API).

Code: `packages/zouriel_ui/lib/src/workflow/` (and `lib/src/canvas/viewport.dart`), exported by
`lib/src/areas/workflow.dart`, so everything comes from `package:zouriel_ui/zouriel_ui.dart`.

```dart
UiWorkflowBuilder          // where admins design workflows
UiWorkflowPanel            // a record's workflow: a stepper, a compact card or an edge drawer
UiWorkflowTasksDrawer      // a "My tasks" button with a count, where people decide their tasks
UiWorkflowAudit            // the tamper-evident log: filter, export, verify
UiWorkflowGlobalSettings   // working hours, channels, webhooks, retention
UiWorkflowPermissions      // who may do what in every published workflow
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
  "Starting over"; `UiWorkflowPanel` (in every layout) shows the button to those allowed
  (`record.reset`, `api.resetRecord`).
  "Offer it" (`reset.states`) limits it to some states: from a state you pick onwards (that state
  and every state after it, final states included: `wfStatesFrom(def, stateId)`), with a checklist
  to adjust. Without it the reset is offered in every state where it would change something.
  The reset dialog lists what the workflow did since the record last started over
  (`api.resetPreview`): fields it changed on this or other records, records it created, other
  records it moved ("Move"), actions, messages and webhooks. Everything that can be undone is ticked,
  except items someone changed again since, which start unticked; sent messages, webhooks and moves
  can't be taken back (a move comes with a warning: start that record over instead). People untick
  anything that should stay; the ticked ids go to `resetRecord(..., undo: [...])`, which deletes
  created records, puts fields back and undoes app actions when the app supports it. The reset
  can't be confirmed until the list has arrived; an empty list says "Nothing the workflow did needs
  taking back." If someone changed what the workflow did in the meantime, the engine refuses with
  `resetChanged` and the dialog reads the list again, keeping the person's ticks for the items still
  listed. The list comes with a `token` (`UiWfResetPreview.token`) that goes back with the reset
  (`resetRecord(..., token:)`), so a list that changed since it was read fails with `resetChanged`
  instead of overwriting; the token is dropped whenever the list is cleared or read again, and older
  engines that send none are still reset without one. `UiWorkflowHttpApi.resetPreview` always asks the engine (`GET /records/{entity}/{id}/reset`);
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

- `resetPreview` (optional, the web `resetPreview?`): lists what a reset would take back. Its default
  throws `UnimplementedError`, so a class that `extends UiWorkflowApi` can leave it out (one that
  `implements` it throws `UnimplementedError` itself); the reset dialog then only asks for
  confirmation.
- `updatePermissions`: needed by `UiWorkflowPermissions` to save.
- `me` (optional): who is signed in and what they may do. `UiWorkflowApi.me()` has a default that
  answers null ("not known"); a class that `extends UiWorkflowApi` can leave it out, and one that
  `implements` it can return null. Without an answer the builder and the permissions page offer
  editing and the server decides, showing its answer if it refuses.

The engine's refusals reach people through the usual error text (`UiWfApiError.message`), with no
special screens: `wrongLifecycle` (409, the record follows another lifecycle), `commentRequired`
(400, remarks the move or reset requires), `notAllowed` (a reset outside the states it is offered
in), `resetChanged` (409, the list changed) and a reset list refused because no reset is offered
(the dialog then says the list couldn't be read).

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
picker type drags after a long press on touch and after a small move with a mouse; Escape cancels a
drag ("Move cancelled"), and a drop lands only on a list that can be seen (not one scrolled out of
view under the header). The grip shows when a card is hovered or selected (always on touch); read-only
hides grips and menus but keeps their room. Only a tap on the canvas background opens the workflow's
settings. On a phone the settings sheet keeps Delete and the "‹ parent" link for states, transitions,
the reset and their steps.

The lifecycle diagram sits on `UiCanvasViewport` (pan, pinch, wheel and trackpad zoom, `+` `-` `0`,
and a minimap when it is at least 520x340), which keeps fitting the diagram until the person pans or
zooms (a refit that comes up mid-drag waits for the pointer to lift) and never fits below 60%
(`fitMinZoom`): a larger diagram starts at its top-left corner and the minimap shows the rest.

## Running workflows in your app

The showcase's **Workflow components** page (`apps/showcase`, `#/workflow-components`; the old
`#/workflow-panel` opens it too) shows each of these live on the in-memory office, with when to use
it, a snippet and its parameters, and a "You are" / "Application" picker so you can see what each
person gets: the head of office sees every button (Start over once an application has moved on from
Draft), the applicant only their own moves, finance only the sign-off. "Show a stopped payment"
reproduces a payment the bank refused: with the demo bank down (the engine sample's
`POST /api/demo/bank {down}`; in the in-memory office, `DemoWorkflowApi.stopPayment`, which does it
in one go without changing who the page acts as), finance signs the application off, Create invoice
fails with "Bank API: 503 Service Unavailable" four times as the clock moves on, and the run stops;
the panel shows it under Running, and the bank is back by then. Start over, or approving or rejecting
the application, cancels its finance check. "Send another application for review" starts another
application's finance sign-off, so finance has a task again.

```dart
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, onChanged: (_) => reloadApp())
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.compact, title: '')
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.sideDrawer)
UiWorkflowTasksDrawer(api: api, onDecided: (_) => refresh())
UiWorkflowTasksDrawer(api: api, scope: 'all', label: 'All tasks') // everyone's, for admins
UiWorkflowAudit(api: api, entity: 'application', entityId: app.id, onExport: (bytes, format) => save(bytes))
UiWorkflowGlobalSettings(api: api)
```

`UiWorkflowPanel` is the record's workflow to attach to its page, like the web `ui-workflow-panel`:
the states as a stepper (green for passed, dark for not reached), what happened in each, and in the
current state the person's moves, tasks and manual workflows (or "Nothing for you to do here right
now."). `layout` picks `vertical`, `horizontal`, `compact`, `sideDrawer` or `bottomDrawer`. The drawer
layouts put a rail of dots on the screen's edge through the overlay, wherever the widget sits: a
mouse hover opens a `UiDrawerPeek` over the page (moving away closes it), a tap opens a regular
`showUiDrawer`. The host can open and close it with `open` and follow it with `onOpenChanged` (the web
`[(open)]`). Switching to another record drops the old one at once (no stale buttons while the new one
loads); a load error shows the engine's message with its details.

In the current state, a task opens the decide dialog: instructions, the form, remarks, earlier
decisions as a bulleted list, and "Hand it to someone else", one combobox that searches the directory
as a name is typed (people already on the task aren't offered), then Hand over. While a decision is
on its way Close, the backdrop, Escape and Back wait. Start over sits under a dashed rule.

`compact` is for a side column or a details card: the state as a badge with "since" (and "Out of
sync" when it is), a strip of the lifecycle's states (the current one filled, passed ones in a
stronger grey), the moves, tasks and manual workflows, and one flat history, newest first ("Nothing
yet." when empty). The panel's own gap (`space2`) is the only spacing between those blocks. An empty
`title` hides the heading in any in-page layout.

A record type with no lifecycle shows that same body in every layout: "No lifecycle for this record
type.", then its manual workflows and open tasks (with no "nothing to do" text), then the history. A
drawer's rail keeps one dot (named by the title) so it can still open.

**Breaking (0.27.0):** `UiWorkflowRecordPanel` is removed. Use
`UiWorkflowPanel(layout: UiWorkflowPanelLayout.compact)`, which shows what it did: the badge, the
strip of states, the moves, tasks and manual workflows, and the history (`title: ''` hides the
panel's heading). Its `onChanged` is the same; its `reload()` is on `UiWorkflowPanelState`.

**Running and stopped workflows.** Under "Running" the panel lists the record's workflows still
going (`record.instances` with status queued, running, waiting or incident), stopped ones first.
Each row shows its status, its title, and why it stopped (the readable error) or "since …"; tapping
it opens the run's steps (the internal `WfRunView`, without its own heading), and changes made there
reload the panel. A stopped run opens by itself the first time the panel sees it, so what to do is
in view. The section comes after the actions in `compact` (and for record types with no lifecycle)
and `horizontal`, and inside the active step, after the actions, in `vertical`.

In the run view, people the engine lets intervene (`me().canIntervene`) can:
- **Try again**;
- **Skip the step**: a dialog asks for what the step would have produced (for an app action, its
  outputs as the registry declares them, with their labels); only filled values are sent, trimmed
  (`skip(id, outputs:, target:)`);
- **Cancel the run**: a confirmation with "Remarks (optional)" (`cancel(id, reason:)`).
In both dialogs Back and the confirm button wait while the answer is on its way, and a double tap on
Skip opens one dialog. Everyone else sees why it stopped and "Someone who looks after workflows can try it again or skip
it." Summaries (the "Stopped:" line, the panel's rows, the drawer's list) read the error through
`wfReadableError`, which drops the engine's exception type ("InvalidOperationException: Bank API:
503" reads "Bank API: 503"); a step's own detail keeps the full text for whoever debugs it.

**Panel reads.** The panel reads 500 history entries ("Showing the latest 500 entries." when that many
came back) and "The history could not be loaded." when that read fails; a failed reload shows over the
record still shown, with Try again. `onChanged` fires after any reload that finds a new state, status or
run status. While a run is queued, running or waiting it looks again every 15 s (only while the app is in
the foreground). The vertical layout folds what happened before the latest reset into "Earlier, before
starting over (n)". The runs section reads "Stopped" when every listed run stopped.

**Forms and remarks.** Decisions, moves, resets and manual starts send the form's submitted answers
(defaults and prefilled values included); picked files with no upload address are refused. Remarks are
trimmed and capped at 2,000 characters, with "n / 2,000" from 1,800. Skip asks each registry output in
its own type and requires the required ones. The audit log offers no export for one run.

**Stuck timers (spec §10).** A timer that keeps failing (a lifecycle's automatic move or time limit,
a task's reminder or escalation) puts its instance in `incident` with an `error`, record instances
included; Try again re-arms it (due now) and Skip drops it unrun. A run or instance needs attention
exactly when its status is `incident`. The readable error names the timer by its purpose ("An
automatic move failed 10 times…", "A time limit…", "A reminder…", "An escalation…", else "A
timer…"). In the run view such an incident offers Try again and Skip (confirmed: "Skip the
automatic move", button "Skip it", no results asked), and Cancel for runs only; a record instance
has no step list. When `record.status` is `incident` the panel shows a "Needs attention" warning
with `record.error`; people who may intervene (`me()` is asked only then) get Try again and Skip for
the record's lifecycle instance (looked up with `instances(entity, entityId, kind: ['record'],
status: ['incident'])`), others read that someone who looks after workflows has been told. The
record's moves stay offered. The tasks drawer's stopped workflows include record instances and
lifecycle runs, named "workflow · record".

**Breaking (0.28.0):** `UiWorkflowRun` is removed from the public API. Runs show where they matter:
in `UiWorkflowPanel`'s Running section (a record's workflows) and in the tasks drawer's Stopped
workflows (for people who may intervene). The view itself is the internal `WfRunView`.

**Breaking (0.27.0):** `UiWorkflowTasks` is removed from the public API: the tasks drawer is where
people work through their tasks. Use `UiWorkflowTasksDrawer` (with `scope: 'all'` for everyone's
tasks); the list inside it is the internal `WfTaskInbox`.

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
- The record actions' dialogs are routes on the navigator, so closed ones never take room in the
  panel's column (the web hides their empty host elements).

## My tasks drawer (UiWorkflowTasksDrawer)

Where people work through their approvals and tasks: a "My tasks" button for an app's header. It
shows how many tasks are open (`api.tasks(UiWfTaskQuery(scope: scope, status: ['open'], take: 100))`)
and opens them in a `UiDrawer` titled with the button's label: due first and overdue marked, open or
finished, each opening its decision. `scope` is `'mine'` (the signed-in person's) or `'all'`
(everyone's, for admins; give it a label such as "All tasks"); the count follows it.

For people the engine lets intervene (`me().canIntervene`, asked once per API), the drawer also
loads stopped workflows (`api.instances(UiWfInstanceQuery(status: ['incident'], take: 100))`). The
badge counts open tasks plus stopped workflows and turns danger when anything is overdue or stopped;
screen readers hear ", 1 stopped workflow" after the tasks. Inside, a "Stopped workflows" section
sits above the tasks, with a hint and a row per run (title · record, and the readable error);
tapping one shows its run view with "‹ Back to the list", and trying again, skipping or cancelling
counts again.

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
| `pageSize` | `int` | `25` | Tasks per page in the drawer's list. |
| `scope` | `String` | `'mine'` | The signed-in person's tasks (`'mine'`), or everyone's (`'all'`, for admins; give it a `label` such as "All tasks"). The count follows it, and the empty list is worded for it ("No open tasks."). |
| `onDecided` | `ValueChanged<UiWfTask>?` | | After a task was decided in the drawer (read when it happens, so a new callback from the host is used). |

The open drawer follows the host: another `api`, `scope` or `pageSize` reaches its list. `hide()`
closes a decision dialog open over it too, and the drawer closes when the widget goes away. A task the
person may not decide (`canDecide` false, e.g. someone else's with scope `'all'`) still opens, with its
decision buttons off. While a decision is on its way its dialog can't be closed, and a decision saved
after the dialog was taken away still reloads the list.

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
  - After saving, the definition is reloaded, a message says what the save did, and `onSaved`
    fires. `updatePermissions` answers a `UiWfPermissionsSummary`: the summary plus `changed`,
    `draftSkipped` (node ids) and `recordsMoved`. The message reads "Nothing changed: version N stays
    in use." when `changed` is false; otherwise "Saved: version N is now in use", with ", and M
    existing records follow it" when records moved onto it, then "Your draft no longer has “…”, so
    the draft kept it as before." when the draft no longer has a changed row. Once published, the changes are never offered again: if the reload fails, the rows show
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
