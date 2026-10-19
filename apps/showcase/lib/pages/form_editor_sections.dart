import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'form_builder_sample.dart';

// Sections added to the Form builder page by the form editor port: the builder itself, the global
// settings editor, and the controller. Kept in their own file so the renderer's sections stay as
// they are.

/// The builder, global settings and controller sections.
List<Widget> formEditorSections() => const [_BuilderSection(), _GlobalSettingsSection(), _ControllerSection()];

const _pretty = JsonEncoder.withIndent('  ');

class _BuilderSection extends StatefulWidget {
  const _BuilderSection();
  @override
  State<_BuilderSection> createState() => _BuilderSectionState();
}

class _BuilderSectionState extends State<_BuilderSection> {
  final _controller = UiFormBuilderController();
  late UiFormDefinition _form = migrateDefinition(sampleForm);
  UiFormDefinition? _published;
  bool _answered = false;
  String _note = '';
  bool _showJson = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publish() {
    final errors = _controller.problems.where((p) => p.severity == 'error').length;
    if (errors > 0) {
      setState(() => _note = 'Fix $errors problem${errors > 1 ? 's' : ''} first (see Logic).');
      return;
    }
    final changes = _controller.diff?.summary.length ?? 0;
    setState(() {
      _form = _form.clone()..revision = (_form.revision ?? 0) + 1;
      _published = _form.clone();
      _note = 'Published revision ${_form.revision}${changes > 0 ? ' with $changes change${changes > 1 ? 's' : ''}' : ''}.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final caption = context.uiText.caption.copyWith(color: t.textMuted);
    return DocSection(
      name: 'Builder',
      widget: 'UiFormBuilder',
      summary: 'Admin staff build forms here. On a phone the page fills the screen: tap a question to select it and get its toolbar '
          '(settings, move up or down, duplicate, delete, more), hold it to open its settings in a sheet, and add fields from the Add field '
          'button. Drag a card by its grip to move it, into or out of a section, or onto another page’s tab. On a tablet the field list, the '
          'form and the settings sit side by side (from 1100 wide; between 720 and 1100 the field list opens from Add). Every rule reads as a '
          'sentence: show or require a question only when other answers say so, fill it in automatically, jump between pages. Logic lists '
          'every rule and anything to fix; Preview fills the form in. Pass the published version and its answer count so the builder protects '
          'saved answers: it archives instead of deleting, locks stored option values and remembers renamed keys. Undo and redo keep working '
          'after you publish. It saves exactly the JSON the web builder saves.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        Container(
          height: 720,
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          clipBehavior: Clip.antiAlias,
          child: UiFormBuilder(
            controller: _controller,
            definition: _form,
            published: _published,
            submissionCount: _answered ? 12 : 0,
            optionSources: demoSources,
            onChanged: (d) => setState(() => _form = d),
            actions: UiButton(label: _published == null ? 'Publish' : 'Publish changes', size: UiSize.sm, onPressed: _publish),
          ),
        ),
        Wrap(spacing: t.space3, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
          UiSwitch(
            value: _answered,
            label: 'Pretend the published form has 12 answers',
            onChanged: _published == null ? null : (v) => setState(() => _answered = v),
          ),
          if (_note.isNotEmpty) Semantics(liveRegion: true, child: Text(_note, style: caption)),
        ]),
        Align(
          alignment: Alignment.centerLeft,
          child: UiButton(label: _showJson ? 'Hide the form JSON' : 'Show the form JSON', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: () => setState(() => _showJson = !_showJson)),
        ),
        if (_showJson) DocCode(code: _pretty.convert(_form.toJson()), language: 'JSON'),
      ]),
      code: '''UiFormDefinition form = migrateDefinition(await api.getForm(id));   // or createDefinition(defaults: settings.defaults)
UiFormDefinition? live;                                                 // the published copy

UiFormBuilder(
  definition: form,
  onChanged: (d) => setState(() => form = d),    // save it, or keep it for your Save button
  published: live,
  submissionCount: answerCount,
  optionSources: [students, courses],
  globalSettings: settings,
  actions: UiButton(label: 'Publish', onPressed: publish),
)

void publish() {
  if (controller.problems.any((p) => p.severity == 'error')) return;   // listed under Logic
  setState(() {
    form = form.clone()..revision = (live?.revision ?? 0) + 1;
    live = form.clone();
  });
  api.publish(form.toJson());
}''',
      api: const [
        ApiRow('definition', 'Object? (UiFormDefinition or JSON)', 'The form. Hand back what onChanged gives you. Another form (a different id or other content) loads and clears undo history; the same form with only revision changed (a published copy) keeps it.'),
        ApiRow('onChanged', 'ValueChanged<UiFormDefinition>', 'Every edit, as a new definition (the one you passed is never changed).'),
        ApiRow('controller', 'UiFormBuilderController?', 'Drive it from outside: select, undo/redo, clearHistory, problems, diff. One is made when not given.'),
        ApiRow('published', 'UiFormDefinition?', 'The version people answer now. Drives the unpublished-changes pill and answer protection.', def: 'null'),
        ApiRow('submissionCount', 'int', 'Answers the published version has. Above zero: archive instead of delete, lock saved option values, remember renamed keys, only similar type changes.', def: '0'),
        ApiRow('validators', 'List<UiFbValidatorDef>', 'App checks for the “Add a check” list, on top of the built-in ones.', def: '[]'),
        ApiRow('optionSources', 'List<UiFbOptionSourceDef>', 'Searchable lists for Options, Data source.', def: '[]'),
        ApiRow('globalSettings / httpSources', 'UiFormGlobalSettings? / UiFbHttpSourcesOptions', 'Lists from the global settings editor become data sources too.'),
        ApiRow('actions', 'Widget?', 'Your buttons (Save, Publish) at the end of the top bar.'),
        ApiRow('showTitle', 'bool', 'Show the form title in the top bar. Turn off when your own header already names the form.', def: 'true'),
      ],
    );
  }
}

