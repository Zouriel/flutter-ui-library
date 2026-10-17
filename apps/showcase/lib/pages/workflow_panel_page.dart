import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'workflow_demo_api.dart';

/// The workflow panel page (the web `/workflow-panel`): one record's workflow in each layout, on the
/// in-memory engine so the page works offline.
class WorkflowPanelPage extends StatefulWidget {
  const WorkflowPanelPage({super.key});

  @override
  State<WorkflowPanelPage> createState() => _WorkflowPanelPageState();
}

class _WorkflowPanelPageState extends State<WorkflowPanelPage> {
  final DemoWorkflowApi _api = DemoWorkflowApi();
  UiWorkflowPanelLayout _layout = UiWorkflowPanelLayout.vertical;
  int _epoch = 0;

  void _reset() => setState(() {
    _api.reset();
    _epoch++;
  });

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final drawer = _layout == UiWorkflowPanelLayout.sideDrawer || _layout == UiWorkflowPanelLayout.bottomDrawer;
    final panel = UiWorkflowPanel(
      key: ValueKey('$_epoch-${_layout.name}'),
      api: _api,
      entity: 'application',
      entityId: '1',
      layout: _layout,
      title: 'Application workflow',
    );
    return DocPage(
      eyebrow: 'Flagship',
      title: 'Workflow panel',
      lead: 'Attach a record\'s workflow to the record\'s own page: its states as a stepper (green for states it has been through, dark for '
          'those it hasn\'t reached), what happened in each, and in the current state the moves this person may make, their forms and '
          'confirmations, open tasks and manual workflows. Choose how it sits on the page in code: a vertical or horizontal panel, or a '
          'drawer that waits on the screen\'s edge as a rail of dots.',
      children: [
        DocSection(
          name: 'Try it',
          widget: 'UiWorkflowPanel',
          summary: 'An application on the demo engine. Pick a layout. With a drawer layout, look for the dots on the right edge or the '
              'bottom of the screen: hover them with a mouse to peek (move away and it closes), or tap them to open the drawer. When the '
              'person has nothing to do in the current state, the panel says so. Start over lists what the workflow did (fields it changed, '
              'a record it created, a message it sent), all ticked; untick what should stay.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space3, children: [
            Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
              UiSegmented<UiWorkflowPanelLayout>(
                label: 'Layout',
                size: UiSize.sm,
                value: _layout,
                onChanged: (v) => setState(() => _layout = v),
                options: const [
                  UiSegmentedOption(value: UiWorkflowPanelLayout.vertical, label: 'Vertical'),
                  UiSegmentedOption(value: UiWorkflowPanelLayout.horizontal, label: 'Horizontal'),
                  UiSegmentedOption(value: UiWorkflowPanelLayout.sideDrawer, label: 'Side drawer'),
                  UiSegmentedOption(value: UiWorkflowPanelLayout.bottomDrawer, label: 'Bottom drawer'),
                ],
              ),
              UiButton(label: 'Start over', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _reset),
            ]),
            if (drawer) ...[
              Text(
                'The panel is on the ${_layout == UiWorkflowPanelLayout.sideDrawer ? 'right edge' : 'bottom edge'} of the screen as a rail of '
                'dots: one per state, green up to where the application is now.',
                style: context.uiText.body.copyWith(fontSize: 13.5, color: t.textSecondary),
              ),
              panel,
            ] else
              Container(
                constraints: BoxConstraints(maxWidth: _layout == UiWorkflowPanelLayout.vertical ? 440 : 900),
                padding: EdgeInsets.all(t.space4),
                decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
                child: panel,
              ),
          ]),
          code: '''UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, onChanged: (_) => reload())

// states left to right, details below
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.horizontal)

// a rail of dots on the right edge; hover (desktop) or tap opens the drawer
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.sideDrawer)

// a rail of dots along the bottom
UiWorkflowPanel(api: api, entity: 'application', entityId: app.id, layout: UiWorkflowPanelLayout.bottomDrawer)''',
          api: const [
            ApiRow('api', 'UiWorkflowApi?', 'The engine. Nothing loads while it is null.'),
            ApiRow('entity', 'String', 'The record type key, as registered.'),
            ApiRow('entityId', 'String', 'The record id.'),
            ApiRow('layout', 'UiWorkflowPanelLayout', 'vertical, horizontal, sideDrawer or bottomDrawer.', def: 'vertical'),
            ApiRow('side', 'UiDrawerSide', 'Which edge the side drawer opens from (left or right).', def: 'right'),
            ApiRow('title', 'String', 'The heading (and the drawer title).', def: "'Workflow'"),
            ApiRow('showHistory', 'bool', 'Show what happened in each state.', def: 'true'),
            ApiRow('emptyText', 'String', 'Said when the person has nothing to do in the current state; empty hides it.', def: "'Nothing for you to do here right now.'"),
            ApiRow('onChanged', 'ValueChanged<UiWfRecord>?', 'After the record moved through the panel.'),
          ],
        ),
      ],
    );
  }
}
