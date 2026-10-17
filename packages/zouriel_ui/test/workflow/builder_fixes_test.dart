import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/canvas.dart';
import 'package:zouriel_ui/src/workflow/panels.dart' show WfVersions;
import 'package:zouriel_ui/src/workflow/scope.dart' show WfBuilderScope;
import 'package:zouriel_ui/zouriel_ui.dart';

// Regression tests for the builder's audit findings: drops on lists scrolled out of view, the
// webhook body after undo, leaving Versions mid-publish, Escape during a drag, and the step cards.

final registry = UiWorkflowRegistry.fromJson({
  'specVersion': 1,
  'entities': [
    {'key': 'application', 'label': 'Application', 'fields': [
      {'key': 'status', 'label': 'Status', 'type': 'enum', 'watchable': true, 'options': [{'value': 'Draft', 'label': 'Draft'}]},
    ]},
  ],
  'channels': [{'key': 'email', 'label': 'Email'}],
});
final schema = UiWorkflowSchema(registry: registry);

UiWorkflowDefinition many() => UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_a', 'key': 'k', 'kind': 'automation', 'title': 'T', 'entity': 'application',
  'trigger': {'type': 'created'},
  'steps': [for (var i = 0; i < 25; i++) {'id': 's$i', 'type': 'end', 'result': 'completed', 'title': 'Step $i'}],
});

UiWorkflowDefinition hook() => UiWorkflowDefinition.fromJson({
  'specVersion': 1, 'id': 'wf_h', 'key': 'h', 'kind': 'automation', 'title': 'H',
  'trigger': {'type': 'manual', 'label': 'Go'},
  'steps': [{'id': 'w', 'type': 'webhook', 'method': 'POST', 'url': 'https://x.test'}],
});

class Host extends StatefulWidget {
  const Host({super.key, required this.initial, this.api, this.out, this.readOnly, this.saved});
  final UiWorkflowDefinition initial;
  final UiWorkflowApi? api;
  final List<UiWorkflowDefinition>? out;
  final bool? readOnly;
  final List<UiWorkflowDefinition>? saved;
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  late UiWorkflowDefinition def = widget.initial;
  @override
  Widget build(BuildContext context) => UiWorkflowBuilder(
        definition: def,
        schema: widget.api == null ? schema : null,
        api: widget.api,
        persist: widget.api != null,
        readOnly: widget.readOnly,
        onSaved: widget.saved?.add,
        onChanged: (d) {
          setState(() => def = d);
          widget.out?.add(d);
        },
      );
}

/// An engine for the Versions panel whose publish answers only when told to.
class PubApi extends Fake implements UiWorkflowApi {
  final publishGate = Completer<void>();
  bool failPublish = false;
  int defCalls = 0;
  UiWorkflowDefinition? last;
  UiWfDefinitionDetail detail(UiWorkflowDefinition d, int v) => UiWfDefinitionDetail.fromJson({
        'summary': {'id': d.id, 'key': d.key, 'version': v, 'hasDraftChanges': false},
        'draft': d.json, 'published': d.json, 'versions': <Object?>[], 'problems': <Object?>[]});
  @override
  Future<UiWfMe> me() async => UiWfMe.fromJson({'type': 'user', 'id': 'u', 'can': {'edit': true}});
  @override
  Future<UiWorkflowSchema> schema() async => schema_;
  /// Whether the engine has the workflow already (else Save creates it).
  bool known = true;

  /// Holds definitions() back until completed, when given.
  Completer<void>? definitionsGate;
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async {
    await definitionsGate?.future;
    return known ? [UiWfDefinitionSummary.fromJson({'id': 'wf_h', 'key': 'h', 'version': 1})] : [];
  }
  @override
  Future<UiWfDefinitionSummary> createDefinition(UiWorkflowDefinition def) async {
    known = true;
    last = def;
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }

  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async => (settings: UiWorkflowSettings(), revision: 1);
  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) async => [];
  @override
  Future<UiWfDefinitionDetail> definition(String id) async {
    defCalls++;
    return detail(last ?? hook(), 1);
  }

  @override
  Future<List<String>> diff(String id) async => [];
  @override
  Future<UiWfUser?> user(String id) async => null;
  @override
  Future<UiWfDefinitionSummary> saveDraft(UiWorkflowDefinition def) async {
    last = def;
    return UiWfDefinitionSummary.fromJson({'id': def.id});
  }

  @override
  Future<UiWfDefinitionSummary> publish(String id, {String? note}) async {
    await publishGate.future;
    if (failPublish) throw const UiWfApiError(409, 'conflict', 'Someone published first.');
    return UiWfDefinitionSummary.fromJson({'id': id, 'version': 2});
  }
}

final schema_ = schema;

Future<void> setup(WidgetTester tester, Widget w, {Size size = const Size(1280, 860)}) async {
  tester.view.devicePixelRatio = 2;
  tester.view.physicalSize = size * 2;
  tester.view.gestureSettings = ui.GestureSettings(physicalTouchSlop: 8 * tester.view.devicePixelRatio);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UiApp(home: w));
  await tester.pumpAndSettle();
}

