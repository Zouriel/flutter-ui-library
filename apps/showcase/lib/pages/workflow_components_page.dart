import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'registry.dart';
import 'workflow_demo_api.dart';

/// The workflow components page (the web `/workflow-components`): every widget an app puts on its own
/// pages once workflows run, each with a live demo on the in-memory engine, when to use it, a snippet
/// and its parameters. One picker ("You are", "Application") drives every demo.
class WorkflowComponentsPage extends StatefulWidget {
  const WorkflowComponentsPage({super.key});

  @override
  State<WorkflowComponentsPage> createState() => _WorkflowComponentsPageState();
}

/// Who the demos act as when the page opens: the head of office, who sees every button.
const String _defaultUser = 'hana';

class _WorkflowComponentsPageState extends State<WorkflowComponentsPage> {
  final DemoWorkflowApi _api = DemoWorkflowApi();
  UiWorkflowPanelLayout _layout = UiWorkflowPanelLayout.vertical;
  String _user = _defaultUser;

  /// An application past Draft, so Start over shows to the head of office.
  String _appId = '1';
  int _settingsTab = 0;

  /// Bumped after something changed, so the lists and views elsewhere on the page load again.
  int _rev = 0;

  /// Bumped when the page itself changes the application (Show a stopped payment, Reset), so the
  /// panel is drawn again; the panel's own changes it shows already.
  int _panelRev = 0;
  bool _busy = false;
  String _prepError = '';

  /// Whether the picked application's finance sign-off is still open, so its payment can be made to fail.
  bool get _stoppable => _appId == '1' && _api.signOffOpen;

  /// The scenario from the docs: with the demo bank down, finance signs this application off.
  /// Creating the invoice fails; after its retries (the clock moved on 5 minutes, four times) the run
  /// stops and the panel shows it under Running. The bank is switched back on, so Try again works.
  Future<void> _stopPayment() async {
    if (!_stoppable || _busy) return;
    final who = _api.actingAs;
    setState(() {
      _busy = true;
      _prepError = '';
    });
    _api.bankDown = true;
    try {
      // Everyone with a sign-off on it approves.
      for (final u in DemoWorkflowApi.people) {
        _api.actingAs = u.id;
        final open = (await _api.tasks(const UiWfTaskQuery(scope: 'mine', status: ['open']))).items;
        for (final task in open.where((x) => x.canDecide && x.kind == 'approval' && x.entityId == _appId)) {
          await _api.decide(task.id, 'approved', comment: 'Signed off.');
        }
      }
      for (var i = 0; i < 4; i++) {
        _api.advance(const Duration(minutes: 5));
      }
    } catch (e) {
      _prepError = 'Couldn’t stop a payment: ${e is UiWfApiError ? e.message : e}';
    } finally {
      _api.bankDown = false;
      _api.actingAs = who;
      if (mounted) {
        setState(() {
          _busy = false;
          _rev++;
          _panelRev++;
        });
      }
    }
  }

  final Map<String, GlobalKey> _anchors = {
    for (final a in ['panel', 'tasks-drawer', 'audit', 'state-badge', 'permissions', 'global-settings', 'settings-page']) a: GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _api.actingAs = _user;
  }

  void _changed() => setState(() => _rev++);

  void _setUser(String id) => setState(() {
    _user = id;
    _api.actingAs = id;
    _rev++;
  });

