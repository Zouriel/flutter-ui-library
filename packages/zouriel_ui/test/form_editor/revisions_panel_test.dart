import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../helpers.dart';

UiJson f(String id) => {'kind': 'field', 'id': id, 'type': 'text', 'key': id, 'label': id.toUpperCase()};
UiFormDefinition form(List<UiJson> els, int revision) => UiFormDefinition.fromJson({
  'schemaVersion': 2,
  'id': 'form1',
  'title': 'T',
  'revision': revision,
  'pages': [
    {'id': 'p1', 'elements': els},
  ],
});

class _Host extends StatefulWidget {
  const _Host({super.key, required this.store, this.formId = 'form1', required this.onRestore});
  final UiFbRevisionStore store;
  final String formId;
  final ValueChanged<UiFormDefinition> onRestore;
  @override
  State<_Host> createState() => HostState();
}

class HostState extends State<_Host> {
  late UiFbRevisionStore store = widget.store;
  late String formId = widget.formId;
  void swap({UiFbRevisionStore? s, String? id}) => setState(() {
    store = s ?? store;
    formId = id ?? formId;
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: SizedBox(
      width: 390,
      child: UiFbRevisionPanel(store: store, formId: formId, current: form([f('a'), f('b')], 3), onRestore: widget.onRestore),
    ),
  );
}

UiFbMemoryRevisionStore seed() {
  final s = UiFbMemoryRevisionStore();
  final v1 = form([f('a')], 1);
  final v2 = form([f('a'), f('b')], 2);
  s.saveRevision(fbCreateRevision(v1));
  s.saveRevision(fbCreateRevision(v2, previous: v1, meta: const UiFbRevisionMeta(publishedBy: 'Aisha')));
  return s;
}

/// Delegates to a memory store but answers later, or fails.
class _AsyncStore implements UiFbRevisionStore {
  _AsyncStore(this.inner, {this.fail = false});
  final UiFbMemoryRevisionStore inner;
  final bool fail;
  final gate = Completer<void>();
  @override
  Future<List<UiFbRevision>> listRevisions(String formId) async {
    await gate.future;
    if (fail) throw UiFbRevisionError('offline');
    return inner.listRevisions(formId);
  }

