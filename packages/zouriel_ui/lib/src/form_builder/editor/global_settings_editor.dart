import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../button/button.dart';
import '../../button/segmented.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../forms/text/inputs.dart';
import '../../forms/text/number_input.dart';
import '../../forms/text/select.dart';
import '../../theme/theme.dart';
import '../engine/definition.dart';
import '../engine/global_settings.dart';
import '../engine/http_sources.dart';
import '../engine/js.dart';
import '../engine/option_sources.dart';
import '../engine/schema.dart';
import 'builder_bits.dart';
import 'settings_fields.dart';

enum _Section { sources, defaults }

class _TestRun {
  const _TestRun({required this.url, required this.ok, required this.message, this.items = const [], this.fields = const [], this.raw = ''});
  final String url;
  final bool ok;
  final String message;
  final List<UiFbSourceItem> items;

  /// Field names found in the first item, to help fill in the reply mapping.
  final List<String> fields;
  final String raw;
}

/// `ui-form-global-settings`: the app's form settings page: the lists every form can search
/// (where to ask, how it pages, how to read the reply, with a test), and what new forms start
/// with. Store the JSON [onChanged] gives you and pass it to [UiFormBuilder] and
/// [UiFormRenderer] as `globalSettings`.
///
/// Requests go through [httpSources] (the app's fetch, which adds the login, and the servers it
/// allows). No secrets are stored in the settings.
class UiFormGlobalSettingsEditor extends StatefulWidget {
  const UiFormGlobalSettingsEditor({
    super.key,
    required this.settings,
    required this.onChanged,
    this.usage = const {},
    this.builtIn = const [],
    this.httpSources = const UiFbHttpSourcesOptions(),
  });

  final UiFormGlobalSettings settings;
  final ValueChanged<UiFormGlobalSettings> onChanged;

  /// How many forms use each list, by key (`{'students': 3}`). Used to warn before deleting or
  /// re-keying one.
  final Map<String, int> usage;

  /// Lists the app registers in code; shown read-only, and their keys can't be reused.
  final List<UiFbOptionSourceDef> builtIn;
  final UiFbHttpSourcesOptions httpSources;

  @override
  State<UiFormGlobalSettingsEditor> createState() => _UiFormGlobalSettingsEditorState();
}

class _UiFormGlobalSettingsEditorState extends State<UiFormGlobalSettingsEditor> {
  _Section _section = _Section.sources;
  int? _open;
  bool _confirmDelete = false;
  bool _testing = false;
  _TestRun? _lastTest;
  final Map<String, String> _testParams = {};
  String _testQuery = '';

  /// Lists whose key the admin typed (so the name stops rewriting it).
  final Set<int> _keyTouched = {};

  List<UiFbHttpSourceConfig> get _sources => widget.settings.sources ?? const [];
  UiFbHttpSourceConfig? get _current => _open == null || _open! >= _sources.length ? null : _sources[_open!];

  UiFormGlobalSettings _copy() => UiFormGlobalSettings.fromJson(widget.settings.toJson())..version = 1;

  void _write(List<UiFbHttpSourceConfig> sources) => widget.onChanged(_copy()..sources = sources);

  List<UiFbHttpSourceConfig> _sourcesCopy() => [for (final s in _sources) UiFbHttpSourceConfig.fromJson(s.toJson())];

  String _used(String type) {
    final n = widget.usage[type] ?? 0;
    return n > 0 ? '$n form${n == 1 ? '' : 's'}' : '';
  }

  String _host(String url) => originOf(url, baseUrl: widget.httpSources.baseUrl).replaceFirst(RegExp(r'^https?://'), '');

  bool _allowed(String url) => originAllowed(url, widget.httpSources.allowedOrigins, baseUrl: widget.httpSources.baseUrl, ownOrigin: widget.httpSources.ownOrigin);

