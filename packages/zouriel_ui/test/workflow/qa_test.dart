import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/src/workflow/canvas.dart';
import 'package:zouriel_ui/src/workflow/editors.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// The QA fixes of @zouriel/ui c91564e: durations, wide branches, variable keys, versions.

UiWfStep _step(String id, [String type = 'notify', UiJson more = const {}]) => UiWfStep.fromJson({...createStep(type).json, 'id': id, ...more});

class _VersionsApi extends Fake implements UiWorkflowApi {
  _VersionsApi(this.draft);
  UiWorkflowDefinition draft;
  final calls = <String>[];

  @override
  Future<UiWorkflowSchema> schema() async => UiWorkflowSchema(registry: UiWorkflowRegistry.fromJson({'entities': <Object?>[]}));
  @override
  Future<List<UiWfDefinitionSummary>> definitions() async => [UiWfDefinitionSummary.fromJson({'id': draft.id, 'key': draft.key})];
  @override
  Future<({UiWorkflowSettings settings, int revision})> settings() async => (settings: UiWorkflowSettings(), revision: 1);
  @override
  Future<List<UiWfProblem>> validate(UiWorkflowDefinition def) async => const [];
  @override
  Future<List<String>> diff(String id) async => const ['Changed “Tell them”'];
  @override
  Future<UiWfUser?> user(String id) async => id == 'u1' ? UiWfUser.fromJson({'id': 'u1', 'name': 'Hana Ibrahim'}) : null;
  @override
  Future<UiWfDefinitionDetail> definition(String id) async => UiWfDefinitionDetail.fromJson({
    'summary': {'id': id, 'key': draft.key, 'status': 'published', 'version': 2},
    'draft': draft.json,
    'published': draft.json,
    'versions': [
      {'version': 2, 'note': 'Second', 'publishedAt': '2026-10-17T09:00:00Z', 'publishedBy': 'u1', 'instances': 0},
      {'version': 1, 'note': 'First', 'publishedAt': '2026-10-16T09:00:00Z', 'publishedBy': 'u1', 'instances': 3},
    ],
    'problems': <Object?>[],
  });
  @override
  Future<UiWfDefinitionSummary> rollback(String id, int version) async {
    calls.add('rollback:$version');
    draft = draft.patch({'title': 'Rolled back to $version'});
    return UiWfDefinitionSummary.fromJson({'id': id});
  }
}

void main() {
  group('durations', () {
    test('one-part durations read as they are', () {
      expect(parseSimpleDuration('P3D'), (n: 3, unit: 'D', negative: false));
      expect(parseSimpleDuration('PT4H'), (n: 4, unit: 'H', negative: false));
      expect(parseSimpleDuration('-P1W'), (n: 1, unit: 'W', negative: true));
      expect(parseSimpleDuration('P2M'), (n: 2, unit: 'Mo', negative: false));
    });

    test('several parts become their total in the largest exact unit', () {
      expect(parseSimpleDuration('P1DT12H'), (n: 36, unit: 'H', negative: false));
      expect(parseSimpleDuration('P1W2D'), (n: 9, unit: 'D', negative: false));
      expect(parseSimpleDuration('PT1H30M'), (n: 90, unit: 'M', negative: false));
      expect(parseSimpleDuration('P1Y2M'), (n: 14, unit: 'Mo', negative: false));
      expect(parseSimpleDuration('P1MT1H'), isNull); // months and hours can't add up
      expect(parseSimpleDuration('P'), isNull);
      expect(parseSimpleDuration('PT'), isNull);
      expect(parseSimpleDuration('soon'), isNull);
    });

    test('written durations are capped at 50 years', () {
      expect(formatSimpleDuration(9999, 'Mo'), 'P600M');
      expect(formatSimpleDuration(1e9, 'M'), 'PT26280000M');
      expect(formatSimpleDuration(-3, 'D'), 'P0D');
      expect(formatSimpleDuration(2, 'H', true), '-PT2H');
    });
  });

  test('branches need room for every column, nested ones too', () {
    expect(wfListWidth([_step('a')]), 0);
    final par = UiWfStep.fromJson({
      ...createStep('parallel').json,
      'paths': [for (var i = 0; i < 4; i++) {'id': 'p$i', 'label': 'P$i', 'steps': <Object?>[]}],
    });
    expect(wfListWidth([par]), 4 * wfLaneMinWidth + 3 * wfForkGap);
    final branch = UiWfStep.fromJson({...createStep('branch').json, 'otherwise': {'id': 'o', 'label': 'Otherwise', 'steps': [par]}});
    // Its "If" column at the minimum, its "Otherwise" column holding the four paths.
    expect(wfListWidth([branch]), wfLaneMinWidth + wfForkGap + (4 * wfLaneMinWidth + 3 * wfForkGap + 14));
  });

  testWidgets('a variable keeps its key once a step reads it', (tester) async {
    final def = createWorkflow('automation', title: 'Vars', entity: 'application').patch({
      'variables': [{'id': 'v1', 'key': 'tries', 'label': 'Tries', 'type': 'number'}],
    });
    final c = UiWorkflowBuilderController(definition: def);
    addTearDown(c.dispose);
    tester.view.physicalSize = const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: UiWorkflowBuilder(controller: c)));
    await tester.pumpAndSettle();
    Future<void> rename(String to) async {
      final input = find.byWidgetPredicate((w) => w is UiInput && w.semanticLabel == 'Variable 1 name');
      await tester.enterText(find.descendant(of: input, matching: find.byType(EditableText)), to);
      await tester.pumpAndSettle();
    }

    await rename('Attempts');
    expect(c.def.variables!.single.key, 'attempts'); // nothing reads it yet: the key follows
    c.commit(insertStep(c.def, 'root', 0, _step('n', 'notify', {'body': ['Try ', {'ref': 'vars.attempts'}]})));
    await tester.pumpAndSettle();
    await rename('Retries');
    expect(c.def.variables!.single.key, 'attempts'); // now read by a step: it stays
    expect(c.def.variables!.single.label, 'Retries');
  });

  testWidgets('versions: publishers by name; rolling back asks first and loads the rolled-back draft', (tester) async {
    final def = createWorkflow('automation', title: 'Draft edits', entity: 'application');
    final api = _VersionsApi(def);
    final c = UiWorkflowBuilderController(definition: def);
    addTearDown(c.dispose);
    UiWorkflowDefinition? saved;
    tester.view.physicalSize = const Size(1280, 900) * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(UiApp(home: UiWorkflowBuilder(controller: c, api: api, persist: true, onSaved: (d) => saved = d)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Versions'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hana Ibrahim'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('Make current'));
    await tester.pumpAndSettle();
    expect(find.text('Make version 1 current?'), findsOneWidget);
    expect(api.calls, isEmpty);
    await tester.tap(find.widgetWithText(UiButton, 'Make current'));
    await tester.pumpAndSettle();
    expect(api.calls, ['rollback:1']);
    expect(c.def.title, 'Rolled back to 1');
    expect(saved?.title, 'Rolled back to 1');
    expect(find.text('Unsaved changes'), findsNothing);
  });
}