  void _jump(String anchor) {
    final c = _anchors[anchor]?.currentContext;
    if (c != null) Scrollable.ensureVisible(c, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
  }

  Key _k(String what, {bool live = true}) => ValueKey('$what-$_user-$_appId${live ? '-$_rev' : ''}');

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget frame(Widget child, {double? maxWidth, double? height}) => Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity, maxHeight: height ?? double.infinity),
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: child,
    );
    Widget note(String text) => UiText(text, color: t.textSecondary);
    final app = _api.applications.firstWhere((a) => a.id == _appId);
    final drawer = _layout == UiWorkflowPanelLayout.sideDrawer || _layout == UiWorkflowPanelLayout.bottomDrawer;

    return DocPage(
      eyebrow: 'Flagship',
      title: 'Workflow components',
      lead: 'Everything an app puts on its own pages once workflows run: a record\'s workflow on the record\'s page, a tasks drawer in the '
          'header, run and audit views for admins, and the pieces of a workflow settings page. Each one talks to the engine '
          'through the workflow API, and each person only sees what they may do.',
      children: [
        _Where(onJump: _jump, onBuilder: () => ShowcaseNav.maybeOf(context)?.go('workflow-builder')),
        SizedBox(height: t.space4),
        Container(
          padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3),
          decoration: BoxDecoration(color: t.surfaceRaised, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            Wrap(spacing: t.space3, runSpacing: t.space2, children: [
              SizedBox(
                width: 300,
                child: UiSelect(
                  label: 'You are',
                  size: UiSize.sm,
                  value: _user,
                  options: [for (final u in DemoWorkflowApi.people) UiSelectOption(value: u.id, label: '${u.name} · ${u.title}')],
                  onChanged: (v) => _setUser(v),
                ),
              ),
              SizedBox(
                width: 340,
                child: UiSelect(
                  label: 'Application',
                  size: UiSize.sm,
                  value: _appId,
                  options: [for (final a in _api.applications) UiSelectOption(value: a.id, label: '${a.title} (${a.stateLabel})')],
                  onChanged: (v) => setState(() {
                    _appId = v;
                    _rev++;
                  }),
                ),
              ),
            ]),
            note('Every demo below acts as this person, on this application, in the in-memory office. Start over shows to the head of office '
                'once an application has moved on from Draft.'),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: UiButton(
                label: 'Reset the office',
                size: UiSize.sm,
                variant: UiButtonVariant.ghost,
                onPressed: () => setState(() {
                  _api.reset();
                  _rev++;
                  _panelRev++;
                }),
              ),
            ),
          ]),
        ),
        DocSection(
          key: _anchors['panel'],
          name: 'Workflow panel',
          widget: 'UiWorkflowPanel',
          summary: 'The record\'s workflow on the record\'s own page: its states as a stepper (green for states it has been through), what '
              'happened in each, and in the current state the moves this person may make, with their forms and confirmations, open tasks '
              'and manual workflows. Use it when the workflow is part of the page\'s story; choose a vertical or horizontal panel, a compact '
              'one for a side column or details card (a badge with a strip of states, the actions and one history), or a drawer that waits '
              'on the screen\'s edge as a rail of dots when the page is busy. A record type with no lifecycle still shows its manual '
              'workflows, open tasks and history. Under Running it lists the record\'s workflows still going, each opening its steps; one '
              'that stopped (a payment the bank refused, say) opens by itself, and people who may intervene try it again, skip the step '
              'giving what it would have produced, or cancel it, right there.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiButton(label: 'Show a stopped payment', size: UiSize.sm, variant: UiButtonVariant.outline, loading: _busy, onPressed: _stoppable && !_busy ? _stopPayment : null),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: note(_stoppable
                    ? 'Has finance sign this application off while the demo bank is down: the payment fails, and the panel shows it under '
                          'Running with Try again, Skip and Cancel (the bank is back by then).'
                    : 'The finance sign-off has been decided: Reset the office (above) to show a stopped payment again.'),
              ),
            ]),
            if (_prepError.isNotEmpty) UiText(_prepError, color: t.danger),
            UiSegmented<UiWorkflowPanelLayout>(
              label: 'Layout',
              size: UiSize.sm,
              value: _layout,
              onChanged: (v) => setState(() => _layout = v),
              options: const [
                UiSegmentedOption(value: UiWorkflowPanelLayout.vertical, label: 'Vertical'),
                UiSegmentedOption(value: UiWorkflowPanelLayout.horizontal, label: 'Horizontal'),
                UiSegmentedOption(value: UiWorkflowPanelLayout.compact, label: 'Compact'),
                UiSegmentedOption(value: UiWorkflowPanelLayout.sideDrawer, label: 'Side drawer'),
                UiSegmentedOption(value: UiWorkflowPanelLayout.bottomDrawer, label: 'Bottom drawer'),
              ],
            ),
            if (drawer) ...[
              note('The panel is on the ${_layout == UiWorkflowPanelLayout.sideDrawer ? 'right edge' : 'bottom edge'} of the screen as a rail '
                  'of dots: one per state, green up to where the application is now. Hover it with a mouse to peek, or tap it to open the drawer.'),
              UiWorkflowPanel(key: _k('panel-${_layout.name}-$_panelRev', live: false), api: _api, entity: 'application', entityId: _appId, layout: _layout, title: 'Application workflow', onChanged: (_) => _changed()),
            ] else
              frame(
                UiWorkflowPanel(key: _k('panel-${_layout.name}-$_panelRev', live: false), api: _api, entity: 'application', entityId: _appId, layout: _layout, title: 'Application workflow', onChanged: (_) => _changed()),
                maxWidth: _layout == UiWorkflowPanelLayout.horizontal ? null : 460,
              ),
          ]),
          code: '''// on the record's page
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, onChanged: (_) => reload())

// states left to right, details below
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.horizontal)

// a side column: a badge with a strip of states, the actions and one history (title: '' hides the heading)
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.compact, title: '')

// a rail of dots on the right edge; hover (desktop) or tap opens the drawer
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.sideDrawer)

// a rail of dots along the bottom
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.bottomDrawer)''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'The engine. Nothing loads while it is null.'),
            ApiRow('entity', 'String', 'The record type key, as registered.'),
            ApiRow('entityId', 'String', 'The record id.'),
            ApiRow('layout', 'UiWorkflowPanelLayout', 'vertical, horizontal, compact, sideDrawer or bottomDrawer.', def: 'vertical'),
            ApiRow('side', 'UiDrawerSide', 'Which edge the side drawer opens from (left or right).', def: 'right'),
            ApiRow('title', 'String', 'The heading (and the drawer title); empty hides the heading.', def: "'Workflow'"),
            ApiRow('showHistory', 'bool', 'Show what happened in each state.', def: 'true'),
            ApiRow('emptyText', 'String', 'Said when the person has nothing to do in the current state; empty hides it.', def: "'Nothing for you to do here right now.'"),
          ],
          callbacks: const [ApiRow('onChanged', 'ValueChanged<UiWfRecord>', 'After the record moved through the panel, so the page can reload its own data.')],
        ),
        DocSection(
          key: _anchors['tasks-drawer'],
          name: 'My tasks drawer',
          widget: 'UiWorkflowTasksDrawer',
          summary: 'Where people work through their approvals and tasks: a button for the app\'s header with the number open (red when one '
              'is overdue) that opens them in a drawer, open or finished, each opening its decision with its form. People act from any page; '
              'open it from code too, for a link in a message or a shortcut. With scope \'all\' it lists everyone\'s tasks, for admins. '
              'People who may intervene also find stopped workflows here, counted in the badge (red) and listed above the tasks, each '
              'opening its steps with try again, skip and cancel.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space2),
              decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: Row(children: [
                Expanded(child: UiText('Scholarship office', variant: UiTextVariant.label)),
                UiWorkflowTasksDrawer(key: _k('drawer'), api: _api, onDecided: (_) => _changed()),
              ]),
            ),
            note('The finance sign-off is Mariyam\'s (finance); checking the transcript is Hana\'s. Pick “You are” to see each person\'s count; '
                'the applicant has none.'),
          ]),
          code: '''// in the app bar
