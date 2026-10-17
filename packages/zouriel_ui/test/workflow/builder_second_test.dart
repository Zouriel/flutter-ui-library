import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/bits.dart' show WfSelect;
import 'package:zouriel_ui/src/workflow/dnd.dart';
import 'package:zouriel_ui/src/workflow/editors.dart' show WfConditionEditor;
import 'package:zouriel_ui/src/workflow/icons.dart';
import 'package:zouriel_ui/src/workflow/inspector.dart';
import 'package:zouriel_ui/src/workflow/lifecycle.dart';
import 'package:zouriel_ui/src/workflow/scope.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

// Mirrors @zouriel/ui 9080495: For each items, the webhook body, move remarks, reset upkeep,
// self-loops, view-only and palette fixes.

final registry = UiWorkflowRegistry.fromJson({
  'entities': [
    {
      'key': 'application', 'label': 'Application',
      'fields': [
        {'key': 'status', 'label': 'Status', 'type': 'enum', 'watchable': true, 'options': [{'value': 'Draft', 'label': 'Draft'}]},
        {'key': 'amount', 'label': 'Amount', 'type': 'currency', 'settable': true},
        {'key': 'documents', 'label': 'Documents', 'type': 'collection', 'entity': 'document'},
      ],
    },
    {'key': 'document', 'label': 'Document', 'fields': [{'key': 'name', 'label': 'Name', 'type': 'text'}, {'key': 'verified', 'label': 'Verified', 'type': 'boolean', 'settable': true}]},
  ],
  'channels': [{'key': 'email', 'label': 'Email'}],
});

UiWfStep step(String id, [String type = 'notify', UiJson more = const {}]) => UiWfStep.fromJson({...createStep(type).json, 'id': id, ...more});

/// root: loop (For each document → [inner]), outer
UiWorkflowDefinition looped({Map<String, Object?> inner = const {}, Map<String, Object?> outer = const {}}) {
  final def = createWorkflow('automation', title: 'Loop', entity: 'application');
  return def.patch({
    'steps': [
      {...step('loop', 'forEach', {'collection': 'entity.documents'}).json, 'steps': [step('inner', 'setFields', inner).json]},
      step('outer', 'setFields', outer).json,
    ],
  });
}

UiWorkflowDefinition life({Map<String, Object?>? reset, List<Object?>? extraTransitions}) => UiWorkflowDefinition.fromJson({
      'specVersion': 1, 'id': 'wf_life', 'key': 'life', 'kind': 'lifecycle', 'title': 'Application', 'entity': 'application',
      'lifecycle': {
        'field': 'status', 'mode': 'enforce',
        'states': [
          {'id': 'draft', 'key': 'Draft', 'label': 'Draft', 'category': 'initial'},
          {'id': 'review', 'key': 'Review', 'label': 'Review', 'category': 'active'},
          {'id': 'more', 'key': 'More', 'label': 'More', 'category': 'active'},
          {'id': 'done', 'key': 'Done', 'label': 'Done', 'category': 'terminal'},
        ],
        'transitions': [
          {'id': 'submit', 'key': 'submit', 'label': 'Submit', 'from': ['draft'], 'to': 'review', 'who': <Object?>[],
            'input': {'form': {'schemaVersion': 1, 'id': 'f', 'title': 'F', 'pages': [{'id': 'p', 'elements': [{'kind': 'field', 'id': 'e', 'type': 'text', 'key': 'why', 'label': 'Why'}]}]}}},
          {'id': 'onward', 'key': 'onward', 'label': 'Onward', 'from': ['review'], 'to': 'more', 'who': <Object?>[]},
          {'id': 'finish', 'key': 'finish', 'label': 'Finish', 'from': ['more'], 'to': 'done', 'who': <Object?>[]},
          ...?extraTransitions,
        ],
        'reset': ?reset,
      },
    });

