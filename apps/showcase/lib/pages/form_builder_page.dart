import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'form_builder_sample.dart';

const _json = JsonEncoder.withIndent('  ');

/// The showcase has no file-picker plugin; this stands in for one.
Future<List<UiPickedFile>?> _fakePicker({required bool multiple, required List<String> accept}) async =>
    const [UiPickedFile(name: 'transcript-2026.pdf', size: 184320, mimeType: 'application/pdf')];

/// The form renderer page: fill in, edit and view the sample form, a small answers studio, the
/// source picker, and the integration notes. The builder UI is a later (tablet) phase.
class FormBuilderPage extends StatefulWidget {
  const FormBuilderPage({super.key});

  @override
  State<FormBuilderPage> createState() => _FormBuilderPageState();
}

class _FormBuilderPageState extends State<FormBuilderPage> {
  UiFormMode _mode = UiFormMode.create;
  UiFormSubmission? _last;
  Object? _picked;
  List<Object?> _pickedMany = const [];

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final caption = context.uiText.caption.copyWith(color: t.textMuted);
    return DocPage(
      eyebrow: 'Flagship',
      title: 'Form builder',
      lead: 'Forms are plain JSON made by the web form builder. On the phone, UiFormRenderer fills them in, '
          'and lets staff correct or read saved answers. It reads the same definitions and saves the same answer JSON as the web renderer, '
          'so a form built on the web runs here unchanged and answers saved by either open in the other.',
      children: [
        DocSection(
          name: 'Renderer',
          widget: 'UiFormRenderer',
          summary: 'Fills in a definition. Problems show when a question is left (or only on Continue, per form), and when someone tries '
              'to move on, all of the page’s problems are listed at the top; tapping one jumps to the question. Hidden questions never block '
              'submitting. Give it saved data to edit (it tracks dirty and lists the changes next to Save) or to view, where every page shows '
              'at once as text. Long forms come in steps with Back and Continue and a progress bar. It doesn’t scroll itself: put it in a scroll view.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: UiSegmented<UiFormMode>(
                label: 'Mode',
                size: UiSize.sm,
                value: _mode,
                onChanged: (m) => setState(() => _mode = m),
                options: const [
                  UiSegmentedOption(value: UiFormMode.create, label: 'New answers'),
                  UiSegmentedOption(value: UiFormMode.edit, label: 'Edit saved'),
                  UiSegmentedOption(value: UiFormMode.view, label: 'View saved'),
                ],
              ),
            ),
            UiFormRenderer(
              key: ValueKey(_mode),
              definition: sampleForm,
              data: _mode == UiFormMode.create ? null : sampleAnswers,
              mode: _mode,
              optionSources: demoSources,
              filePicker: _fakePicker,
              onSubmitted: (s) => setState(() => _last = s),
            ),
            if (_last != null) ...[
              Text('Submitted JSON', style: caption),
              DocCode(code: _json.convert(_last!.toJson()), language: 'JSON'),
            ],
          ]),
          code: '''UiFormRenderer(definition: formJson, optionSources: [students, courses], onSubmitted: save)
UiFormRenderer(definition: formJson, data: saved, onSubmitted: (s) => update(s.data))   // edit
UiFormRenderer(definition: formJson, data: saved, mode: UiFormMode.view)                  // read only

// Your own buttons: showActions: false, then
final key = GlobalKey<UiFormRendererState>();
key.currentState!.submit();          // the submission, or null (problems shown)
key.currentState!.engine.dirty;      // and data, changes, pageIndex...''',
          api: const [
            ApiRow('definition', 'Object', 'The form: a UiFormDefinition or its stored JSON map (migrated on load). Usually the published version.'),
            ApiRow('data', 'UiJson?', 'Saved answers to edit or view. Unknown keys and answers to questions hidden at the time are kept.'),
            ApiRow('mode', 'UiFormMode?', 'edit shows “Save changes” and a change list; view shows every page as text and never validates.', def: 'edit with data, else create'),
            ApiRow('validators', 'List<UiFbValidatorDef>', 'App checks (sync or async), on top of the built-in ones.', def: '[]'),
            ApiRow('optionSources', 'List<UiFbOptionSourceDef>', 'Lists sourced dropdowns search. Use the same ones the builder had.', def: '[]'),
            ApiRow('globalSettings / httpSources', 'UiFormGlobalSettings? / UiFbHttpSourcesOptions', 'Makes the lists from the global settings searchable, through your fetch (login, allowed origins).'),
            ApiRow('filePicker', 'UiFilePicker?', 'Opens the platform file picker for file questions (wrap file_picker or file_selector).'),
            ApiRow('uploader', 'UiFbUploader?', '(file, field) => Future<UiFbFileValue>: uploads as files are picked. Without it, picked files come back in submission.files.'),
            ApiRow('submitLabel / cancelLabel', 'String?', 'Last button’s text (else the form’s, then Submit / Save changes); a Cancel button.'),
            ApiRow('busy', 'bool', 'Shows the submit button as busy while you save.', def: 'false'),
            ApiRow('showTitle / showActions', 'bool', 'The form’s title and description; the buttons.', def: 'true'),
            ApiRow('today', 'String Function()?', 'Fixes today (YYYY-MM-DD) for date rules and ages.'),
          ],
          callbacks: const [
            ApiRow('onSubmitted', 'ValueChanged<UiFormSubmission>', '{formId, revision, data, submittedAt, files} once everything on the route is valid. Store data with revision.'),
            ApiRow('onValueChanged', 'ValueChanged<UiJson>', 'The data as it would be saved, after every change.'),
            ApiRow('onDirtyChanged', 'ValueChanged<bool>', 'Whether the answers differ from what the form opened with.'),
            ApiRow('onCancelled', 'VoidCallback', 'The Cancel button was pressed.'),
            ApiRow('submit() / reset()', 'UiFormRendererState', 'Validate and submit; start over from the given data on the first page.'),
            ApiRow('engine', 'UiFormEngine', 'The running form: data, dirty, changes, pageIndex, setValue...'),
          ],
        ),
        const DocSection(
          name: 'Answers studio',
          widget: 'UiFormRenderer in three modes',
          summary: 'A small version of the web form studio: fill in the sample form, save the answers (here in memory, in your app in your '
              'database), then open a saved answer to correct it or to read it, and see the JSON that is stored. The saved answer used '
              'by Edit and View is the same answer the web showcase uses.',
          demo: _AnswersStudio(),
        ),
        DocSection(
          name: 'Source picker',
          widget: 'UiFbSourcePicker',
          summary: 'The searchable dropdown the renderer uses for questions that take their options from a list in your app: type to search '
              '(after a short pause), scroll to the end to load the next page, pick one, or several as chips. A search still running when the '
              'next starts is cancelled through its signal. Answers are saved as {value, label}, so they stay readable if the record is renamed.',
          demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            UiFormField(
              label: 'Student',
              child: UiFbSourcePicker(source: studentsSource, value: _picked, placeholder: 'Search students…', onChanged: (v) => setState(() => _picked = v)),
            ),
            UiFormField(
              label: 'Courses (health)',
              child: UiFbSourcePicker(
                source: coursesSource,
                params: const {'programme': 'health'},
                multiple: true,
                value: _pickedMany,
                onChanged: (v) => setState(() => _pickedMany = (v as List?) ?? const []),
              ),
            ),
            Text('Value: ${jsonEncode({'student': _picked, 'courses': _pickedMany})}', style: caption),
          ]),
          code: '''final students = UiFbOptionSource(
  type: 'students',
  label: 'Students',
  params: [UiFbSourceParamSpec(key: 'faculty', label: 'Faculty')],
  pageSize: 20,
  search: (q) => api.students(q: q.query, page: q.page, size: q.pageSize, faculty: q.params['faculty'], cancel: q.signal),
  // -> UiFbSourcePage(items: [UiFbSourceItem(value: 'S240117', label: 'Aminath Shareef')], total: 600)
);

UiFbSourcePicker(source: students, value: picked, onChanged: (v) => setState(() => picked = v))''',
          api: const [
            ApiRow('source', 'UiFbOptionSourceDef', 'The list: type, label, params, pageSize, minQueryLength, debounceMs and search.'),
            ApiRow('params', 'Map<String, Object?>', 'The source’s settings, resolved. A required one that is blank shows “Choose … first.”', def: '{}'),
            ApiRow('multiple', 'bool', 'Several choices, as chips. Backspace in the empty box removes the last.', def: 'false'),
            ApiRow('value / onChanged', 'Object? / ValueChanged<Object?>', '{value, label} (or a list of them); bare values are read as {value: v, label: "v"}.'),
            ApiRow('placeholder / enabled / invalid / label', '', 'As on the other fields.'),
          ],
        ),
        const DocSection(
          name: 'Integrating it',
          widget: 'JSON in, JSON out',
          summary: 'Your app stores three kinds of JSON: forms (made by the web builder), answers (one object per submission, made by the '
              'renderer) and app-wide settings. The widgets never call your server, except lists through the search functions you provide.',
          code: '''// 1. Load: stored forms go through migrateDefinition, which fills in defaults and upgrades older versions.
final form = migrateDefinition(await api.getForm(id));

// 2. Fill in. Store data with the revision it was made against.
UiFormRenderer(definition: form, optionSources: sources,
  onSubmitted: (s) => api.saveAnswers(formId: s.formId, revision: s.revision, data: s.data));

// 3. Edit or view: pass the stored data back.
UiFormRenderer(definition: form, data: answer.data, onSubmitted: (s) => api.updateAnswers(answer.id, s.data));
UiFormRenderer(definition: form, data: answer.data, mode: UiFormMode.view);

// Without UI: the same engine the renderer runs (rules, checks, calculations, data shaping).
final engine = UiFormEngine.fromJson(form, data: saved);
engine.setValue('f_name', null, 'Aminath');
final submission = engine.submit();   // null when something is wrong''',
        ),
      ],
    );
  }
}

