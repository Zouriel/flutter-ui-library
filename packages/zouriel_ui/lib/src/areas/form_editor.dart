/// Exports for the form_editor area (owned by that area's port; see docs/CONVENTIONS.md).
///
/// The form builder's editor: the builder screen, its panels, and the global settings editor.
/// It edits the same definition JSON as the web `ui-form-builder`.
library;

export '../form_builder/editor/builder_canvas.dart' show UiFbCanvas;
export '../form_builder/editor/builder_condition.dart' show UiFbConditionEditor, UiFbValueInput;
export '../form_builder/editor/builder_dnd.dart' show FbDnd, FbDragPayload, FbDropState;
export '../form_builder/editor/builder_editors.dart' show UiFbOptionsEditor, UiFbChecksEditor, UiFbCalcEditor;
export '../form_builder/editor/builder_inspector.dart' show UiFbInspector;
export '../form_builder/editor/builder_logic.dart' show UiFbLogicOverview;
export '../form_builder/editor/builder_palette.dart' show UiFbPalette;
export '../form_builder/editor/builder_preview.dart' show UiFbPreview;
export '../form_builder/editor/builder_source.dart' show UiFbSourceSettings;
export '../form_builder/editor/builder_store.dart' show UiFormBuilderController, UiFbBuilderScope, UiFbRefOption, sameForm;
export '../form_builder/editor/form_builder.dart' show UiFormBuilder, UiFormBuilderState, UiFormBuilderView, UiFormBuilderLayout;
export '../form_builder/editor/settings_fields.dart' show UiFbSettingsFields, UiFbSettingsPatch;
