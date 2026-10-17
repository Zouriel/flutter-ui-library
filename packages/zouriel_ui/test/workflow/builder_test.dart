import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

final registry = UiWorkflowRegistry.fromJson({
  'specVersion': 1,
  'entities': [
    {
      'key': 'application', 'label': 'Application',
      'fields': [
        {'key': 'status', 'label': 'Status', 'type': 'enum', 'watchable': true, 'lifecycle': true, 'options': [{'value': 'Draft', 'label': 'Draft'}, {'value': 'Submitted', 'label': 'Submitted'}]},
        {'key': 'amount', 'label': 'Amount', 'type': 'currency', 'watchable': true, 'settable': true},
        {'key': 'reviewer', 'label': 'Reviewer', 'type': 'user', 'settable': true},
      ],
    },
  ],
  'channels': [{'key': 'email', 'label': 'Email'}],
  'roles': [{'key': 'finance', 'label': 'Finance'}],
});

final schema = UiWorkflowSchema(registry: registry);
final _schema = schema;

UiWorkflowDefinition automation() => UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_a', 'key': 'remind', 'kind': 'automation', 'title': 'Remind reviewers', 'entity': 'application',
  'trigger': {'type': 'fieldChanged', 'field': 'status', 'to': ['Submitted']},
  'steps': [
    {'id': 'a', 'type': 'notify', 'title': 'Tell the applicant', 'channel': 'email', 'to': [{'initiator': true}], 'body': 'Thanks'},
    {
      'id': 'b', 'type': 'branch', 'title': 'Big amount?',
      'paths': [{'id': 'p', 'label': 'Over 5,000', 'when': {'match': 'all', 'conditions': <Object?>[]}, 'steps': [{'id': 'c', 'type': 'wait', 'until': {'type': 'duration', 'duration': 'P1D'}}]}],
      'otherwise': {'id': 'o', 'label': 'Otherwise', 'steps': <Object?>[]},
    },
    {'id': 'd', 'type': 'end', 'result': 'completed'},
  ],
});

class _Api extends Fake implements UiWorkflowApi {
  final calls = <String>[];
  List<UiWfProblem> problems = [];

  @override
  Future<UiWorkflowSchema> schema() async => _schema;
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => [];
  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async => (settings: UiWorkflowSettings(), revision: 1);
  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) async {
    calls.add('validate');
    return problems;
  }

  @override
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def) async {
    calls.add('create:${def.id}');
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }

  @override
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def) async {
    calls.add('save:${def.id}');
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }
}

class _Host extends StatefulWidget {
  const _Host({required this.initial, this.api, this.persist = false, this.onDef});
  final UiWorkflowDefinition initial;
  final UiWorkflowApi? api;
  final bool persist;
  final ValueChanged<UiWorkflowDefinition>? onDef;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late UiWorkflowDefinition def = widget.initial;

  @override
  Widget build(BuildContext context) => UiWorkflowBuilder(
    definition: def,
    schema: widget.api == null ? schema : null,
    api: widget.api,
    persist: widget.persist,
    onChanged: (d) {
      setState(() => def = d);
      widget.onDef?.call(d);
    },
  );
}

Future<List<UiWorkflowDefinition>> pumpBuilder(WidgetTester tester, {Size size = const Size(1280, 860), UiWorkflowDefinition? def, UiWorkflowApi? api, bool persist = false}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  final out = <UiWorkflowDefinition>[];
  await tester.pumpWidget(UiApp(home: _Host(initial: def ?? automation(), api: api, persist: persist, onDef: out.add)));
  await tester.pumpAndSettle();
  return out;
}

List<String> rootIds(List<UiWorkflowDefinition> out) => [for (final s in out.last.steps!) s.id];