Future<UiWorkflowBuilderController> pumpInspector(WidgetTester tester, UiWorkflowDefinition def, UiWfSelection sel, {bool readOnly = false}) async {
  final store = UiWorkflowBuilderController(definition: def)
    ..schema = UiWorkflowSchema(registry: registry)
    ..selection = sel
    ..readOnly = readOnly;
  await pumpUi(tester, SizedBox(width: 400, height: 1200, child: WfBuilderScope(controller: store, child: const WfInspector())), size: const Size(400, 1200));
  return store;
}

WfSelect select(WidgetTester tester, String label) => tester.widget<WfSelect>(find.byWidgetPredicate((w) => w is WfSelect && w.label == label));

void main() {
  group('For each items', () {
    test('names the item of the For each a step is inside, and nothing outside it', () {
      final def = looped();
      expect([for (final x in forEachItemsAt(def, registry, const UiWfAt.step('inner'))) (x.stepId, x.entity, x.label)], [('loop', 'document', 'Document')]);
      expect(forEachItemsAt(def, registry, const UiWfAt.step('outer')), isEmpty);
      final tokens = tokensAt(def, registry, at: const UiWfAt.step('inner'));
      expect(tokens.where((t) => t.path == 'item.id'), hasLength(1), reason: 'item tokens listed once');
    });

    testWidgets('offers the current item; choosing it sets target "item" and starts the fields again', (tester) async {
      final store = await pumpInspector(tester, looped(inner: {'values': [{'field': 'amount', 'value': {'const': 5}}]}), const UiWfSelection.step('inner'));
      final record = select(tester, 'Record');
      expect([for (final o in record.options) o.label], contains('Current document (each item of the For each)'));
      record.onChanged!('item');
      await tester.pump();
      final s = UiWfSetFieldsStep.of(store.def.steps!.first.json['steps'] is List ? UiWfStep.fromJson((store.def.steps!.first.json['steps']! as List).first) : store.def.steps!.first);
      expect(s.target, 'item');
      expect(s.values, isEmpty);
      // Its fields are the document's.
      expect(find.text('Change another field'), findsOneWidget);
    });

    testWidgets('outside a For each, a loaded item target is kept (values too) and explained', (tester) async {
      final store = await pumpInspector(tester, looped(outer: {'target': 'item', 'values': [{'field': 'verified', 'value': {'const': true}}]}), const UiWfSelection.step('outer'));
      expect(select(tester, 'Record').value, 'item');
      expect(find.textContaining('isn’t inside a For each'), findsOneWidget);
      expect(UiWfSetFieldsStep.of(store.def.steps!.last).values, hasLength(1));
    });
  });

  group('webhook body', () {
    UiWorkflowDefinition hooks() => createWorkflow('automation', title: 'H').patch({
          'steps': [step('w1', 'webhook', {'url': 'https://x.test'}).json, step('w2', 'webhook', {'url': 'https://y.test'}).json],
        });
    Finder body() => find.descendant(of: find.byWidgetPredicate((w) => w is UiTextarea && w.semanticLabel == 'Body'), matching: find.byType(EditableText));

    testWidgets('keeps what is typed as typed while it is valid JSON, saves it, and tidies it on leaving the box', (tester) async {
      final store = await pumpInspector(tester, hooks(), const UiWfSelection.step('w1'));
      await tester.enterText(body(), '{"a":1}');
      await tester.pump();
      expect(tester.widget<EditableText>(body()).controller.text, '{"a":1}');
      expect(UiWfWebhookStep.of(store.def.steps!.first).body, {'a': 1});
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(body()).controller.text, '{\n  "a": 1\n}');
    });

    testWidgets('an invalid body belongs to its step: the next step does not say it is invalid', (tester) async {
      final store = await pumpInspector(tester, hooks(), const UiWfSelection.step('w1'));
      await tester.enterText(body(), '{"a": ');
      await tester.pump();
      expect(find.text('That isn’t valid JSON yet.'), findsOneWidget);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(body()).controller.text, '{"a": ', reason: 'invalid text stays to be fixed');
      store.selection = const UiWfSelection.step('w2');
      await tester.pumpAndSettle();
      expect(find.text('That isn’t valid JSON yet.'), findsNothing);
    });
  });

  testWidgets('Move lifecycle has a remarks template, stored as comment (left out when empty)', (tester) async {
    final def = createWorkflow('automation', title: 'M').patch({'steps': [step('m', 'applyTransition').json]});
    final store = await pumpInspector(tester, def, const UiWfSelection.step('m'));
    final remarks = find.descendant(of: find.byWidgetPredicate((w) => w.runtimeType.toString() == 'WfTemplateEditor' && (w as dynamic).label == 'Remarks'), matching: find.byType(EditableText));
    await tester.enterText(remarks, 'Approved automatically');
    await tester.pump();
    expect(store.def.steps!.first.json['comment'], isNotNull);
    await tester.enterText(remarks, '');
    await tester.pump();
    expect(store.def.steps!.first.json.containsKey('comment'), isFalse);
  });

  group('lifecycle upkeep', () {
    test('a reset back to the deleted state goes back to the start, and is no longer offered in it', () {
      final def = removeState(life(reset: {'to': 'review', 'states': ['review', 'more'], 'who': <Object?>[]}), 'review');
      final r = def.lifecycle!.reset!;
      expect(r.to, isNull);
      expect(r.states, ['more']);
    });

    test('leaves the reset alone when it doesn\'t mention the state', () {
      final reset = {'to': 'draft', 'states': ['review'], 'who': <Object?>[]};
      final def = removeState(life(reset: reset), 'more');
      expect(def.lifecycle!.reset!.json, reset);
    });

    testWidgets('making a state the start is one undo step', (tester) async {
      final store = await pumpInspector(tester, life(), const UiWfSelection.state('review'));
      store.clearHistory();
      final kind = find.byWidgetPredicate((w) => w is WfSelect && w.options.any((o) => o.value == 'initial'));
      tester.widget<WfSelect>(kind).onChanged!('initial');
      await tester.pump();
      String cat(String id) => store.def.lifecycle!.states.firstWhere((s) => s.id == id).category;
      expect((cat('review'), cat('draft')), ('initial', 'active'));
      store.undo();
      expect((cat('review'), cat('draft')), ('active', 'initial'));
      expect(store.canUndo, isFalse);
    });

    testWidgets('"Back to" works the offered states out again when they were "from a state onwards", and says when ticks match no state', (tester) async {
      final store = await pumpInspector(tester, life(reset: {'states': ['review', 'more', 'done'], 'who': <Object?>[]}), UiWfSelection.reset);
      expect(store.def.lifecycle!.reset!.states, ['review', 'more', 'done']);
      select(tester, 'Back to').onChanged!('more');
      await tester.pump();
      // From Review onwards, stopping at the new target (More).
      expect(store.def.lifecycle!.reset!.states, ['review']);
      expect(store.def.lifecycle!.reset!.to, 'more');
      // Ticks that are no state's onward set get a note.
      store.updateReset({'states': ['draft', 'done']});
      await tester.pump();
      expect(find.textContaining('aren’t one state and the ones after it'), findsOneWidget);
    });

    testWidgets('checks before a move and automatic moves don\'t offer form answers, remarks or who moved it', (tester) async {
      final def = updateTransition(life(), 'submit', {'auto': {'when': {'match': 'all', 'conditions': <Object?>[]}}});
      await pumpInspector(tester, def, const UiWfSelection.transition('submit'));
      final editors = tester.widgetList<WfConditionEditor>(find.byType(WfConditionEditor)).toList();
      expect(editors, hasLength(2));
      for (final e in editors) {
        final paths = [for (final t in e.tokens) t.path];
        expect(paths.where((p) => p.startsWith('input.')), isEmpty);
        expect(paths, isNot(contains('trigger.comment')));
        expect(paths, isNot(contains('trigger.actor')));
        expect(paths, contains('trigger.from'));
      }
    });
  });

  group('self-loops and the reset chip', () {
    final loopDef = life(
      reset: {'states': ['review'], 'who': <Object?>[]},
      extraTransitions: [{'id': 'askMore', 'key': 'askMore', 'label': 'Ask for more', 'from': ['review'], 'to': 'review', 'who': <Object?>[]}],
    );

    test('are listed as loops (the layout leaves them out) and drawn over the top of their card', () {
      final lc = loopDef.lifecycle!;
      expect(lifecycleSelfLoops(lc), [(id: 'askMore:review', state: 'review')]);
      expect(lifecycleEdges(lc).where((e) => e.id.startsWith('askMore')), isEmpty);
      final p = selfLoopPath(const Offset(100, 100));
      expect(p.d, startsWith('M '));
      expect(p.d, contains(' C '));
      expect(p.label.dy, lessThan(100));
      expect(p.toPath().getBounds().top, lessThan(100));
    });

    testWidgets('draws a move back to the same state as a loop with its label, and says where a restricted reset is offered', (tester) async {
      final store = UiWorkflowBuilderController(definition: loopDef);
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(900, 640) * 2;
      tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: WfBuilderScope(controller: store, child: const WfLifecycleCanvas())));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Transition Ask for more'), findsOneWidget);
      expect(find.text('Starting over'), findsOneWidget, reason: 'no any-state moves');
      expect(find.text('Draft · from Review'), findsOneWidget);
    });
  });

  group('view only', () {
    testWidgets('Delete deletes nothing and Ctrl+S saves nothing', (tester) async {
      final c = UiWorkflowBuilderController(definition: life());
      final api = _SaveCounter();
      tester.view.physicalSize = const Size(1280, 860) * tester.view.devicePixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UiApp(home: UiWorkflowBuilder(controller: c, api: api, persist: true, readOnly: true)));
      await tester.pumpAndSettle();
      c.selection = const UiWfSelection.state('review');
      await tester.pumpAndSettle();
      await tester.tap(find.text('View only'));
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();
      expect(find.byType(UiModal), findsNothing);
      expect(c.def.lifecycle!.states.any((s) => s.id == 'review'), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(api.saves, 0);
      await tester.state<UiWorkflowBuilderState>(find.byType(UiWorkflowBuilder)).save();
      expect(api.saves, 0);
    });

    test('a drag starts nothing and announces nothing', () {
      final c = UiWorkflowBuilderController(definition: createWorkflow('automation', title: 'A'))..readOnly = true;
      final dnd = WfDnd(c);
      dnd.begin(const WfDragPayload.add(type: 'wait', label: 'Wait', icon: WfIcons.add01), Offset.zero);
      expect(dnd.payload, isNull);
      dnd.end();
      expect(dnd.announcement, '');
    });
  });

  testWidgets('palette clicks add to the end of the selected transition\'s steps, not the start', (tester) async {
    final def = updateTransition(life(), 'submit', {'steps': [step('a').json, step('b').json]});
    final c = UiWorkflowBuilderController(definition: def)..selection = const UiWfSelection.transition('submit');
    tester.view.physicalSize = const Size(1280, 860) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: UiWorkflowBuilder(controller: c, schema: UiWorkflowSchema(registry: registry))));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Wait').first);
    await tester.pumpAndSettle();
    final ids = [for (final s in listSteps(c.def, 'transition:submit')!) s.type];
    expect(ids, ['notify', 'notify', 'wait']);
  });
}

class _SaveCounter extends Fake implements UiWorkflowApi {
  int saves = 0;
  @override
  Future<UiWfMe?> me() async => null;
  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema(registry: registry);
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => [UiWfDefinitionSummary.fromJson({'id': 'wf_life', 'key': 'life', 'version': 1})];
  @override
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def) async {
    saves++;
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }

  @override
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def) async {
    saves++;
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }
}
