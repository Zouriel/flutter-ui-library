/// Exports for the workflow area: the workflow builder, the runtime widgets (workflow panel, task
/// inbox and drawer, run view, audit log, permissions, global settings), and the definition model,
/// helpers and REST client they share. It reads and writes the same JSON as the web `@zouriel/ui/workflow`.
library;

export '../workflow/api.dart';
export '../workflow/clock.dart';
export '../workflow/definition.dart';
export '../workflow/global_settings.dart';
// The task inbox is internal: apps use UiWorkflowTasksDrawer.
export '../workflow/runtime.dart' hide WfTaskInbox, WfTaskInboxState;
export '../workflow/panel.dart';
export '../workflow/permissions.dart';
export '../workflow/history.dart' show wfDescribeHistory, wfOutcomeLabel, wfAuditActionLabel, wfActorLabel, wfStepTimedOut, wfCommentRequired, wfRemarksLabel, wfRemarksFor;
export '../workflow/layout.dart';
export '../workflow/schema.dart';
export '../workflow/store.dart';
export '../workflow/tasks_drawer.dart';
export '../workflow/scope.dart' show UiWorkflowBuilderLayout;
export '../workflow/workflow_builder.dart';
