/// Exports for the workflow area: the workflow builder, the runtime widgets (record panel, task
/// inbox, run view, audit log, global settings), and the definition model, helpers and REST client
/// they share. It reads and writes the same JSON as the web `@zouriel/ui/workflow`.
library;

export '../workflow/api.dart';
export '../workflow/clock.dart';
export '../workflow/definition.dart';
export '../workflow/global_settings.dart';
export '../workflow/runtime.dart';
export '../workflow/panel.dart';
export '../workflow/history.dart' show wfDescribeHistory, wfOutcomeLabel, wfAuditActionLabel;
export '../workflow/layout.dart';
export '../workflow/schema.dart';
export '../workflow/store.dart';
export '../workflow/scope.dart' show UiWorkflowBuilderLayout;
export '../workflow/workflow_builder.dart';