/// Saved answers kept in memory, each one openable to edit or view, with its JSON.
class _AnswersStudio extends StatefulWidget {
  const _AnswersStudio();

  @override
  State<_AnswersStudio> createState() => _AnswersStudioState();
}

class _Answer {
  _Answer(this.id, this.data, this.revision, this.savedAt);
  final int id;
  UiJson data;
  final num? revision;
  String savedAt;
}

class _AnswersStudioState extends State<_AnswersStudio> {
  late final List<_Answer> _answers = [_Answer(1, sampleAnswers, sampleForm['revision'] as num?, 'sample')];
  int _seq = 1;

  /// null: the list. Otherwise the answer open (id 0 = a new one) and how.
  ({int id, UiFormMode mode})? _open;
  int? _jsonFor;

  _Answer? _find(int id) {
    for (final a in _answers) {
      if (a.id == id) return a;
    }
    return null;
  }

  void _saved(UiFormSubmission s) {
    setState(() {
      final open = _open!;
      if (open.id == 0) {
        _answers.add(_Answer(++_seq, s.data, s.revision, s.submittedAt));
        _jsonFor = _seq;
      } else {
        final a = _find(open.id)!;
        a.data = s.data;
        a.savedAt = s.submittedAt;
        _jsonFor = a.id;
      }
      _open = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    final open = _open;
    if (open != null) {
      final a = open.id == 0 ? null : _find(open.id);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        Row(children: [
          UiButton(
            label: 'All answers',
            variant: UiButtonVariant.ghost,
            size: UiSize.sm,
            icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01, size: 14),
            onPressed: () => setState(() => _open = null),
          ),
        ]),
        UiFormRenderer(
          key: ValueKey(open),
          definition: sampleForm,
          data: a?.data,
          mode: open.mode,
          optionSources: demoSources,
          filePicker: _fakePicker,
          cancelLabel: 'Cancel',
          onCancelled: () => setState(() => _open = null),
          onSubmitted: _saved,
        ),
      ]);
    }
    final shown = _jsonFor == null ? null : _find(_jsonFor!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
      Row(children: [
        Expanded(child: Text('${_answers.length} saved ${_answers.length == 1 ? 'answer' : 'answers'}', style: ty.label.copyWith(color: t.text))),
        UiButton(
          label: 'New answer',
          size: UiSize.sm,
          icon: const UiIcon(HugeIcons.strokeRoundedAdd01, size: 14),
          onPressed: () => setState(() => _open = (id: 0, mode: UiFormMode.create)),
        ),
      ]),
      for (final a in _answers)
        UiCard(
          padding: UiSize.sm,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
            Text('${a.data['full_name'] ?? 'No name'}', style: ty.body.copyWith(fontWeight: FontWeight.w600, color: t.text)),
            Text('#${a.id} · ${a.data['programme'] ?? 'no programme'} · revision ${a.revision ?? '-'} · ${a.savedAt}',
                style: ty.caption.copyWith(color: t.textMuted)),
            Wrap(spacing: t.space2, runSpacing: t.space2, children: [
              UiButton(label: 'Edit', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _open = (id: a.id, mode: UiFormMode.edit))),
              UiButton(label: 'View', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _open = (id: a.id, mode: UiFormMode.view))),
              UiButton(
                label: _jsonFor == a.id ? 'Hide JSON' : 'JSON',
                size: UiSize.sm,
                variant: UiButtonVariant.ghost,
                onPressed: () => setState(() => _jsonFor = _jsonFor == a.id ? null : a.id),
              ),
            ]),
          ]),
        ),
      if (shown != null) DocCode(code: _json.convert(shown.data), language: 'JSON'),
    ]);
  }
}
