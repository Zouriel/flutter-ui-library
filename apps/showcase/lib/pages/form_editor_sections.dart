import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:zouriel_ui/zouriel_ui.dart';

import '../docs/doc.dart';
import 'form_builder_sample.dart';

// Sections added to the Form builder page by the form editor port: the builder itself, the global
// settings editor, and the controller. Kept in their own file so the renderer's sections stay as
// they are.

/// The builder, global settings and controller sections.
List<Widget> formEditorSections() => const [_BuilderSection(), _LanguagesSection(), _RevisionsSection(), _GlobalSettingsSection(), _ControllerSection()];

const _pretty = JsonEncoder.withIndent('  ');

class _BuilderSection extends StatefulWidget {
  const _BuilderSection();
  @override
  State<_BuilderSection> createState() => _BuilderSectionState();
}

class _BuilderSectionState extends State<_BuilderSection> {
  final _controller = UiFormBuilderController();
  /// Where earlier published versions are kept: the builder's History button lists them and rolls one back into a draft.
  final _revisions = UiFbMemoryRevisionStore();
  late UiFormDefinition _form = migrateDefinition(sampleForm);
  UiFormDefinition? _published;
  bool _answered = false;
  String _note = '';
  bool _showJson = false;

  @override
  void dispose() {
    _controller.dispose();
    _revisions.dispose();
    super.dispose();
  }

