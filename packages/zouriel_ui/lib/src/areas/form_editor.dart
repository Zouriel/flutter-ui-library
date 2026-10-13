/// Exports for the form_editor area (owned by that area's port; see docs/CONVENTIONS.md).
///
/// The form builder's editor: the builder screen, its panels, and the global settings editor.
/// It edits the same definition JSON as the web `ui-form-builder`.
library;

export '../form_builder/editor/builder_store.dart' show UiFormBuilderController, UiFbBuilderScope, UiFbRefOption, sameForm;