  String _problemOf(UiFbHttpSourceConfig c) {
    if (c.type.isEmpty || c.url.isEmpty || c.valueField.isEmpty || c.labelField.isEmpty) return 'Missing a key, address, saved value or what people see.';
    if (!_allowed(c.url)) return 'This app doesn’t allow its address.';
    return '';
  }

  String _keyProblem(UiFbHttpSourceConfig c) {
    if (c.type.isEmpty) return 'Give it a key, e.g. students.';
    if (!RegExp(r'^[a-z][a-z0-9_-]*$', caseSensitive: false).hasMatch(c.type)) return 'Use letters, numbers, - and _ only, starting with a letter.';
    final others = [
      for (var i = 0; i < _sources.length; i++)
        if (i != _open) _sources[i].type,
      for (final d in widget.builtIn) d.type,
    ];
    return others.contains(c.type) ? 'Another list already uses this key.' : '';
  }

  String _urlProblem(UiFbHttpSourceConfig c) {
    if (c.url.isEmpty) return 'Add the address of the list.';
    if (originOf(c.url, baseUrl: widget.httpSources.baseUrl).isEmpty || !RegExp(r'^https?://', caseSensitive: false).hasMatch(c.url)) {
      return 'That isn’t a web address (it should start with https://).';
    }
    if (!_allowed(c.url)) {
      final allowed = widget.httpSources.allowedOrigins ?? const [];
      final ok = allowed.isNotEmpty ? ' Allowed: ${allowed.join(', ')}.' : '';
      return 'This app doesn’t allow lists from ${originOf(c.url)}.$ok A developer can add it.';
    }
    return '';
  }

  String _example(UiFbHttpSourceConfig c) {
    if (c.url.isEmpty || _urlProblem(c).isNotEmpty && originOf(c.url).isEmpty) return '…';
    final params = {for (final p in c.params ?? const <UiFbSourceParamSpec>[]) p.key: '{${p.key}}'};
    final url = sourceUrl(c, query: 'text', page: 1, pageSize: c.pageSize ?? 20, params: params, baseUrl: widget.httpSources.baseUrl);
    try {
      return Uri.decodeFull(url);
    } on ArgumentError {
      return url;
    }
  }

  // ── Editing ───────────────────────────────────────────────────────────────────────────────

  void _add() {
    final n = _sources.length + 1;
    _write([..._sourcesCopy(), UiFbHttpSourceConfig(type: 'list-$n', label: '', url: '', valueField: 'id', labelField: 'name')]);
    setState(() {
      _open = n - 1;
      _lastTest = null;
      _confirmDelete = false;
    });
  }

  /// Merges [p] into the open list; null values remove a setting.
  void _patch(Map<String, Object?> p) {
    final i = _open;
    if (i == null) return;
    if (p.containsKey('type')) _keyTouched.add(i);
    final list = _sourcesCopy();
    final j = list[i].toJson();
    for (final e in p.entries) {
      if (e.value == null) {
        j.remove(e.key);
      } else {
        j[e.key] = e.value;
      }
    }
    list[i] = UiFbHttpSourceConfig.fromJson(j);
    _write(list);
  }

  /// The key follows the name until the admin edits it, or forms use it.
  void _setLabel(String label) {
    final i = _open;
    final c = _current;
    if (i == null || c == null) return;
    final follow = !_keyTouched.contains(i) && (widget.usage[c.type] ?? 0) == 0;
    final slug = fbSlug(label);
    final list = _sourcesCopy();
    list[i]
      ..label = label
      ..type = follow && label.trim().isNotEmpty ? slug : list[i].type;
    _write(list);
  }

  void _remove({bool confirmed = false}) {
    final i = _open;
    final c = _current;
    if (i == null || c == null) return;
    if (!confirmed && (widget.usage[c.type] ?? 0) > 0) {
      setState(() => _confirmDelete = true);
      return;
    }
    _write(_sourcesCopy()..removeAt(i));
    setState(() {
      _open = null;
      _confirmDelete = false;
      _lastTest = null;
    });
  }

  List<Map<String, Object?>> _paramsJson() => [for (final p in _current?.params ?? const <UiFbSourceParamSpec>[]) p.toJson()];

