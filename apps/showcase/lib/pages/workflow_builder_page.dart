import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'workflow_demo_api.dart';

/// The workflow page: the builder, the record panel, the task inbox, the run view, the audit log
/// and the settings screen, all on an in-memory engine so the page works offline.
class WorkflowBuilderPage extends StatefulWidget {
  const WorkflowBuilderPage({super.key});

  @override
  State<WorkflowBuilderPage> createState() => _WorkflowBuilderPageState();
}

class _WorkflowBuilderPageState extends State<WorkflowBuilderPage> {
  final DemoWorkflowApi _api = DemoWorkflowApi();
  late UiWorkflowDefinition _def = createWorkflow('automation', title: 'Remind reviewers', entity: 'application');
  String _kind = 'automation';
  int _epoch = 0;
  String _exported = '';

  void _setKind(String kind) => setState(() {
    _kind = kind;
    _def = switch (kind) {
      'lifecycle' => DemoWorkflowApi.statusLifecycle(),
      'finance' => DemoWorkflowApi.financeCheck(),
      _ => createWorkflow('automation', title: 'Remind reviewers', entity: 'application'),
    };
  });

  void _reset() => setState(() {
    _api.reset();
    _epoch++;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final size = MediaQuery.sizeOf(context);
    final phone = size.width < 720;
    Widget panel(Widget child) => Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: EdgeInsets.all(t.space3),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: child,
    );

    return DocPage(
      eyebrow: 'Flagship',
      title: 'Workflow builder',
      lead: 'Admins design workflows without code. Automations start when a record changes (a field becomes a value, a date comes up, a '
          'schedule, a button, an event from your app) and run approvals, waits, branches, parallel paths, loops, messages, record updates '
          'and your own actions. Lifecycles own a status field: states, who may move a record between them, checks, forms, and what runs on '
          'each move. Everything is audited in a tamper-evident log. A .NET engine runs it; the builder reads and writes the same JSON as '
          'the web builder.',
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
          decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: Wrap(spacing: t.space4, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 4, children: [
                UiText('Everything here runs on a pretend engine', variant: UiTextVariant.label),
                UiText(
                  'The demos below use an in-memory scholarship office (an application in review, a finance approval, an audit trail), so they '
                  'work offline. Save, publish, test, decide tasks and move the record; Reset puts it back. The web docs connect the same '
                  'widgets to the real .NET engine in a private sandbox.',
                  color: t.textSecondary,
                ),
              ]),
            ),
            UiButton(label: 'Reset the office', variant: UiButtonVariant.outline, size: UiSize.sm, onPressed: _reset),
          ]),
        ),
        const DocSection(
          name: 'How it fits together',
          widget: 'spec, engine, widgets',
          summary: 'One JSON format (the Zouriel Workflows spec) is written by the builder and run by the engine. Developers register which '
              'records, fields and actions workflows may use; admins only ever choose from that list. The engine checks every change to a '
              'registered record when it is saved and starts workflows through an outbox, so a rolled-back save starts nothing.',
          code: '''// Backend (.NET): Zouriel.Workflows.AspNetCore + Zouriel.Workflows.EntityFrameworkCore
builder.Services.AddWorkflows(wf => wf
    .UseEntityFrameworkCore<AppDb>()
    .Entity<Application>("application", e => e
        .Field(a => a.Status, f => f.LifecycleCapable())
        .Field(a => a.Amount, f => f.Currency().Watchable().Settable()))
    .UseIdentity<AppWorkflowIdentity>()
    .UseNotifications<AppNotificationSender>());
app.MapWorkflowApi("/api/workflows").RequireAuthorization();

// Flutter: one client for every workflow widget
final api = UiWorkflowHttpApi(
  baseUrl: 'https://app.example.com/api/workflows',
  headers: () async => {'Authorization': 'Bearer \${await auth.token()}'},
);''',
        ),
        DocSection(
          name: 'Builder',
          widget: 'UiWorkflowBuilder',
          summary: 'Automations are a trigger card and a list of steps: press + between steps (or drag one in from the left) and branches, '
              'outcomes and parallel paths appear as columns. Drag a step by its grip to move it anywhere, including into another branch; the '
              '… menu also moves, duplicates, turns off or deletes it. Lifecycles are a diagram: drag a state to move it, drag from its handle '
              'onto another state to add a transition (tap the handle, then the target, on touch), and edit what each transition or state runs '
              'underneath. Every change is checked by the engine as you go; Versions publishes and rolls back, Test runs the draft without '
              'changing anything. Below 1100px the palette moves into a dialog, and on phones the settings open in a bottom sheet.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: UiSegmented<String>(
                label: 'Example',
                size: UiSize.sm,
                value: _kind,
                onChanged: _setKind,
                options: const [
                  UiSegmentedOption(value: 'automation', label: 'New automation'),
                  UiSegmentedOption(value: 'finance', label: 'Finance check'),
                  UiSegmentedOption(value: 'lifecycle', label: 'Lifecycle'),
                ],
              ),
            ),
            SizedBox(
              height: phone ? (size.height - 120).clamp(520, 900) : (size.height - 120).clamp(560, 820),
              child: UiWorkflowBuilder(
                key: ValueKey('$_kind$_epoch'),
                definition: _def,
                api: _api,
                persist: true,
                onChanged: (d) => setState(() => _def = d),
              ),
            ),
          ]),
          code: '''UiWorkflowBuilder(
  definition: workflow,              // spec JSON: UiWorkflowDefinition.fromJson(json)
  onChanged: (d) => setState(() => workflow = d),
  published: published,
  api: api,                          // registry, checks, save, publish, test
  persist: true,                     // Save and Publish in its header
  onSaved: (d) => reload(),
)

// Offline: no API, give it the registry yourself.
UiWorkflowBuilder(definition: workflow, schema: UiWorkflowSchema(registry: registry), onChanged: save)''',
          api: const [
            ApiRow('definition', 'UiWorkflowDefinition?', 'The workflow being built (spec JSON). Hand back what onChanged gives; another id clears undo.'),
            ApiRow('controller', 'UiWorkflowBuilderController?', 'Drive it from outside: selection, undo/redo, problems.', def: 'own'),
            ApiRow('published', 'UiWorkflowDefinition?', 'The published version; locks the record type.', def: 'null'),
            ApiRow('api', 'UiWorkflowApi?', 'The engine API (UiWorkflowHttpApi, or your own).', def: 'null'),
            ApiRow('schema', 'UiWorkflowSchema?', 'Registry and step outputs, when there is no API.', def: 'null'),
            ApiRow('settings', 'UiWorkflowSettings?', 'Global settings (webhook connections), when there is no API.', def: 'null'),
            ApiRow('persist', 'bool', 'Show Save and Publish and save drafts through the API.', def: 'false'),
            ApiRow('actions', 'Widget?', 'Your own buttons at the end of the header.'),
          ],
          callbacks: const [
            ApiRow('onChanged', 'ValueChanged<UiWorkflowDefinition>', 'Every edit, as a new definition (the old one is never changed).'),
            ApiRow('onProblemsChanged', 'ValueChanged<List<UiWfProblem>>', 'The engine’s problems after each check.'),
            ApiRow('onSaved', 'ValueChanged<UiWorkflowDefinition>', 'After a successful save through the API.'),
            ApiRow('save()', 'UiWorkflowBuilderState', 'Saves the draft (creates it the first time). Ctrl/Cmd+S does the same.'),
          ],
        ),
        DocSection(
          name: 'Record panel',
          widget: 'UiWorkflowRecordPanel',
          summary: 'Drop it onto a record’s page: it shows the record’s state, the moves this person may make (with their confirmation or '
              'form), open tasks they can decide, buttons for manual workflows, and the history. This one is the application in the pretend office.',
          demo: panel(UiWorkflowRecordPanel(key: ValueKey('panel$_epoch'), api: _api, entity: 'application', entityId: '1')),
          code: "UiWorkflowRecordPanel(api: api, entity: 'application', entityId: app.id, onChanged: (_) => reloadApp())",
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'The engine API. Nothing loads while it is null.'),
            ApiRow('entity', 'String', 'The record type key, as registered.'),
            ApiRow('entityId', 'String', 'The record id.'),
            ApiRow('showHistory', 'bool', 'Show the record’s workflow history.', def: 'true'),
          ],
          callbacks: const [
            ApiRow('onChanged', 'ValueChanged<UiWfRecord>', 'After a transition was applied through the panel.'),
            ApiRow('reload()', 'state', 'Loads the record again (e.g. after your page changed it).'),
          ],
        ),
        DocSection(
          name: 'Tasks, runs, audit and settings',
          widget: 'UiWorkflowTasks · UiWorkflowRun · UiWorkflowAudit · UiWorkflowGlobalSettings',
          summary: 'The task inbox lists the signed-in person’s approvals and tasks (due first, overdue marked) and opens the decision with '
              'its form. The run view draws one run over its workflow, with retry, skip and cancel for admins (each stopped path on its own '
              'when several stopped). The audit view filters, exports and checks the hash chain. Global settings hold working hours and '
              'holidays, defaults, channels, webhook addresses, audit retention and masking, and pausing per record type.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [
            UiText('Tasks', variant: UiTextVariant.label, color: t.textMuted),
            panel(UiWorkflowTasks(key: ValueKey('tasks$_epoch'), api: _api)),
            UiText('A run', variant: UiTextVariant.label, color: t.textMuted),
            panel(UiWorkflowRun(key: ValueKey('run$_epoch'), api: _api, instanceId: 'run1', canIntervene: true)),
            UiText('Audit log', variant: UiTextVariant.label, color: t.textMuted),
            Container(
              constraints: const BoxConstraints(maxWidth: 720),
              child: UiWorkflowAudit(
                key: ValueKey('audit$_epoch'),
                api: _api,
                entity: 'application',
                entityId: '1',
                onExport: (bytes, format) => setState(() => _exported = 'Exported ${bytes.length} bytes of $format.'),
              ),
            ),
            if (_exported.isNotEmpty) UiText(_exported, color: t.textMuted),
            UiText('Global settings', variant: UiTextVariant.label, color: t.textMuted),
            SizedBox(height: 560, child: UiWorkflowGlobalSettings(key: ValueKey('settings$_epoch'), api: _api)),
          ]),
          code: '''UiWorkflowTasks(api: api, onDecided: (_) => refresh())              // my approvals and tasks
UiWorkflowRun(api: api, instanceId: runId, canIntervene: isAdmin)
UiWorkflowAudit(api: api, entity: 'application', entityId: app.id,
    onExport: (bytes, format) => saveFile('audit.\$format', bytes))
UiWorkflowGlobalSettings(api: api)                                 // your settings page''',
          api: const [
            ApiRow('UiWorkflowTasks', 'api, scope, pageSize, onDecided', "scope 'mine' or 'all' (admins); pageSize 25; Show more loads the next page."),
            ApiRow('UiWorkflowRun', 'api, instanceId, canIntervene, onChanged', 'canIntervene shows Try again, Skip and Cancel (needs the permission on the server).'),
            ApiRow('UiWorkflowAudit', 'api, entity, entityId, instanceId, pageSize, onExport', 'onExport gets the CSV bytes; the button shows only when it is set (there is no browser download on a phone).'),
            ApiRow('UiWorkflowGlobalSettings', 'api, registry, settings, onSettingsChanged', 'With an API it loads and saves (with a revision check); without one it edits settings and reports them.'),
            ApiRow('UiWorkflowStateBadge', 'label, tone', 'A state as a small coloured chip.'),
          ],
        ),
        const DocSection(
          name: 'Working with definitions in code',
          widget: 'definition helpers',
          summary: 'The helpers the builder uses are exported for apps that generate or inspect workflows. Every type is a typed view over '
              'the JSON itself, so unknown keys survive a round trip, and every helper returns a new definition. The lifecycle layout is '
              'deterministic and identical to the web library’s: both run the same fixtures.',
          code: '''final def = createWorkflow('automation', title: 'Remind reviewers', entity: 'application');
var next = insertStep(def, 'root', 0, createStep('approval'));
final where = indexSteps(next);                     // every step with its list, parent and path
final tokens = tokensAt(next, registry, at: UiWfAt.step(stepId));   // what a step can read
final words = describeTrigger(next.trigger, UiWfDescribeContext(registry: registry, def: next));
final layout = autoLayout(lifecycle.lifecycle!);    // positions of a lifecycle's states
final json = next.toJson();                         // store it as it is''',
        ),
      ],
    );
  }
}
