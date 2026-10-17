/// Exports for the workflow area: the workflow builder, the runtime widgets (record panel, task
/// inbox, run view, audit log, global settings), and the definition model, helpers and REST client
/// they share. It reads and writes the same JSON as the web `@zouriel/ui/workflow`.
library;

export '../workflow/api.dart';
export '../workflow/definition.dart';
export '../workflow/layout.dart';
export '../workflow/schema.dart';
export '../workflow/store.dart';