  void _patchParam(int i, Map<String, Object?> p) {
    final list = _paramsJson();
    for (final e in p.entries) {
      if (e.value == null) {
        list[i].remove(e.key);
      } else {
        list[i][e.key] = e.value;
      }
    }
    _patch({'params': list});
  }

  String _choicesText(UiFbSourceParamSpec p) =>
      [for (final o in p.options ?? const <({String value, String label})>[]) o.label.isNotEmpty && o.label != o.value ? '${o.value}: ${o.label}' : o.value].join('\n');

  void _setChoices(int i, String text) {
    final options = [
      for (final l in text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty))
        () {
          final at = l.indexOf(':');
          return at > 0 ? {'value': l.substring(0, at).trim(), 'label': l.substring(at + 1).trim()} : {'value': l, 'label': l};
        }(),
    ];
    _patchParam(i, {'options': options});
  }

  void _patchDefaults(void Function(UiFbSettings s) edit, {String? mergeKey}) {
    final next = _copy();
    edit(next.defaults ??= UiFbSettings());
    widget.onChanged(next);
  }

  // ── Testing ───────────────────────────────────────────────────────────────────────────────

  /// Asks the list for its first page the same way forms will, and shows what came back.
  Future<void> _runTest() async {
    final c = _current;
    if (c == null) return;
    final problem = _urlProblem(c);
    if (problem.isNotEmpty) {
      setState(() => _lastTest = _TestRun(url: c.url, ok: false, message: problem));
      return;
    }
    final pageSize = c.pageSize ?? 20;
    final params = <String, Object?>{
      for (final e in _testParams.entries)
        if (e.value.isNotEmpty) e.key: e.value,
    };
    final url = sourceUrl(c, query: _testQuery.trim(), page: 1, pageSize: pageSize, params: params, baseUrl: widget.httpSources.baseUrl);
    setState(() => _testing = true);
    Object? reply;
    try {
      reply = await sourceFetch(widget.httpSources)(url, UiFbAbortSignal());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastTest = _TestRun(url: url, ok: false, message: 'The request failed: $e');
        _testing = false;
      });
      return;
    }
    if (!mounted) return;
    var raw = '';
    try {
      raw = const JsonEncoder.withIndent('  ').convert(reply);
      if (raw.length > 4000) raw = '${raw.substring(0, 4000)}\n…';
    } catch (_) {
      raw = jsString(reply);
    }
    final list = readPath(reply, c.itemsPath);
    final first = list is List && list.isNotEmpty ? list.first : null;
    final fields = first is Map ? [for (final k in first.keys.take(16)) '$k'] : const <String>[];
    _TestRun run;
    try {
      final page = readSourceReply(c, reply, pageSize);
      final n = page.total ?? page.items.length;
      final more = page.hasMore == true ? ' (more pages follow)' : '';
      run = _TestRun(
        url: url,
        ok: true,
        raw: raw,
        fields: fields,
        message: page.items.isNotEmpty ? 'Works: found ${jsNumberToString(n)}${page.total == null && page.hasMore != false ? '+' : ''}$more.' : 'Works, but nothing matched.',
        items: page.items.take(8).toList(),
      );
    } catch (e) {
      run = _TestRun(url: url, ok: false, raw: raw, fields: fields, message: e.toString());
    }
    setState(() {
      _lastTest = run;
      _testing = false;
    });
  }

  // ── Layout ────────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final intro = context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: t.textSecondary);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
      Align(
        alignment: Alignment.centerLeft,
        child: UiSegmented<_Section>(
          label: 'Settings section',
          size: UiSize.sm,
          value: _section,
          options: const [UiSegmentedOption(value: _Section.sources, label: 'Data sources'), UiSegmentedOption(value: _Section.defaults, label: 'New form defaults')],
          onChanged: (v) => setState(() => _section = v),
        ),
      ),
      if (_section == _Section.defaults)
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
            Text('New forms start with these. Each form can change its own, and forms that already exist aren’t changed.', style: intro),
            UiFbSettingsFields(settings: widget.settings.defaults ?? UiFbSettings(), onPatch: _patchDefaults),
          ]),
        )
      else
        LayoutBuilder(builder: (context, box) {
          final wide = box.maxWidth >= 760;
          final c = _current;
          final list = _list(context);
          if (c == null) return list;
          final editor = _editor(context, c, showBack: !wide);
          if (!wide) return editor;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, spacing: t.space4, children: [SizedBox(width: 280, child: list), Expanded(child: editor)]);
        }),
    ]);
  }

  Widget _list(BuildContext context) {
    final t = context.ui;
    Widget row(int i, UiFbHttpSourceConfig c) {
      final on = _open == i;
      final used = _used(c.type);
      final problem = _problemOf(c);
      return UiInteractive(
        onTap: () => setState(() {
          _open = i;
          _lastTest = null;
          _confirmDelete = false;
        }),
        selected: on,
        semanticLabel: '${c.label.isNotEmpty ? c.label : 'Untitled list'}, ${c.url.isNotEmpty ? _host(c.url) : 'no address yet'}${used.isNotEmpty ? ', used by $used' : ''}${problem.isNotEmpty ? ', needs fixing' : ''}',
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, s) => Container(
          padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
          decoration: BoxDecoration(
            color: on ? t.selected : (s.hovered || s.pressed ? t.surfaceHover : null),
            // The same bordered card as the built-in lists below: they are the same kind of thing.
            border: Border.all(color: t.borderSubtle),
            borderRadius: BorderRadius.circular(t.radius),
            boxShadow: s.focused ? t.focusRing : null,
          ),
          child: Row(spacing: t.space2, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.label.isNotEmpty ? c.label : 'Untitled list', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 14 * context.ui.fontScale, color: t.text)),
                Text(c.url.isNotEmpty ? _host(c.url) : 'No address yet', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
              ]),
            ),
            if (used.isNotEmpty) FbChip(used),
            if (problem.isNotEmpty) FbChip('Fix', tone: FbTone.bad, tooltip: problem),
          ]),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
      Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: t.space3, runSpacing: t.space2, children: [
        Text('Lists that dropdowns and multi-selects can search, in any form.', style: context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: t.textSecondary)),
        UiButton(label: 'Add a list', size: UiSize.sm, icon: const UiIcon(HugeIcons.strokeRoundedAdd01), onPressed: _add),
      ]),
      if (_sources.isEmpty && widget.builtIn.isEmpty)
        Container(
          padding: EdgeInsets.all(t.space4),
          decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: Text(
            'No lists yet. Add one to let forms search your data, e.g. students or courses.',
            textAlign: TextAlign.center,
            style: context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: t.textMuted),
          ),
        ),
      for (var i = 0; i < _sources.length; i++) row(i, _sources[i]),
      if (widget.builtIn.isNotEmpty) ...[
        Padding(
          padding: EdgeInsets.only(top: t.space1),
          child: Text('Built into the app', style: context.uiText.label.copyWith(fontSize: 12, color: t.textSecondary)),
        ),
        for (final d in widget.builtIn)
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
            decoration: BoxDecoration(border: Border.all(color: t.borderSubtle), borderRadius: BorderRadius.circular(t.radius)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.label, style: context.uiText.label.copyWith(fontSize: 14 * context.ui.fontScale, color: t.text)),
              Text(
                (d.description ?? '').isNotEmpty ? d.description! : 'Provided by the app’s code. It can’t be changed here.',
                style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted),
              ),
            ]),
          ),
      ],
    ]);
  }

  Widget _editor(BuildContext context, UiFbHttpSourceConfig c, {required bool showBack}) {
    final t = context.ui;
    final keyProblem = _keyProblem(c);
    final urlProblem = c.url.isEmpty ? '' : _urlProblem(c);
    final paging = c.paging ?? 'page';
    final used = _used(c.type);
    final mono = context.uiText.code.copyWith(fontSize: 12, color: t.text);

    Widget text(String label, String? value, String placeholder, void Function(String v) set, {bool invalid = false}) => FbSetting(
      label: label,
      child: UiInput(size: UiSize.sm, value: value ?? '', placeholder: placeholder, invalid: invalid, semanticLabel: label, onChanged: set),
    );
    String? orNull(String v) => v.isEmpty ? null : v;

    Widget group(String title, List<Widget> children) => FbSection(title: title, children: children);
    final test = _lastTest;

    return Container(
      padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space4),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Semantics(
        container: true,
        label: 'Editing ${c.label.isNotEmpty ? c.label : 'list'}',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space3, children: [
          Row(spacing: t.space2, children: [
            if (showBack)
              UiButton(label: 'Lists', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(HugeIcons.strokeRoundedArrowLeft01), onPressed: () => setState(() => _open = null)),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(c.label.isNotEmpty ? c.label : 'Untitled list', maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 15 * context.ui.fontScale, color: t.text)),
              ),
            ),
            UiButton(label: 'Delete', size: UiSize.sm, variant: UiButtonVariant.ghost, icon: const UiIcon(HugeIcons.strokeRoundedDelete02), onPressed: _remove),
          ]),
          if (_confirmDelete)
            Semantics(
              liveRegion: true,
              child: FbWarn(
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: t.space2, runSpacing: t.space2, children: [
                  Text('$used use this list. They’ll show “This list isn’t available” until it’s back.'),
                  UiButton(label: 'Delete anyway', size: UiSize.sm, variant: UiButtonVariant.destructive, onPressed: () => _remove(confirmed: true)),
                  UiButton(label: 'Cancel', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: () => setState(() => _confirmDelete = false)),
                ]),
              ),
            ),
          group('About', [
            FbPair(children: [
              text('Name', c.label, 'e.g. Students', _setLabel),
              text('Key', c.type, 'students', (v) => _patch({'type': v}), invalid: keyProblem.isNotEmpty),
            ]),
            FbHint(
              keyProblem.isNotEmpty ? keyProblem : (used.isNotEmpty ? 'Forms refer to this list by its key, so changing it disconnects them.' : 'Forms refer to the list by this key.'),
              bad: keyProblem.isNotEmpty,
            ),
            text('Description', c.description, 'Shown to form builders, e.g. ‘Everyone in the student records’', (v) => _patch({'description': orNull(v)})),
          ]),
          group('Where to ask', [
            text('Address', c.url, 'https://api.example.com/students', (v) => _patch({'url': v.trim()}), invalid: urlProblem.isNotEmpty),
            FbHint(urlProblem.isNotEmpty ? urlProblem : 'Your app adds its login to every request, so no keys go here.', bad: urlProblem.isNotEmpty),
          ]),
          group('Searching and pages', [
            FbPair(children: [
              text('Search setting', c.searchParam ?? 'q', 'q', (v) => _patch({'searchParam': orNull(v)})),
              FbSetting(
                label: 'Results per page',
                child: UiNumberInput(
                  size: UiSize.sm,
                  value: c.pageSize ?? 20,
                  min: 1,
                  max: 200,
                  semanticLabel: 'Results per page',
                  onChanged: (v) => _patch({'pageSize': v == null || v == 0 ? null : v.toInt()}),
                ),
              ),
            ]),
            Align(
              alignment: Alignment.centerLeft,
              child: UiSegmented<String>(
                label: 'How pages are asked for',
                size: UiSize.sm,
                value: paging,
                options: const [UiSegmentedOption(value: 'page', label: 'Page numbers'), UiSegmentedOption(value: 'offset', label: 'Skip a number')],
                onChanged: (v) => _patch({'paging': v, 'pageParam': null}),
              ),
            ),
            FbPair(children: [
              text(paging == 'page' ? 'Page setting' : 'Skip setting', c.pageParam, paging == 'page' ? 'page' : 'offset', (v) => _patch({'pageParam': orNull(v)})),
              if (paging == 'page')
                FbSetting(
                  label: 'First page is',
                  child: UiSelect(
                    label: 'First page is',
                    size: UiSize.sm,
                    value: c.firstPage == 0 ? '0' : '1',
                    options: const [UiSelectOption(value: '1', label: '1'), UiSelectOption(value: '0', label: '0')],
                    onChanged: (v) => _patch({'firstPage': v == '0' ? 0 : null}),
                  ),
                )
              else
                text('Page size setting', c.pageSizeParam ?? 'pageSize', 'limit', (v) => _patch({'pageSizeParam': v})),
            ]),
            if (paging == 'page') text('Page size setting', c.pageSizeParam ?? 'pageSize', 'pageSize', (v) => _patch({'pageSizeParam': v})),
            FbSetting(
              label: 'Search after typing',
              child: Row(spacing: t.space2, children: [
                SizedBox(
                  width: 140,
                  child: UiNumberInput(
                    size: UiSize.sm,
                    value: c.minQueryLength ?? 0,
                    min: 0,
                    max: 10,
                    semanticLabel: 'Characters before searching',
                    onChanged: (v) => _patch({'minQueryLength': v == null || v == 0 ? null : v.toInt()}),
                  ),
                ),
                Text('characters', style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary)),
              ]),
            ),
            Text.rich(
              TextSpan(text: 'A search asks: ', children: [TextSpan(text: _example(c), style: mono)]),
              style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted),
            ),
          ]),
          group('Reading the reply', [
            if (test != null && test.fields.isNotEmpty)
              Text.rich(
                TextSpan(text: 'Fields in each item: ', children: [TextSpan(text: test.fields.join('  '), style: mono)]),
                style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted),
              ),
            FbPair(children: [
              text('Where the list is', c.itemsPath, 'Empty when the reply is the list', (v) => _patch({'itemsPath': orNull(v)})),
              text('Saved value', c.valueField, 'id', (v) => _patch({'valueField': v})),
              text('What people see', c.labelField, 'name, or {firstName} {lastName}', (v) => _patch({'labelField': v})),
              text('Second line (optional)', c.descriptionField, 'email', (v) => _patch({'descriptionField': orNull(v)})),
              text('Total count at (optional)', c.totalPath, 'total', (v) => _patch({'totalPath': orNull(v)})),
              text('“More pages” flag at (optional)', c.hasMorePath, 'hasMore', (v) => _patch({'hasMorePath': orNull(v)})),
            ]),
            const FbHint('Use dots for nested fields (data.items). Without a total or flag, a full page means there may be more.'),
          ]),
          group('Settings for each question', [
            const FbHint('Filters form builders set per question, sent as query settings, e.g. a faculty. Each can follow another answer.'),
            for (var i = 0; i < (c.params ?? const []).length; i++)
              FbBox(children: [
                FbPair(children: [
                  text('Setting', c.params![i].key, 'faculty', (v) => _patchParam(i, {'key': v})),
                  text('Shown as', c.params![i].label, 'Faculty', (v) => _patchParam(i, {'label': v})),
                ]),
                Wrap(spacing: t.space2, runSpacing: t.space2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  SizedBox(
                    width: 140,
                    child: UiSelect(
                      label: 'Kind of value',
                      size: UiSize.sm,
                      value: c.params![i].kind ?? 'text',
                      options: const [UiSelectOption(value: 'text', label: 'Text'), UiSelectOption(value: 'number', label: 'Number'), UiSelectOption(value: 'select', label: 'Choice')],
                      onChanged: (v) => _patchParam(i, {'kind': v}),
                    ),
                  ),
                  FbSwitch(size: UiSize.sm, value: c.params![i].required, label: 'Needed before searching', onChanged: (v) => _patchParam(i, {'required': v ? true : null})),
                  FbIconButton(
                    icon: HugeIcons.strokeRoundedDelete02,
                    label: 'Remove setting ${c.params![i].label.isNotEmpty ? c.params![i].label : c.params![i].key}',
                    danger: true,
                    onPressed: () => _patch({'params': _paramsJson()..removeAt(i)}),
                  ),
                ]),
                if (c.params![i].kind == 'select')
                  FbSetting(
                    label: 'Choices, one per line as value: label',
                    child: UiTextarea(size: UiSize.sm, 
                      rows: 3,
                      autosize: true,
                      maxRows: 8,
                      value: _choicesText(c.params![i]),
                      placeholder: 'health: Health and medicine',
                      semanticLabel: 'Choices, one per line as value: label',
                      onChanged: (v) => _setChoices(i, v),
                    ),
                  ),
              ]),
            Align(
              alignment: Alignment.centerLeft,
              child: FbLink(label: 'Add a setting', icon: HugeIcons.strokeRoundedAdd01, onTap: () => _patch({'params': [..._paramsJson(), {'key': '', 'label': ''}]})),
            ),
          ]),
          group('Test', [
            for (final p in c.params ?? const <UiFbSourceParamSpec>[])
              text(p.label.isNotEmpty ? p.label : p.key, _testParams[p.key], 'A value to test with', (v) => setState(() => _testParams[p.key] = v)),
            Row(spacing: t.space2, children: [
              Expanded(
                child: UiInput(
                  size: UiSize.sm,
                  value: _testQuery,
                  placeholder: 'Search for (optional)',
                  semanticLabel: 'Search for',
                  onChanged: (v) => _testQuery = v,
                  onSubmitted: (_) => _runTest(),
                ),
              ),
              UiButton(label: 'Run test', size: UiSize.sm, loading: _testing, onPressed: _runTest),
            ]),
            if (test != null) _TestResult(run: test, showDescription: (c.descriptionField ?? '').isNotEmpty),
          ]),
        ]),
      ),
    );
  }
}