UiWorkflowTasksDrawer(api: api, onDecided: (_) => reload())

// your own button, or a link in a message
UiWorkflowTasksDrawer(api: api, showButton: false, label: 'Approvals',
    open: tasksOpen, onOpenChanged: (v) => setState(() => tasksOpen = v))

// everyone's tasks, for admins
UiWorkflowTasksDrawer(api: api, scope: 'all', label: 'All tasks', pageSize: 50)''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'The engine API.'),
            ApiRow('open', 'bool?', 'Whether the drawer is open, when you control it; with onOpenChanged it is the web [(open)].'),
            ApiRow('label', 'String', 'The button\'s and the drawer\'s title.', def: "'My tasks'"),
            ApiRow('side', 'UiDrawerSide', 'Which edge the drawer opens from.', def: 'right'),
            ApiRow('size · variant', 'UiSize · UiButtonVariant', 'The button\'s look.', def: 'sm · outline'),
            ApiRow('showButton', 'bool', 'Show the built-in button; off when the app opens the drawer from its own control.', def: 'true'),
            ApiRow('refreshSeconds', 'int', 'How often the count refreshes while the app is in the foreground; 0 only on open, close and decisions.', def: '60'),
            ApiRow('pageSize', 'int', 'Tasks per page in the drawer.', def: '25'),
            ApiRow('scope', 'String', "The signed-in person's tasks ('mine'), or everyone's ('all', for admins; give it a label such as 'All tasks'). The count follows it.", def: "'mine'"),
          ],
          callbacks: const [
            ApiRow('onOpenChanged', 'ValueChanged<bool>', 'When the drawer opens or closes.'),
            ApiRow('onDecided', 'ValueChanged<UiWfTask>', 'After a task was decided in the drawer.'),
            ApiRow('show() · hide() · refresh()', 'state', 'Through a GlobalKey<UiWorkflowTasksDrawerState>.'),
          ],
        ),
        DocSection(
          key: _anchors['audit'],
          name: 'Audit log',
          widget: 'UiWorkflowAudit',
          summary: 'The tamper-evident audit log: filter by kind, open an entry for its before and after values, export it, and check the hash '
              'chain. Use it on an admin page, or scoped to one record (as here) on that record\'s page. Reading it needs admin rights, so the '
              'applicant and finance see the engine\'s refusal.',
          demo: frame(UiWorkflowAudit(key: _k('audit'), api: _api, entity: 'application', entityId: _appId, pageSize: 20), height: 560),
          code: '''// everything, on an admin page
UiWorkflowAudit(api: api, onExport: (bytes, format) => saveFile('audit.\$format', bytes))

// one record's entries, on its page
UiWorkflowAudit(api: api, entity: 'application', entityId: app.id)

// one run's entries
UiWorkflowAudit(api: api, instanceId: runId)''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'The engine API.'),
            ApiRow('entity · entityId', 'String?', 'Show only one record\'s entries.'),
            ApiRow('instanceId', 'String?', 'Show only one run\'s entries.'),
            ApiRow('pageSize', 'int', 'Entries per page.', def: '50'),
          ],
          callbacks: const [ApiRow('onExport', '(Uint8List bytes, String format)', 'Gets the exported file; the button shows only when it is set.')],
        ),
        DocSection(
          key: _anchors['state-badge'],
          name: 'State badge',
          widget: 'UiWorkflowStateBadge',
          summary: 'A record\'s state as a small coloured chip, in the tone its lifecycle gives it. Use it in tables and cards wherever a '
              'record\'s state is listed; the workflow panel uses it too.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Wrap(spacing: t.space2, runSpacing: t.space2, children: const [
              UiWorkflowStateBadge(label: 'Draft', tone: 'neutral'),
              UiWorkflowStateBadge(label: 'Submitted', tone: 'info'),
              UiWorkflowStateBadge(label: 'In progress', tone: 'primary'),
              UiWorkflowStateBadge(label: 'Under review', tone: 'warning'),
              UiWorkflowStateBadge(label: 'Approved', tone: 'success'),
              UiWorkflowStateBadge(label: 'Rejected', tone: 'danger'),
            ]),
            Wrap(spacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              note('This application now:'),
              UiWorkflowStateBadge(label: app.stateLabel, tone: app.stateTone ?? 'neutral'),
            ]),
          ]),
          code: '''UiWorkflowStateBadge(label: record.stateLabel ?? record.state ?? '', tone: record.stateTone)
const UiWorkflowStateBadge(label: 'Approved', tone: 'success')
// tones: neutral, info, primary, warning, success, danger''',
          api: const [
            ApiRow('label', 'String', 'The state\'s name.'),
            ApiRow('tone', 'String?', 'neutral, info, primary, warning, success or danger.', def: "'neutral'"),
          ],
        ),
        DocSection(
          key: _anchors['permissions'],
          name: 'Permissions',
          widget: 'UiWorkflowPermissions',
          summary: 'Who may do what in every published workflow, on one page: who may make each lifecycle move, start a record over, press a '
              'start button, and decide each approval or task. Saving publishes a new version with only those changes. Use it on a settings '
              'page so admins can swap people without opening the builder; people who may not publish see it read-only.',
          demo: frame(SingleChildScrollView(child: UiWorkflowPermissions(key: ValueKey('permissions-$_user'), api: _api, onSaved: (_) => _changed())), height: 560),
          code: '''UiWorkflowPermissions(api: api, onSaved: (summary) => reload())

// the rows themselves, for your own page
for (final row in permissionRows(def)) print('\${row.label}: \${row.detail}');''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'Loads every published workflow; saves with updatePermissions (POST /definitions/{id}/permissions). me is optional: without an answer, editing is offered and the server decides.'),
            ApiRow('permissionRows(def)', 'List<UiWfPermissionRow>', 'Moves (not hidden ones), the reset, a start button and approval/task steps, in reading order.'),
          ],
          callbacks: const [ApiRow('onSaved', 'ValueChanged<UiWfDefinitionSummary>', 'After a workflow\'s permissions were saved (the new version\'s summary).')],
        ),
        DocSection(
          key: _anchors['global-settings'],
          name: 'Global settings',
          widget: 'UiWorkflowGlobalSettings',
          summary: 'The app-wide workflow settings: working hours and holidays, defaults for new steps, notification channels, which addresses '
              'webhooks may call, audit retention and masking, pausing triggers per record type, what is being watched, and what the app lets '
              'workflows use. Use it on a settings page; without an API, give it settings and save them yourself. On a phone its sections '
              'become a scrolling row by themselves.',
          demo: SizedBox(height: 560, child: UiWorkflowGlobalSettings(key: ValueKey('settings-$_user'), api: _api)),
          code: '''// through the API (saves with a revision check)
UiWorkflowGlobalSettings(api: api)

// without an API: edit settings you load and save yourself
UiWorkflowGlobalSettings(registry: registry, settings: settings, onSettingsChanged: save)''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'Loads and saves the settings (with a revision check).'),
            ApiRow('registry', 'UiWorkflowRegistry?', 'The app\'s registry (channels, fields to mask, the read-only browser) when there is no API.'),
            ApiRow('settings', 'UiWorkflowSettings?', 'Settings to edit when there is no API.'),
          ],
          callbacks: const [ApiRow('onSettingsChanged', 'ValueChanged<UiWorkflowSettings>', 'The edited settings, when there is no API.')],
        ),
        DocSection(
          key: _anchors['settings-page'],
          name: 'Putting a settings page together',
          widget: 'your app\'s settings page',
          summary: 'The library has no settings page of its own: the app decides where each piece goes, next to its other settings. A typical '
              'Workflow settings page has three tabs: Workflows (the list and the builder, on their own route), Permissions and Global '
              'settings. Here is one, live.',
          demo: UiTabs(
            label: 'Workflow settings',
            selectedIndex: _settingsTab,
            onChanged: (i) => setState(() => _settingsTab = i),
            tabs: [
              UiTab(
                label: 'Workflows',
                child: Padding(
                  padding: EdgeInsets.only(top: t.space3),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
                    note('Workflows are designed in the builder. Most apps list them here and open the builder on its own route.'),
                    UiButton(label: 'Open the Workflow builder page', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => ShowcaseNav.maybeOf(context)?.go('workflow-builder')),
                  ]),
                ),
              ),
              UiTab(
                label: 'Permissions',
                child: Padding(
                  padding: EdgeInsets.only(top: t.space3),
                  child: _settingsTab == 1 ? UiWorkflowPermissions(key: ValueKey('tab-permissions-$_user'), api: _api) : const SizedBox.shrink(),
                ),
              ),
              UiTab(
                label: 'Global settings',
                child: Padding(
                  padding: EdgeInsets.only(top: t.space3),
                  child: _settingsTab == 2 ? SizedBox(height: 520, child: UiWorkflowGlobalSettings(key: ValueKey('tab-settings-$_user'), api: _api)) : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
          code: '''// workflow_settings_page.dart: your app's page; the widgets only fill its tabs
class WorkflowSettingsPage extends StatefulWidget {
  const WorkflowSettingsPage({super.key, required this.api});
  final UiWorkflowApi api;
  @override
  State<WorkflowSettingsPage> createState() => _WorkflowSettingsPageState();
}

class _WorkflowSettingsPageState extends State<WorkflowSettingsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => UiTabs(
        label: 'Workflow settings',
        selectedIndex: _tab,
        onChanged: (i) => setState(() => _tab = i),
        tabs: [
          UiTab(label: 'Workflows', child: WorkflowList(api: widget.api)),   // yours; opens the builder on its own route
          UiTab(label: 'Permissions', child: UiWorkflowPermissions(api: widget.api, onSaved: (_) => toast('Saved'))),
          UiTab(label: 'Global settings', child: SizedBox(height: 600, child: UiWorkflowGlobalSettings(api: widget.api))),
        ],
      );
}''',
        ),
      ],
    );
  }
}