  void _publish() {
    final errors = _controller.problems.where((p) => p.severity == 'error').length;
    if (errors > 0) {
      setState(() => _note = 'Fix $errors problem${errors > 1 ? 's' : ''} first (see Logic).');
      return;
    }
    final changes = _controller.diff?.summary.length ?? 0;
    final previous = _published;
    setState(() {
      _form = _form.clone()..revision = (_form.revision ?? 0) + 1;
      _published = _form.clone();
      _revisions.saveRevision(fbCreateRevision(_form, previous: previous));
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
          'after you publish. With a revisionStore a History button lists the published versions: see what each changed and load one back as a '
          'draft (one undo step; nothing goes live until you publish). It saves exactly the JSON the web builder saves.',
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
            revisionStore: _revisions,
            onRestored: (_) => setState(() => _note = 'Loaded an earlier version as a draft. Publish it to make it live.'),
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
  revisionStore: revisions,                      // adds the History button
  onRestored: (draft) => showMessage('Loaded an earlier version as a draft'),
  submissionCount: answerCount,
  optionSources: [students, courses],
  globalSettings: settings,
  actions: UiButton(label: 'Publish', onPressed: publish),
)

void publish() {
  final previous = live;
  if (controller.problems.any((p) => p.severity == 'error')) return;   // listed under Logic
  setState(() {
    form = form.clone()..revision = (live?.revision ?? 0) + 1;
    live = form.clone();
  });
  revisions.saveRevision(fbCreateRevision(form, previous: previous));
  api.publish(form.toJson());
}''',
      api: const [
        ApiRow('definition', 'Object? (UiFormDefinition or JSON)', 'The form. Hand back what onChanged gives you. Another form (a different id or other content) loads and clears undo history; the same form with only revision changed (a published copy) keeps it.'),
        ApiRow('onChanged', 'ValueChanged<UiFormDefinition>', 'Every edit, as a new definition (the one you passed is never changed).'),
        ApiRow('controller', 'UiFormBuilderController?', 'Drive it from outside: select, undo/redo, clearHistory, problems, diff. One is made when not given.'),
        ApiRow('published', 'UiFormDefinition?', 'The version people answer now. Drives the unpublished-changes pill and answer protection.', def: 'null'),
        ApiRow('submissionCount', 'int', 'Answers the published version has. Above zero: archive instead of delete, lock saved option values, remember renamed keys, only similar type changes.', def: '0'),
        ApiRow('revisionStore', 'UiFbRevisionStore?', 'Where earlier published versions are kept. With one, a History button opens the list: see what each version changed and roll one back, which loads it as a new draft (one undo step; nothing goes live until you publish). Save each version with fbCreateRevision(definition, previous: ...) when you publish. UiFbMemoryRevisionStore is a ready-made in-memory one.', def: 'null'),
        ApiRow('onRestored', 'ValueChanged<UiFormDefinition>', 'A past version was loaded as the draft. It is already in the builder (and was handed to onChanged).'),
        ApiRow('validators', 'List<UiFbValidatorDef>', 'App checks for the “Add a check” list, on top of the built-in ones.', def: '[]'),
        ApiRow('optionSources', 'List<UiFbOptionSourceDef>', 'Searchable lists for Options, Data source.', def: '[]'),
        ApiRow('globalSettings / httpSources', 'UiFormGlobalSettings? / UiFbHttpSourcesOptions', 'Lists from the global settings editor become data sources too.'),
        ApiRow('actions', 'Widget?', 'Your buttons (Save, Publish) at the end of the top bar.'),
        ApiRow('showTitle', 'bool', 'Show the form title in the top bar. Turn off when your own header already names the form.', def: 'true'),
        ApiRow('Languages (top bar)', 'UI', 'Add or remove languages (Dhivehi is offered, or type any code), choose the default language and each language’s direction. With more than one language a switcher picks the language being edited; text in other languages shows the default text beneath its box. Stored in defaultLocale and supportedLocales.'),
      ],
    );
  }
}

class _LanguagesSection extends StatefulWidget {
  const _LanguagesSection();
  @override
  State<_LanguagesSection> createState() => _LanguagesSectionState();
}

class _LanguagesSectionState extends State<_LanguagesSection> {
  String _lang = 'en';

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final def = migrateDefinition(sampleForm);
    return DocSection(
      name: 'Languages',
      widget: 'UiFbText',
      summary: 'Every text a person reads (questions, help, options, titles, messages, button labels) is either a plain string or a map from '
          'language code to text. A form with one language stays plain strings; supportedLocales and defaultLocale turn on more. In the builder, '
          'add a language from Languages in the top bar, write everything in the default language first, then pick the other language in the '
          'switcher to translate each text with the default shown underneath. Right-to-left languages such as Dhivehi (Thaana) lay the canvas, '
          'the form and its inputs out right to left. Data keys and option values are never translated. A text with no translation shows in '
          'the default language, and the builder lists missing translations under Logic.',
      demo: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
        Align(
          alignment: Alignment.centerLeft,
          child: UiSegmented<String>(
            label: 'Language',
            size: UiSize.sm,
            value: _lang,
            options: [for (final l in fbLocales(def)) UiSegmentedOption(value: l.code, label: l.label)],
            onChanged: (v) => setState(() => _lang = v),
          ),
        ),
        UiFormRenderer(definition: sampleForm, locale: _lang, optionSources: demoSources),
      ]),
      code: '''// Every user-facing text: one string, or a map by language code.
const plain = UiFbText('Name');
final both = UiFbText.localized({'en': 'Name', 'dv': 'ނަން'});

final form = {
  'schemaVersion': 2, 'id': 'f', 'title': {'en': 'Survey', 'dv': 'ސާވޭ'},
  'defaultLocale': 'en',
  'supportedLocales': [{'code': 'en', 'label': 'English'}, {'code': 'dv', 'label': 'ދިވެހި', 'dir': 'rtl'}],
  'pages': [{'id': 'p', 'elements': [{'kind': 'field', 'id': 'a', 'type': 'text', 'key': 'name', 'label': {'en': 'Name', 'dv': 'ނަން'}}]}],
};

fbText(label, 'dv', 'en')        // the text in dv, else en, else the first one written
UiFormRenderer(definition: form, locale: 'dv')   // answers survive switching language''',
      api: const [
        ApiRow('UiFbText / UiFbText.localized(map)', 'class', 'A plain text, or one text per language code. Its JSON is a string or an object.'),
        ApiRow('fbText(text, [locale, defaultLocale])', 'String', 'A text in a language: that language, else the same base language, else the default, else the first text written.'),
        ApiRow('fbTextIn(text, locale, [defaultLocale]) / fbSetText(text, locale, value, [defaultLocale])', 'String / UiFbText', 'Read exactly one language (blank when missing), or write one. A text stays a plain string until a second language is written.'),
        ApiRow('fbLocales(def) / fbDefaultLocale(def) / fbResolveLocale(def, [requested]) / fbLocaleDir(def, [locale])', 'various', 'The form’s languages with label and direction filled in (default first), its default, the language a request resolves to, and a language’s direction.'),
        ApiRow('fbLocaleName(code) / fbDefaultDir(code)', 'String / UiFbDir', 'A language’s own name (ދިވެހި for dv) and its usual direction (Dhivehi, Arabic, Hebrew, Persian and Urdu are right to left).'),
      ],
    );
  }
}