class _TestResult extends StatefulWidget {
  const _TestResult({required this.run, required this.showDescription});
  final _TestRun run;
  final bool showDescription;

  @override
  State<_TestResult> createState() => _TestResultState();
}

class _TestResultState extends State<_TestResult> {
  bool _raw = false;

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final showDescription = widget.showDescription;
    final t = context.ui;
    final c = run.ok ? t.success : t.danger;
    final cell = context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: t.text);
    final head = context.uiText.label.copyWith(fontSize: 12, color: t.textSecondary);
    final mono = context.uiText.code.copyWith(fontSize: 12, color: t.textSecondary);
    Widget cells(List<Widget> children, {bool header = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: header ? t.border : t.borderSubtle))),
      child: Row(spacing: t.space2, children: [for (final ch in children) Expanded(child: ch)]),
    );
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withValues(alpha: 0.08), t.surface),
          border: Border.all(color: c.withValues(alpha: 0.32)),
          borderRadius: BorderRadius.circular(t.radius),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: t.space2, children: [
          Text(run.message, style: context.uiText.label.copyWith(fontSize: 13 * context.ui.fontScale, color: t.text)),
          Text(run.url, style: mono),
          if (run.items.isNotEmpty)
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              cells(header: true, [Text('Shown as', style: head), Text('Saved value', style: head), if (showDescription) Text('Second line', style: head)]),
              for (final it in run.items)
                cells([Text(it.label, style: cell), Text(jsString(it.value), style: mono), if (showDescription) Text(it.description ?? '', style: cell)]),
            ]),
          if (run.raw.isNotEmpty) ...[
            Align(alignment: Alignment.centerLeft, child: FbLink(label: _raw ? 'Hide the reply' : 'Show the reply', fontSize: 12, onTap: () => setState(() => _raw = !_raw))),
            if (_raw)
              Container(
                constraints: const BoxConstraints(maxHeight: 240),
                padding: EdgeInsets.all(t.space2),
                decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(t.radiusXs)),
                child: SingleChildScrollView(child: Text(run.raw, style: mono)),
              ),
          ],
        ]),
      ),
    );
  }
}
