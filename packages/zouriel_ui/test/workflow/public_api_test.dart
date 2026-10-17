import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

// Mirrors @zouriel/ui f845ff8 (public-api.spec.ts): apps get the components and helpers they use;
// the runtime views' inner parts and the permissions helpers stay internal.

void main() {
  test('exports the components and helpers apps use', () {
    // Referenced here, so the test only compiles while they are exported.
    final used = <Object>[
      UiWorkflowBuilder.new, UiWorkflowPanel.new, UiWorkflowAudit.new, UiWorkflowStateBadge.new, UiWorkflowTasksDrawer.new,
      UiWorkflowPermissions.new, UiWorkflowGlobalSettings.new, UiWorkflowHttpApi.new, UiWorkflowClock.new, createWorkflow, createStep,
      insertStep, moveStep, removeStep, indexSteps, listSteps, tokensAt, describeTrigger, describeStep, autoLayout, wfStatesFrom,
      wfDescribeHistory,
    ];
    expect(used, hasLength(22));
  });

  test('keeps the runtime views\' inner parts internal', () {
    final src = File('lib/src/areas/workflow.dart').readAsStringSync();
    // Every file with inner parts is exported by name only.
    for (final f in ['runtime', 'panel', 'permissions', 'history', 'tasks_drawer', 'global_settings']) {
      expect(RegExp("export '../workflow/$f\\.dart' show [^;]+;").hasMatch(src), isTrue, reason: '$f is exported by name');
    }
    final shown = [for (final m in RegExp(r'show ([^;]+);').allMatches(src)) ...m.group(1)!.split(',').map((x) => x.trim())];
    for (final name in [
      'showWfDecideDialog', 'WfRecordActions', 'WfTaskInbox', 'WfRunView', 'wfRemarksFor', 'wfPanelPath', 'permissionRows', 'emptyWhoText',
      'sameWho', 'wfFormAnswers', 'wfSkipValue',
    ]) {
      expect(shown, isNot(contains(name)), reason: name);
    }
  });
}