class _RevisionsSection extends StatelessWidget {
  const _RevisionsSection();

  @override
  Widget build(BuildContext context) {
    return const DocSection(
      name: 'Revisions',
      widget: 'UiFbRevisionStore',
      summary: 'A snapshot of the form is kept every time you publish, and any earlier version can be brought back as a new draft. Restoring '
          'keeps every saved answer readable: questions added since stay on the form, archived; options added since stay, archived; a question '
          'whose key changed takes the old key back and remembers the newer one in keyHistory. Nothing goes live until you publish again. '
          'UiFbMemoryRevisionStore is for demos and small apps; an app with a backend implements UiFbRevisionStore itself (each method may '
          'return a Future).',
      code: '''// On publish: store the snapshot, with a one-line summary of what changed.
revisions.saveRevision(fbCreateRevision(form, previous: live, meta: UiFbRevisionMeta(publishedBy: user.name)));

// Your own store: any method may return a value or a Future.
class ApiRevisions implements UiFbRevisionStore {
  @override Future<List<UiFbRevision>> listRevisions(String formId) => api.revisions(formId);
  @override Future<UiFbRevision?> getRevision(String formId, int n) => api.revision(formId, n);
  @override Future<void> saveRevision(UiFbRevision entry) => api.saveRevision(entry.toJson());
  @override Future<UiFormDefinition> rollback(String formId, int n, [UiFormDefinition? current]) async {
    final target = await getRevision(formId, n);
    return rollbackDefinition(target!.definition, current ?? form);
  }
}

// Keep the in-memory history across restarts: load / save a JSON string.
UiFbMemoryRevisionStore(load: () => prefs.getString('revisions'), save: (json) => prefs.setString('revisions', json));

// The history on its own, in your own screen:
UiFbRevisionPanel(store: revisions, formId: form.id, current: form, onRestore: (draft) => setState(() => form = draft))''',
      api: [
        ApiRow('UiFbRevisionStore', 'interface', 'listRevisions(formId), getRevision(formId, n), saveRevision(entry), rollback(formId, n, [current]). Each may return a Future. Pass one to the builder as revisionStore.'),
        ApiRow('fbCreateRevision(definition, {previous, meta}) / UiFbMemoryRevisionStore', 'UiFbRevision / class', 'The snapshot to store when you publish (with a summary of what changed), and an in-memory store for demos and small apps. Its all and revisions(formId) are ValueListenables; load / save keep it across restarts.'),
        ApiRow('rollbackDefinition(target, current)', 'UiFormDefinition', 'The draft that brings target back while keeping every saved answer readable. Pure: neither input changes.'),
        ApiRow('UiFbRevisionPanel', 'widget', 'The list on its own: store, formId, current (the draft, for “Compare with draft”) and onRestore. Newest first, with what changed, a comparison with the draft and Restore (after a confirmation).'),
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
        ApiRow('replace(definition)', '', 'Load a whole definition as ONE undoable edit (restoring a revision), keeping the host’s revision.'),
        ApiRow('locales / defaultLocale / multilingual', 'List<UiFbResolvedLocale> / String / bool', 'The form’s languages (default first), the default one, and whether there is more than one.'),
        ApiRow('editLocale / editDir / defaultDir / translating, setEditLocale(code)', 'String / UiFbDir / bool', 'The language being written (falls back to the default when removed), its direction, and whether it is not the default.'),
        ApiRow('text(t) / defaultText(t) / shown(t) / setText(current, value)', 'String / UiFbText', 'Text helpers for editors: the edit language with no fallback, the default language’s text while translating, the canvas text with fallback, and a write into the edit language.'),
        ApiRow('addLocale(code) / removeLocale(code) / setDefaultLocale(code) / setLocaleDir(code, dir)', '', 'Each one undoable step. Removing a language strips its text from every question in the same step.'),
      ],
    );
  }
}
