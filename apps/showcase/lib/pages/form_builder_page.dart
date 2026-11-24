import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'form_builder_sample.dart';
import 'form_editor_sections.dart';

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
              'submitting. Give it saved values to edit (it tracks dirty and lists the changes next to Save) or to view, where every page shows '
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
              values: _mode == UiFormMode.create ? null : sampleAnswers,
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
UiFormRenderer(definition: formJson, values: saved, onSubmitted: (s) => update(s.values))   // edit
UiFormRenderer(definition: formJson, values: saved, mode: UiFormMode.view)                  // read only

// Your own buttons: showActions: false, then
final key = GlobalKey<UiFormRendererState>();
key.currentState!.submit();          // the submission, or null (problems shown)
key.currentState!.engine.dirty;      // and values, changes, pageIndex...''',
          api: const [
            ApiRow('definition', 'Object', 'The form: a UiFormDefinition or its stored JSON map (migrated on load). Usually the published version.'),
            ApiRow('values', 'UiJson?', 'Saved answers to edit or view. Unknown keys and answers to questions hidden at the time are kept.'),
            ApiRow('prefill', 'UiJson?', 'Starting answers for a new submission (create mode; 0.87.0): filled in without making it an edit (no change list, the normal Submit label); defaults still apply to questions without one, keys that are not questions are dropped. The form restarts when it changes.'),
            ApiRow('serverErrors', 'Map<String, Object>?', 'A server\'s 422 by data path (full_name, address.city, dependants[1].name), each a message or a list of them (0.87.0). Shown under their questions and in the summary, which takes focus; a message goes when its answer changes. Give a new map for each response; null or {} clears them.'),
            ApiRow('mode', 'UiFormMode?', 'edit shows “Save changes” and a change list; view shows every page as text and never validates.', def: 'edit with values, else create'),
            ApiRow('validators', 'List<UiFbValidatorDef>', 'App checks (sync or async), on top of the built-in ones.', def: '[]'),
            ApiRow('optionSources', 'List<UiFbOptionSourceDef>', 'Lists sourced dropdowns search. Use the same ones the builder had.', def: '[]'),
            ApiRow('globalSettings / httpSources', 'UiFormGlobalSettings? / UiFbHttpSourcesOptions', 'Makes the lists from the global settings searchable, through your fetch (login, allowed origins).'),
            ApiRow('filePicker', 'UiFilePicker?', 'Opens the platform file picker for file questions (wrap file_picker or file_selector).'),
            ApiRow('uploader', 'UiFbUploader?', '(file, field) => Future<UiFbFileValue>: uploads as files are picked. Without it, picked files come back in submission.files.'),
            ApiRow('locale', 'String?', 'The language to show the form in (en, dv, or dv-MV for the same language). Unknown codes fall back to the form’s default language. Changing it keeps the answers, and right-to-left languages lay the form out right to left.'),
            ApiRow('strings', 'UiFbStringOverrides?', 'The renderer’s own words (Submit, Continue, Back, Step x of y, Yes/No, default error messages, …) per language code, on top of the built-in English and Dhivehi: {\'fr\': {\'submit\': \'Envoyer\'}}. Wins, key by key, over UiFormStringsScope. Words the form author wrote always win over these.'),
            ApiRow('submitLabel / cancelLabel', 'String?', 'Last button’s text (else the form’s, then Submit / Save changes); a Cancel button.'),
            ApiRow('busy', 'bool', 'Shows the submit button as busy while you save.', def: 'false'),
            ApiRow('showTitle / showActions', 'bool', 'The form’s title and description; the buttons.', def: 'true'),
            ApiRow('today', 'String Function()?', 'Fixes today (YYYY-MM-DD) for date rules and ages.'),
          ],
          callbacks: const [
            ApiRow('onSubmitted', 'ValueChanged<UiFormSubmission>', '{formId, revision, locale, values, submittedAt, fields, files} once everything on the route is valid. locale is the language it was filled in; fields lists each answer’s path, key, label (in that language) and type. Store data with revision.'),
            ApiRow('onValueChanged', 'ValueChanged<UiJson>', 'The values as it would be saved, after every change.'),
            ApiRow('onDirtyChanged', 'ValueChanged<bool>', 'Whether the answers differ from what the form opened with.'),
            ApiRow('onCancelled', 'VoidCallback', 'The Cancel button was pressed.'),
            ApiRow('onServerErrorsUnmatched', 'ValueChanged<List<UiFbServerErrorItem>>', 'After non-empty serverErrors were applied: the ones that named no question ({path, message}), which the summary lists first as plain text.'),
            ApiRow('engine.setServerErrors(errors) / engine.serverUnmatched', 'List<UiFbServerErrorItem>', 'The same on the engine: returns (and keeps) the unmatched ones; a remaining server error blocks submit().'),
            ApiRow('submit() / reset()', 'UiFormRendererState', 'Validate and submit; start over from the given values on the first page.'),
            ApiRow('engine', 'UiFormEngine', 'The running form: values, dirty, changes, pageIndex, setValue...'),
            ApiRow('engine.strings / engine.setStrings(overrides)', 'UiFbStrings / void', 'The engine’s and renderer’s own words in the language in use (built-in table plus the strings option). Messages are worded again when the language or the overrides change. UiFormEngine(strings: …) sets them up front.'),
          ],
        ),
        DocSection(
          name: 'Form summary',
          widget: 'UiFormSummary',
          summary: 'Compact review card of answered, visible fields in definition order, keeping section headings and skipping fields hidden by conditions. Reuses UiFormEngine and formatValue.',
          demo: SizedBox(
            width: 380,
            child: UiFormSummary(
              definition: UiFormDefinition.fromJson(sampleForm),
              answers: sampleAnswers,
              marked: const ['full_name'],
              subtitle: 'Check every answer before you confirm.',
              footer: Row(spacing: t.space2, children: [
                Expanded(child: UiButton(variant: UiButtonVariant.outline, onPressed: () {}, child: const Text('Edit Answers'))),
                Expanded(child: UiButton(onPressed: () {}, child: const Text('Confirm & Submit'))),
              ]),
            ),
          ),
          code: "UiFormSummary(\n  definition: form,\n  answers: answers,\n  marked: ['full_name'],\n  footer: UiButton(onPressed: submit, child: Text('Confirm & Submit')),\n)",
          api: const [
            ApiRow('definition', 'UiFormDefinition', 'Form definition.'),
            ApiRow('answers', 'UiJson', 'Submitted or draft answers map.', def: '{}'),
            ApiRow('language', 'String?', 'Language code (en, dv, …); defaults to form default.'),
            ApiRow('marked', 'List<String>', 'Field paths to mark as assistant-filled.', def: '[]'),
            ApiRow('markedLabel', 'String', 'Legend label for marked fields.', def: 'Filled in by the assistant'),
            ApiRow('footer', 'Widget?', 'Optional footer slot (e.g. Edit / Confirm buttons).'),
          ],
        ),
        const DocSection(
          name: 'Starting answers and server errors',
          widget: 'UiFormRenderer(prefill:, serverErrors:)',
          summary: 'A new submission can open with answers already in it (prefill): a signed-in person\'s details, or what they gave an '
              'older version of the form. It stays a new submission: Submit, no change list, nothing counts as changed. When your server '
              'refuses a submission with errors by data path, pass them as serverErrors: each shows under its question and in the summary at '
              'the top, which takes focus, until the answer changes; paths that name no question are listed first in the summary and '
              'reported by onServerErrorsUnmatched.',
          demo: _PrefillServerDemo(),
          code: '''UiFormRenderer(
  definition: form,
  prefill: {'full_name': me.name, 'address': {'city': me.city}},
  serverErrors: errors, // a new map per response, e.g. the 422's errors with 'data.' taken off
  onServerErrorsUnmatched: (items) => log(items),
  onSubmitted: (s) async {
    final res = await api.submit(s.values);
    if (res.statusCode == 422) setState(() => errors = res.errors);
  },
)''',
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
        ...formEditorSections(),
        const DocSection(
          name: 'Integrating it',
          widget: 'JSON in, JSON out',
          summary: 'Your app stores three kinds of JSON: forms (made by the web builder), answers (one object per submission, made by the '
              'renderer) and app-wide settings. The widgets never call your server, except lists through the search functions you provide.',
          code: '''// 1. Load: stored forms go through migrateDefinition, which fills in defaults and upgrades older versions.
final form = migrateDefinition(await api.getForm(id));

// 2. Fill in. Store the values with the revision it was made against.
UiFormRenderer(definition: form, optionSources: sources,
  onSubmitted: (s) => api.saveAnswers(formId: s.formId, revision: s.revision, values: s.values));

// 3. Edit or view: pass the stored values back.
UiFormRenderer(definition: form, values: answer.values, onSubmitted: (s) => api.updateAnswers(answer.id, s.values));
UiFormRenderer(definition: form, values: answer.values, mode: UiFormMode.view);

// Without UI: the same engine the renderer runs (rules, checks, calculations, values shaping).
final engine = UiFormEngine.fromJson(form, values: saved, locale: 'dv', strings: {'dv': {'next': 'ދެން'}});
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
  _Answer(this.id, this.values, this.revision, this.savedAt);
  final int id;
  UiJson values;
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
        _answers.add(_Answer(++_seq, s.values, s.revision, s.submittedAt));
        _jsonFor = _seq;
      } else {
        final a = _find(open.id)!;
        a.values = s.values;
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
          values: a?.values,
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
            Text('${a.values['full_name'] ?? 'No name'}', style: ty.body.copyWith(fontWeight: FontWeight.w600, color: t.text)),
            Text('#${a.id} · ${a.values['programme'] ?? 'no programme'} · revision ${a.revision ?? '-'} · ${a.savedAt}',
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
      if (shown != null) DocCode(code: _json.convert(shown.values), language: 'JSON'),
    ]);
  }
}

/// Prefill and server errors: a short form opened with a signed-in person's details, and a button
/// that answers the way a server's 422 would.
class _PrefillServerDemo extends StatefulWidget {
  const _PrefillServerDemo();

  @override
  State<_PrefillServerDemo> createState() => _PrefillServerDemoState();
}

class _PrefillServerDemoState extends State<_PrefillServerDemo> {
  static const _form = {
    'schemaVersion': 1,
    'id': 'apply',
    'title': 'Apply for a permit',
    'pages': [
      {
        'id': 'p1',
        'elements': [
          {'kind': 'field', 'id': 'name', 'type': 'text', 'key': 'full_name', 'label': 'Full name', 'required': true},
          {'kind': 'field', 'id': 'phone', 'type': 'text', 'key': 'phone', 'label': 'Phone'},
          {
            'kind': 'group',
            'id': 'addr',
            'key': 'address',
            'title': 'Address',
            'elements': [
              {'kind': 'field', 'id': 'city', 'type': 'text', 'key': 'city', 'label': 'City'},
            ],
          },
        ],
      },
    ],
  };

  Map<String, Object>? _errors;
  String _unmatched = '';
  String _submitted = '';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
      Wrap(spacing: t.space2, runSpacing: t.space2, children: [
        UiButton(
          label: 'Answer as the server would',
          size: UiSize.sm,
          variant: UiButtonVariant.outline,
          onPressed: () => setState(() => _errors = {
                'full_name': ['Use the name on your ID card.'],
                'address.city': 'We don\'t serve this city yet.',
                'office_note': 'Applications close at 2 pm today.',
              }),
        ),
        UiButton(label: 'Clear', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _errors = null)),
      ]),
      UiFormRenderer(
        definition: _form,
        prefill: const {'full_name': 'Aisha Ali', 'address': {'city': 'Addu City'}, 'efaas_id': 'A123456'},
        serverErrors: _errors,
        onServerErrorsUnmatched: (items) => setState(() => _unmatched = items.isEmpty ? 'Every error named a question.' : 'Named no question: ${items.map((i) => i.path).join(', ')}'),
        onSubmitted: (s) => setState(() => _submitted = 'Submitted: ${jsonEncode(s.values)}'),
      ),
      if (_unmatched.isNotEmpty) UiText(_unmatched, color: t.textSecondary),
      if (_submitted.isNotEmpty) UiText(_submitted, color: t.textSecondary),
    ]);
  }
}