class _GlobalSettingsSection extends StatefulWidget {
  const _GlobalSettingsSection();
  @override
  State<_GlobalSettingsSection> createState() => _GlobalSettingsSectionState();
}

class _GlobalSettingsSectionState extends State<_GlobalSettingsSection> {
  UiFormGlobalSettings _settings = UiFormGlobalSettings.fromJson({
    'version': 1,
    'sources': [
      {
        'type': 'people',
        'label': 'People',
        'description': 'A public demo API with 208 people',
        'url': 'https://dummyjson.com/users/search',
        'paging': 'offset',
        'pageParam': 'skip',
        'pageSizeParam': 'limit',
        'itemsPath': 'users',
        'valueField': 'id',
        'labelField': '{firstName} {lastName}',
        'descriptionField': 'email',
        'totalPath': 'total',
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    return DocSection(
      name: 'Global settings',
      widget: 'UiFormGlobalSettingsEditor',
      summary: 'For the app’s settings screen: admins set up the lists every form can search (the address, how it searches and pages, which '
          'fields are the value and the label) and test them on the spot with “Run test”, plus what new forms start with. Lists the app '
          'registers in code show read-only. It saves plain JSON; pass it to UiFormBuilder and UiFormRenderer as globalSettings. Requests go '
          'through httpSources, where the app adds its login and lists the servers it allows, so no keys are stored in settings.',
      demo: UiFormGlobalSettingsEditor(
        settings: _settings,
        usage: const {'people': 2},
        builtIn: demoSources,
        httpSources: const UiFbHttpSourcesOptions(allowedOrigins: ['https://dummyjson.com']),
        onChanged: (s) => setState(() => _settings = s),
      ),
      code: '''UiFormGlobalSettingsEditor(
  settings: settings,
  usage: {'people': 2},                          // forms using each list, to warn before deleting it
  builtIn: [students, courses],                  // lists registered in code (read-only here)
  httpSources: UiFbHttpSourcesOptions(
    allowedOrigins: ['https://api.example.com'],
    fetch: (url, signal) => myHttp.getJson(url),  // adds the session or token
  ),
  onChanged: (s) => api.saveFormSettings(s.toJson()),
)

UiFormBuilder(definition: form, globalSettings: settings, onChanged: save)''',
      api: const [
        ApiRow('settings', 'UiFormGlobalSettings', 'The stored JSON (createGlobalSettings() for a new app).'),
        ApiRow('onChanged', 'ValueChanged<UiFormGlobalSettings>', 'Every edit, as a new copy.'),
        ApiRow('usage', 'Map<String, int>', 'How many forms use each list, by key. Warns before deleting or re-keying one.', def: '{}'),
        ApiRow('builtIn', 'List<UiFbOptionSourceDef>', 'Lists registered in code: shown read-only, their keys reserved.', def: '[]'),
        ApiRow('httpSources', 'UiFbHttpSourcesOptions', 'The fetch to use and the servers lists may call.'),
      ],
    );
  }
}

class _ControllerSection extends StatelessWidget {
  const _ControllerSection();

  @override
  Widget build(BuildContext context) {
    return const DocSection(
      name: 'Controller and panels',
      widget: 'UiFormBuilderController',
      summary: 'The builder’s state: the definition, what’s selected, and undo/redo (typing in one box undoes as one step). Pass your own '
          'to read problems and changes before publishing, or to select a question from elsewhere. The panels (UiFbCanvas, UiFbPalette, '
          'UiFbInspector, UiFbLogicOverview, UiFbPreview) work on their own inside a UiFbBuilderScope, for apps that lay them out differently.',
      code: '''final controller = UiFormBuilderController(definition: form);

controller.problems;            // List<UiFbProblem>: missing keys, loops, rules pointing at deleted questions
controller.diff?.summary;       // what changed since published, one line each
controller.select('fld_x');     // a question, section or page; null for the form
controller.undo(); controller.redo(); controller.clearHistory();

UiFbBuilderScope(controller: controller, child: Row(children: [
  Expanded(child: UiFbCanvas(onOpen: openSettings)),
  SizedBox(width: 340, child: UiFbInspector()),
]))''',
      api: [
        ApiRow('def', 'UiFormDefinition', 'The form being built.'),
        ApiRow('selectedId / select(id)', 'String?', 'What the settings show; null is the form itself.'),
        ApiRow('problems / errorCount', 'List<UiFbProblem> / int', 'Things to fix, including sourced fields whose list is missing or not set up.'),
        ApiRow('diff', 'UiFbDiff?', 'What changed since published (added, archived, renamed keys, type changes, removed options, changed rules).'),
        ApiRow('canUndo / canRedo, undo(), redo()', '', 'History survives a published copy being handed back.'),
        ApiRow('clearHistory()', '', 'Forget undo/redo, e.g. after saving.'),
        ApiRow('load(definition)', '', 'Take a definition from outside (what the widget does when definition changes).'),
      ],
    );
  }
}