Finder textarea(String label) =>
    find.descendant(of: find.byWidgetPredicate((w) => w is UiTextarea && w.semanticLabel == label), matching: find.byType(EditableText));

void main() {
  testWidgets('a drop over the top bar never lands in a list scrolled out of view under it', (tester) async {
    final out = <UiWorkflowDefinition>[];
    await setup(tester, Host(initial: many(), out: out));
    final canvasCenter = tester.getCenter(find.byType(WfAutomationCanvas));
    final m = TestPointer(9, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(m.hover(canvasCenter));
    await tester.sendEventToBinding(m.scroll(const Offset(0, 900)));
    await tester.pumpAndSettle();
    final from = tester.getCenter(find.bySemanticsLabel('Wait').first);
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    final dest = Offset(canvasCenter.dx, 20); // over the builder's top bar
    for (var i = 1; i <= 12; i++) {
      await g.moveTo(Offset.lerp(from, dest, i / 12)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await tester.pumpAndSettle();
    expect(out.where((d) => d.steps!.any((s) => s.type == 'wait')), isEmpty);
  });

  testWidgets('Escape during a drag cancels it and says so', (tester) async {
    final out = <UiWorkflowDefinition>[];
    await setup(tester, Host(initial: many(), out: out));
    final from = tester.getCenter(find.bySemanticsLabel('Wait').first);
    final to = tester.getCenter(find.text('Step 1'));
    final g = await tester.startGesture(from, kind: PointerDeviceKind.mouse);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.bySemanticsLabel('Move cancelled'), findsOneWidget);
    await g.up();
    await tester.pumpAndSettle();
    expect(out, isEmpty);
  });

  group('Versions', () {
    testWidgets('leaving it while publishing still finishes: the published version, Saved, onSaved', (tester) async {
      final api = PubApi();
      final saved = <UiWorkflowDefinition>[];
      await setup(tester, Host(initial: hook(), api: api, saved: saved));
      await tester.tap(find.text('Publish…'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Publish version'));
      await tester.pump();
      await tester.tap(find.text('Build'));
      await tester.pumpAndSettle();
      final before = api.defCalls;
      api.publishGate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(api.defCalls - before, 1); // the published version was read
      expect(saved, hasLength(1));
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Something went wrong.'), findsNothing);
    });

    testWidgets('a publish that fails after leaving it shows in the builder', (tester) async {
      final api = PubApi()..failPublish = true;
      await setup(tester, Host(initial: hook(), api: api));
      await tester.tap(find.text('Publish…'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Publish version'));
      await tester.pump();
      await tester.tap(find.text('Build'));
      await tester.pumpAndSettle();
      api.publishGate.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Someone published first.'), findsOneWidget);
    });

    testWidgets('reads the versions once the workflow is saved for the first time', (tester) async {
      final api = PubApi()..known = false;
      await setup(tester, Host(initial: hook(), api: api));
      await tester.tap(find.text('Publish…'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Save the workflow first'), findsOneWidget);
      expect(api.defCalls, 0);
      await tester.tap(find.byWidgetPredicate((w) => w is UiButton && w.label == 'Save'));
      await tester.pumpAndSettle();
      expect(api.defCalls, 1);
      expect(find.textContaining('Save the workflow first'), findsNothing);
    });

    testWidgets('reads the versions when saved turns true, even with nothing else changing', (tester) async {
      final api = PubApi();
      final store = UiWorkflowBuilderController(definition: hook())..api = api;
      final saved = ValueNotifier(false);
      await setup(tester, WfBuilderScope(controller: store, child: ValueListenableBuilder(valueListenable: saved, builder: (_, v, _) => WfVersions(saved: v))));
      expect(find.textContaining('Save the workflow first'), findsOneWidget);
      saved.value = true;
      await tester.pumpAndSettle();
      expect(api.defCalls, 1);
      expect(find.textContaining('Publish version 2'), findsOneWidget);
    });
  });

  testWidgets('Undo takes the webhook body back to what the step has, not the last text typed', (tester) async {
    final out = <UiWorkflowDefinition>[];
    await setup(tester, Host(initial: hook(), out: out));
    await tester.tap(find.text('Call webhook').first);
    await tester.pumpAndSettle();
    await tester.enterText(textarea('Body'), '{"a": 1}');
    await tester.pumpAndSettle();
    expect(UiWfWebhookStep.of(out.last.steps!.first).hasBody, isTrue);
    await tester.tap(find.bySemanticsLabel('Undo'));
    await tester.pumpAndSettle();
    expect(UiWfWebhookStep.of(out.last.steps!.first).hasBody, isFalse);
    expect(tester.widget<EditableText>(textarea('Body')).controller.text, '');
    // Text that isn't JSON yet stays while nothing else changes the body.
    await tester.enterText(textarea('Body'), '{"a": ');
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(textarea('Body')).controller.text, '{"a": ');
    expect(find.text('That isn’t valid JSON yet.'), findsOneWidget);
  });
}
