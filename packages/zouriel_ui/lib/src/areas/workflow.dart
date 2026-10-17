/// Exports for the workflow area: the workflow builder, the runtime widgets (workflow panel, tasks
/// drawer, audit log, permissions, global settings), and the definition model,
/// helpers and REST client they share. It reads and writes the same JSON as the web `@zouriel/ui/workflow`.
library;

export '../workflow/api.dart';
export '../workflow/clock.dart';
export '../workflow/definition.dart';
export '../workflow/global_settings.dart' show UiWorkflowGlobalSettings, UiWorkflowGlobalSettingsState;
// What apps use, by name (the web public-api). The runtime views' inner parts (the decide dialog,
// record actions, task inbox, run view and their helpers) and the permissions helpers are internal;
// tests import them by path.
export '../workflow/runtime.dart' show UiWorkflowStateBadge, UiWorkflowAudit, UiWorkflowAuditState;
export '../workflow/panel.dart' show UiWorkflowPanel, UiWorkflowPanelState, UiWorkflowPanelLayout, UiWfPanelStep;
export '../workflow/permissions.dart' show UiWorkflowPermissions, UiWorkflowPermissionsState;
export '../workflow/history.dart' show wfDescribeHistory;
export '../workflow/layout.dart';
export '../workflow/schema.dart';
export '../workflow/store.dart';
export '../workflow/tasks_drawer.dart' show UiWorkflowTasksDrawer, UiWorkflowTasksDrawerState;
export '../workflow/scope.dart' show UiWorkflowBuilderLayout;
export '../workflow/workflow_builder.dart';