  @override
  Future<UiFbRevision?> getRevision(String formId, int revision) async => inner.getRevision(formId, revision);
  @override
  Future<void> saveRevision(UiFbRevision entry) async => inner.saveRevision(entry);
  @override
  Future<UiFormDefinition> rollback(String formId, int targetRevision, [UiFormDefinition? current]) async => inner.rollback(formId, targetRevision, current);
}

class _FailingRollback extends UiFbMemoryRevisionStore {
  @override
  UiFormDefinition rollback(String formId, int targetRevision, [UiFormDefinition? current]) => throw UiFbRevisionError('the server said no');
}

void main() {
  final hostKey = GlobalKey<HostState>();
  Future<void> show(WidgetTester t, UiFbRevisionStore store, {ValueChanged<UiFormDefinition>? onRestore, String formId = 'form1'}) =>
      pumpUi(t, _Host(key: hostKey, store: store, formId: formId, onRestore: onRestore ?? (_) {}));

  testWidgets('shows an empty state, then the versions newest first', (tester) async {
    final store = UiFbMemoryRevisionStore();
    await show(tester, store);
    expect(find.textContaining('Nothing has been published yet'), findsOneWidget);
    hostKey.currentState!.swap(s: seed());
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Version 2')).dy, lessThan(tester.getTopLeft(find.text('Version 1')).dy));
    expect(find.text('Latest'), findsOneWidget);
    expect(find.textContaining('Aisha'), findsOneWidget);
    expect(find.text('First version'), findsOneWidget);
  });

  testWidgets('shows what changed and the comparison with the draft, and hides them again', (tester) async {
    await show(tester, seed());
    await tester.tap(find.text('What changed').first);
    await tester.pumpAndSettle();
    expect(find.text('Changed in version 2'), findsOneWidget);
    expect(find.textContaining('Added'), findsWidgets);
    expect(find.text('Hide what changed'), findsOneWidget);
    await tester.tap(find.text('Compare with draft').last);
    await tester.pumpAndSettle();
    expect(find.text('What the draft has changed since version 1'), findsOneWidget);
    expect(find.text('Hide comparison'), findsOneWidget);
    await tester.tap(find.text('Hide what changed'));
    await tester.pumpAndSettle();
    expect(find.text('Changed in version 2'), findsNothing);
  });

  testWidgets('says so for the first version and for an identical draft', (tester) async {
    await show(tester, seed());
    await tester.tap(find.text('What changed').last);
    await tester.pumpAndSettle();
    expect(find.text('This was the first version.'), findsOneWidget);
    await tester.tap(find.text('Compare with draft').first);
    await tester.pumpAndSettle();
    expect(find.text('The draft is the same as this version.'), findsOneWidget);
  });

  testWidgets('restores after a confirmation and gives the new draft', (tester) async {
    UiFormDefinition? got;
    await show(tester, seed(), onRestore: (d) => got = d);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(find.text('Restore version 1?'), findsOneWidget);
    expect(find.textContaining('Questions you added since then are archived, not deleted'), findsOneWidget);
    await tester.tap(find.text('Restore this version'));
    await tester.pumpAndSettle();
    expect(got, isNotNull);
    expect(got!.revision, 3);
    expect([for (final e in got!.pages[0].elements) [e.id, e.archived ?? false]], [['a', false], ['b', true]]);
  });

  testWidgets('cancelling the confirmation restores nothing', (tester) async {
    UiFormDefinition? got;
    await show(tester, seed(), onRestore: (d) => got = d);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(got, isNull);
    expect(find.text('Restore version 1?'), findsNothing);
  });

  testWidgets('shows why a restore failed', (tester) async {
    await show(tester, (_FailingRollback()..saveRevision(fbCreateRevision(form([f('a')], 1)))));
    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore this version'));
    await tester.pumpAndSettle();
    expect(find.text('Version 1 couldn’t be restored: the server said no'), findsOneWidget);
  });

  testWidgets('loads from an async store, shows its failure, and reloads for another form', (tester) async {
    final slow = _AsyncStore(seed());
    await tester.runAsync(() async {});
    await show(tester, slow);
    expect(find.text('Loading versions…'), findsOneWidget);
    slow.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Version 2'), findsOneWidget);

    final bad = _AsyncStore(seed(), fail: true)..gate.complete();
    hostKey.currentState!.swap(s: bad);
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);
    expect(find.text('Version 2'), findsNothing);

    hostKey.currentState!.swap(id: 'x');
    await tester.pumpAndSettle();
    expect(find.textContaining('offline'), findsOneWidget);
  });

  testWidgets('a slow answer for an earlier form never replaces the newer one', (tester) async {
    final slow = _AsyncStore(seed());
    await show(tester, slow);
    hostKey.currentState!.swap(s: seed());
    await tester.pumpAndSettle();
    expect(find.text('Version 2'), findsOneWidget);
    slow.gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Version 2'), findsOneWidget);
    expect(find.text('Loading versions…'), findsNothing);
  });

  testWidgets('has accessible names and meets the tap target guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await show(tester, seed());
    expect(find.bySemanticsLabel('Version history'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  group('UiFormBuilder history', () {
    testWidgets('has no History button without a store', (tester) async {
      await pumpUi(tester, SizedBox(width: 390, height: 800, child: UiFormBuilder(definition: form([f('a')], 3))), size: const Size(390, 844));
      expect(find.text('History'), findsNothing);
    });

    testWidgets('opens the history, restores a version as one undo step and tells the host', (tester) async {
      final controller = UiFormBuilderController();
      addTearDown(controller.dispose);
      final store = seed();
      UiFormDefinition? restored;
      await pumpUi(
        tester,
        SizedBox(width: 390, height: 800, child: UiFormBuilder(controller: controller, definition: form([f('a'), f('b')], 3), revisionStore: store, onRestored: (d) => restored = d)),
      );
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Version 2'), findsOneWidget);
      await tester.tap(find.text('Restore').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Restore this version'));
      await tester.pumpAndSettle();
      expect(find.text('Version 2'), findsNothing, reason: 'the drawer closes');
      expect(find.text('Loaded the earlier version as a draft'), findsOneWidget);
      expect(restored, isNotNull);
      expect(restored!.revision, 3);
      expect([for (final e in controller.def.pages[0].elements) [e.id, e.archived ?? false]], [['a', false], ['b', true]]);
      controller.undo();
      expect([for (final e in controller.def.pages[0].elements) [e.id, e.archived ?? false]], [['a', false], ['b', false]]);
    });
  });
}