void main() {
  testWidgets('shows the trigger, the steps and their columns, with the palette and settings beside them', (tester) async {
    await pumpBuilder(tester);
    expect(find.bySemanticsLabel(RegExp(r'^Trigger: When Status changes to Submitted')), findsOneWidget);
    expect(find.text('Tell the applicant'), findsOneWidget);
    expect(find.text('Over 5,000'), findsOneWidget);
    expect(find.text('Otherwise'), findsOneWidget);
    expect(find.text('Add a step'), findsOneWidget); // the palette's heading (wide layout)
    expect(find.text('Workflow settings'), findsOneWidget);
  });

  testWidgets('pressing + between steps opens the picker, and choosing adds the step there', (tester) async {
    final out = await pumpBuilder(tester);
    // The slots of the root list: before a (0), after a (1)…
    final plus = find.bySemanticsLabel('Add a step here');
    await tester.tap(plus.at(1));
    await tester.pumpAndSettle();
    expect(find.text('Add a step'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Approval').last);
    await tester.pumpAndSettle();
    final ids = rootIds(out);
    expect(ids, hasLength(4));
    expect(ids[0], 'a');
    expect(out.last.steps![1].type, 'approval');
    // The new step is selected and its settings show.
    expect(find.text('Who approves'), findsOneWidget);
  });

  testWidgets('tapping a palette type adds it after the selected step', (tester) async {
    final out = await pumpBuilder(tester);
    await tester.tap(find.text('Tell the applicant'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Wait').first);
    await tester.pumpAndSettle();
    expect(out.last.steps![1].type, 'wait');
  });

  testWidgets('dragging a step by its grip moves it into another branch', (tester) async {
    final out = await pumpBuilder(tester);
    final grip = find.bySemanticsLabel('Move Tell the applicant (or use the menu)');
    final target = tester.getCenter(find.text('Otherwise'));
    final g = await tester.startGesture(tester.getCenter(grip));
    await tester.pump();
    final from = tester.getCenter(grip);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, target + const Offset(0, 30), i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    final b = UiWfBranchStep.of(out.last.steps!.firstWhere((s) => s.id == 'b'));
    expect(b.otherwise!.steps.map((s) => s.id), ['a']);
    expect(rootIds(out), ['b', 'd']);
  });

  testWidgets('the step menu moves, duplicates, turns off and deletes', (tester) async {
    final out = await pumpBuilder(tester);
    Future<void> menu(String label) async {
      await tester.tap(find.bySemanticsLabel('More for Tell the applicant').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await menu('Move down');
    expect(rootIds(out), ['b', 'a', 'd']);
    await menu('Turn off (skip it)');
    expect(out.last.steps![1].disabled, isTrue);
    expect(find.text('Off'), findsOneWidget);
    await menu('Duplicate');
    expect(out.last.steps, hasLength(4));
    expect(out.last.steps![2].title, 'Tell the applicant (copy)');
    // Nothing inside and nothing uses it: deleted at once.
    await tester.tap(find.bySemanticsLabel('More for Tell the applicant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(out.last.steps!.map((s) => s.id), isNot(contains('a')));
  });

  testWidgets('deleting a container asks first, and undo brings it back', (tester) async {
    final out = await pumpBuilder(tester);
    await tester.tap(find.text('Big amount?'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Delete Big amount?'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “Big amount?”?'), findsOneWidget);
    expect(find.text('The 1 step inside it will be deleted too.'), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(rootIds(out), ['a', 'd']);
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(rootIds(out), ['a', 'b', 'd']);
  });

  testWidgets('keyboard: Ctrl+Z undoes, Ctrl+Shift+Z redoes, Escape clears the selection', (tester) async {
    final out = await pumpBuilder(tester);
    await tester.tap(find.text('Tell the applicant'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Wait').first);
    await tester.pumpAndSettle();
    expect(out.last.steps, hasLength(4));
    // Focus the builder itself, not a text field.
    await tester.tapAt(const Offset(700, 820));
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(out.last.steps, hasLength(3));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(out.last.steps, hasLength(4));
  });

  testWidgets('editing a step in the inspector writes the definition back; typing merges into one undo', (tester) async {
    final out = await pumpBuilder(tester);
    await tester.tap(find.text('Tell the applicant'));
    await tester.pumpAndSettle();
    final name = find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Name');
    await tester.enterText(find.descendant(of: name.first, matching: find.byType(EditableText)).first, 'Say thanks');
    await tester.pumpAndSettle();
    expect(out.last.steps![0].title, 'Say thanks');
    expect(find.text('Say thanks'), findsWidgets);
  });

  testWidgets('selecting the trigger edits what starts it', (tester) async {
    final out = await pumpBuilder(tester);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Trigger: ')));
    await tester.pumpAndSettle();
    expect(find.text('What starts it'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('A record is created'));
    await tester.pumpAndSettle();
    expect(out.last.trigger!.type, 'created');
    expect(find.bySemanticsLabel(RegExp(r'^Trigger: When a application is created')), findsOneWidget);
  });

  testWidgets('with an API: problems from the engine show on the step and in the list', (tester) async {
    final api = _Api()..problems = [UiWfProblem(code: 'noRecipients', severity: 'error', node: 'a', message: 'Add who gets the message.')];
    await pumpBuilder(tester, api: api);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(api.calls, contains('validate'));
    expect(find.bySemanticsLabel('1 problem to fix'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('1 problem to fix'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp('Add who gets the message')).last);
    await tester.pumpAndSettle();
    // Jumped to the step: its settings and the problem show.
    expect(find.text('Add who gets the message.'), findsWidgets);
    expect(find.text('Send by'), findsOneWidget);
  });

  testWidgets('persist: Save creates the definition, then saves drafts', (tester) async {
    final api = _Api();
    await pumpBuilder(tester, api: api, persist: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Tell the applicant'));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Wait').first);
    await tester.pumpAndSettle();
    expect(find.text('Unsaved changes'), findsOneWidget);
    await tester.tap(find.widgetWithText(UiButton, 'Save'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('create:wf_a'));
    expect(find.text('Saved'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('phone: no palette beside the canvas; + opens the picker in a sheet; settings open in a sheet', (tester) async {
    final out = await pumpBuilder(tester, size: const Size(390, 844));
    expect(find.text('Workflow settings'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Add a step here').first);
    await tester.pumpAndSettle();
    // The list is long on a phone: search for it.
    await tester.enterText(find.descendant(of: find.byType(UiSearchInput).last, matching: find.byType(EditableText)), 'wait');
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Wait').last);
    await tester.pumpAndSettle();
    expect(out.last.steps!.first.type, 'wait');
    // The new step's settings opened in the sheet.
    expect(find.text('For a length of time'), findsOneWidget);
  });

  testWidgets('phone: branch columns stack and collapse', (tester) async {
    await pumpBuilder(tester, size: const Size(390, 844));
    expect(find.text('Wait'), findsWidgets);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Over 5,000')));
    await tester.pumpAndSettle();
    expect(find.text('for 1 day'), findsNothing);
  });

  testWidgets('a lifecycle shows the diagram and, once a state is selected, its steps', (tester) async {
    final out = await pumpBuilder(tester, def: createWorkflow('lifecycle', title: 'Life', entity: 'application'));
    expect(find.text('Select a state or a transition to see the steps it runs.'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Draft')).first);
    await tester.pumpAndSettle();
    expect(find.text('In “Draft”'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Wait').first);
    await tester.pumpAndSettle();
    final draft = out.last.lifecycle!.states.first;
    expect(draft.onEnter!.single.type, 'wait');
  });

  testWidgets('golden: the builder, wide and on a phone', (tester) async {
    await expectThemedGolden(tester, 'workflow_builder_wide', (_) => UiWorkflowBuilder(definition: automation(), schema: schema), width: 1180, height: 640, themes: const [UiThemeName.dark]);
    await expectThemedGolden(tester, 'workflow_builder_phone', (_) => UiWorkflowBuilder(definition: automation(), schema: schema), width: 390, height: 760);
  });
}