/// "Which component goes where": a short map of the page, with links to each section.
class _Where extends StatelessWidget {
  const _Where({required this.onJump, required this.onBuilder});
  final ValueChanged<String> onJump;
  final VoidCallback onBuilder;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget link(String label, String anchor) => UiButton(label: label, size: UiSize.sm, variant: UiButtonVariant.link, onPressed: () => onJump(anchor));
    Widget row(String where, List<Widget> what) => SizedBox(
      width: 240,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 2, children: [
        UiText(where, variant: UiTextVariant.label, color: t.textMuted),
        Wrap(spacing: t.space2, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: what),
      ]),
    );
    return Container(
      padding: EdgeInsets.all(t.space4),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
        Semantics(header: true, child: UiText('Which component goes where', variant: UiTextVariant.h4)),
        Wrap(spacing: t.space4, runSpacing: t.space3, children: [
          row('A record\'s page', [link('Workflow panel', 'panel')]),
          row('Approvals and tasks', [link('My tasks drawer', 'tasks-drawer')]),
          row('Admin pages', [
            link('Audit log', 'audit'),
            UiText('(a stopped workflow is fixed from the record\'s panel or the tasks drawer)', color: t.textMuted),
          ]),
          row('A settings page', [link('Permissions', 'permissions'), link('Global settings', 'global-settings'), link('Put together', 'settings-page')]),
          row('The builder page', [UiButton(label: 'Workflow builder', size: UiSize.sm, variant: UiButtonVariant.link, onPressed: onBuilder)]),
        ]),
      ]),
    );
  }
}
