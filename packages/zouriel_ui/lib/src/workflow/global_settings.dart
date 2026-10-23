import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../accordion/accordion.dart';
import '../behaviors/scrolling.dart';
import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../datepicker/date_picker.dart';
import '../forms/text/inputs.dart';
import '../forms/text/number_input.dart';
import '../forms/text/time_picker.dart';
import '../forms/choice/switch.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'definition.dart' show wfKey;
import 'editors.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';

const List<WfOption> _days = [
  (value: 'mon', label: 'Mon'), (value: 'tue', label: 'Tue'), (value: 'wed', label: 'Wed'), (value: 'thu', label: 'Thu'),
  (value: 'fri', label: 'Fri'), (value: 'sat', label: 'Sat'), (value: 'sun', label: 'Sun'),
];

/// Audit categories whose entries can be removed after a while, with names for people.
const List<WfOption> _auditCategories = [
  (value: 'step', label: 'Steps'), (value: 'instance', label: 'Runs'), (value: 'task', label: 'Tasks and approvals'),
  (value: 'lifecycle', label: 'Record moves'), (value: 'trigger', label: 'Triggers'), (value: 'definition', label: 'Workflow changes'),
  (value: 'settings', label: 'Settings changes'),
];

/// The settings with a record type paused or resumed.
UiWorkflowSettings _withPaused(UiWorkflowSettings st, String entity, bool on) {
  final list = [for (final e in st.paused) if (e != entity) {'entity': e}];
  return st.patch({'paused': on ? [...list, {'entity': entity}] : (list.isNotEmpty ? list : null)});
}

/// Places one of the engine's `invalidSettings` problems (its `details` is a list of plain messages,
/// spec §12, wording from the .NET engine) next to the field it is about (the web
/// `wfSettingsProblemField`): `timeZone`, `days`, `hours`, `holidays`, `retry`, `reminders`,
/// `concurrency`, `maxChainDepth`, `forEachMax`, `origins`, `retention`, `masked`, `paused`, one
/// connection (`conn:<index>`), the connections as a whole, or `general` (the footer). A message that
/// names a value is matched by that value.
String wfSettingsProblemField(String message, UiWorkflowSettings st) {
  final quoted = RegExp(r"'([^']*)'").firstMatch(message)?.group(1);
  final conns = st.connections;
  if (RegExp(r"^Connection key '|^Two connections are called '|^Connection '").hasMatch(message)) {
    final i = conns.indexWhere((c) => c.key == quoted);
    return i >= 0 ? 'conn:$i' : 'connections';
  }
  bool has(String pattern) => RegExp(pattern, caseSensitive: false).hasMatch(message);
  if (has('time zone')) return 'timeZone';
  if (has('is not a day|working day')) return 'days';
  if (has('working hours')) return 'hours';
  if (has('is not a date')) return 'holidays';
  if (has('retries')) return 'retry';
  if (has('is not a duration')) {
    final reminders = wfStringsOrNull(st.defaults?['reminders']) ?? const <String>[];
    return quoted != null && reminders.contains(quoted) ? 'reminders' : 'retry';
  }
  if (has('concurrency')) return 'concurrency';
  if (message.contains('maxChainDepth')) return 'maxChainDepth';
  if (message.contains('forEachMax')) return 'forEachMax';
  if (has('is not an origin')) return 'origins';
  if (has('must be kept at least')) return 'retention';
  if (has('masked field')) return 'masked';
  if (has('paused entry')) return 'paused';
  return 'general';
}

/// The part of the settings a problem field is about (as JSON), to tell when it has changed since
/// the save was refused.
String _problemValue(String field, UiWorkflowSettings st) {
  final j = st.json;
  final cal = wfMapOrNull(j['calendar']);
  final d = wfMapOrNull(j['defaults']);
  final hooks = wfMapOrNull(j['webhooks']);
  final audit = wfMapOrNull(j['audit']);
  final Object? v;
  if (field.startsWith('conn:')) {
    final list = hooks?['connections'];
    final i = int.tryParse(field.substring(5)) ?? -1;
    v = list is List && i >= 0 && i < list.length ? list[i] : null;
  } else {
    v = switch (field) {
      'timeZone' => j['timeZone'],
      'days' => cal?['days'],
      'hours' => cal?['hours'],
      'holidays' => cal?['holidays'],
      'retry' => d?['retry'],
      'reminders' => d?['reminders'],
      'concurrency' => d?['concurrency'],
      'maxChainDepth' => d?['maxChainDepth'],
      'forEachMax' => d?['forEachMax'],
      'origins' => hooks?['allowedOrigins'],
      'connections' => hooks?['connections'],
      'retention' => audit?['retentionDays'],
      'masked' => audit?['maskedFields'],
      'paused' => j['paused'],
      _ => null,
    };
  }
  return jsonEncode(v);
}

/// The section of the page a problem field is on.
String? _problemSection(String field) {
  if (const ['timeZone', 'days', 'hours', 'holidays'].contains(field)) return 'time';
  if (const ['retry', 'reminders', 'concurrency', 'maxChainDepth', 'forEachMax'].contains(field)) return 'defaults';
  if (field == 'origins' || field == 'connections' || field.startsWith('conn:')) return 'webhooks';
  if (field == 'retention' || field == 'masked') return 'audit';
  if (field == 'paused') return 'watching';
  return null;
}

/// The settings without fields the engine no longer has (`defaults.taskDue`,
/// `people.escalationDefault`, `channels.*.sender`, removed from the spec), so settings kept from
/// before are not sent back with them (the web `wfWithoutRemovedSettings`).
UiWorkflowSettings wfWithoutRemovedSettings(UiWorkflowSettings st) {
  final out = wfMap(jsonDecode(jsonEncode(st.json)));
  final d = out['defaults'];
  if (d is Map) d.remove('taskDue');
  final people = out['people'];
  if (people is Map) people.remove('escalationDefault');
  final channels = out['channels'];
  if (channels is Map) {
    for (final c in channels.values) {
      if (c is Map) c.remove('sender');
    }
  }
  return UiWorkflowSettings.fromJson(out);
}

const List<WfOption> _sections = [
  (value: 'time', label: 'Time & calendar'), (value: 'defaults', label: 'Defaults'), (value: 'channels', label: 'Channels'),
  (value: 'webhooks', label: 'Webhooks'), (value: 'audit', label: 'Audit log'), (value: 'watching', label: 'Watching'), (value: 'registry', label: 'What’s available'),
];

/// Time zones offered. Dart has no `Intl.supportedValuesOf('timeZone')` (the web list), so this is
/// a fixed list of common IANA zones; a zone saved from elsewhere is offered as well.
const List<String> uiWfTimeZones = [
  'UTC', 'Africa/Cairo', 'Africa/Johannesburg', 'Africa/Lagos', 'Africa/Nairobi', 'America/Bogota', 'America/Chicago', 'America/Denver',
  'America/Los_Angeles', 'America/Mexico_City', 'America/New_York', 'America/Sao_Paulo', 'America/Toronto', 'Asia/Bangkok', 'Asia/Colombo',
  'Asia/Dhaka', 'Asia/Dubai', 'Asia/Hong_Kong', 'Asia/Jakarta', 'Asia/Karachi', 'Asia/Kolkata', 'Asia/Kuala_Lumpur', 'Asia/Manila', 'Asia/Riyadh',
  'Asia/Seoul', 'Asia/Shanghai', 'Asia/Singapore', 'Asia/Tokyo', 'Australia/Melbourne', 'Australia/Sydney', 'Europe/Amsterdam', 'Europe/Berlin',
  'Europe/Istanbul', 'Europe/London', 'Europe/Madrid', 'Europe/Moscow', 'Europe/Paris', 'Europe/Rome', 'Indian/Maldives', 'Pacific/Auckland',
];

/// `ui-workflow-global-settings`: the app's workflow settings page: working hours and holidays,
/// defaults for new steps, notification channels, which addresses webhooks may call, audit
/// retention and masking, pausing triggers per record type, what is being watched, and what the
/// app allows workflows to use. Saves through the [api] (with a revision check), or, without one,
/// edits [settings] and hands the result to [onSettingsChanged].
///
/// Give it a bounded height to scroll the section inside it; in an unbounded column it grows.
class UiWorkflowGlobalSettings extends StatefulWidget {
  const UiWorkflowGlobalSettings({super.key, this.api, this.registry, this.settings, this.onSettingsChanged});
  final UiWorkflowApi? api;

  /// The app's registry (for channels, fields to mask, the read-only browser), when there is no API.
  final UiWorkflowRegistry? registry;

  /// Settings to edit when there is no API.
  final UiWorkflowSettings? settings;

  /// After a save (through the API, or locally without one).
  final ValueChanged<UiWorkflowSettings>? onSettingsChanged;

  @override
  State<UiWorkflowGlobalSettings> createState() => UiWorkflowGlobalSettingsState();
}

class UiWorkflowGlobalSettingsState extends State<UiWorkflowGlobalSettings> {
  String _section = 'time';
  UiWorkflowSettings _s = UiWorkflowSettings();
  String _saved = jsonEncode({'version': 1});
  int _revision = 0;
  UiWorkflowRegistry? _registry;
  List<UiWfTriggerOverview> _triggers = const [];
  bool _busy = false;
  String _error = '';
  String _status = '';
  String _newOrigin = '';
  String _originError = '';

  /// The engine's reasons for refusing the last save (`invalidSettings`), each placed at its field
  /// with the value it was about: a problem stops showing once that value is changed.
  List<({String field, String message, String value})> _problems = const [];

  /// The problems still showing (their field unchanged since the refused save).
  List<({String field, String message, String value})> get _openProblems => [
        for (final p in _problems)
          if (p.field == 'general' || _problemValue(p.field, _s) == p.value) p,
      ];

  /// Sections with a problem showing, marked in the section list so they can be found.
  Set<String> get _badSections => {for (final p in _openProblems) ?_problemSection(p.field)};

  /// The engine's messages about one field, shown next to it.
  List<Widget> _problemsFor(String field) => [
        for (final p in _openProblems)
          if (p.field == field) Text(p.message, style: context.uiText.body.copyWith(fontSize: 12.5, color: context.ui.danger)),
      ];

  /// Shows a refused save: an `invalidSettings` refusal lists each problem (`details`, a list of
  /// messages), placed next to its field; the footer says how many and repeats those that belong to
  /// no field.
  void _showSaveError(Object e, UiWorkflowSettings sent) {
    final d = e is UiWfApiError && e.code == 'invalidSettings' ? e.details : null;
    final details = d is List ? [for (final x in d) if (x is String && x.trim().isNotEmpty) x] : const <String>[];
    if (details.isEmpty) {
      _problems = const [];
      _error = e is UiWfApiError ? e.message : 'Saving failed.';
      return;
    }
    _problems = [
      for (final m in details)
        () {
          final field = wfSettingsProblemField(m, sent);
          return (field: field, message: m, value: _problemValue(field, sent));
        }(),
    ];
    final general = [for (final p in _problems) if (p.field == 'general') p.message];
    final n = _problems.length - general.length;
    final head = n == 0 ? '' : '${n == 1 ? 'One setting needs' : '$n settings need'} fixing before saving (marked in the sections).';
    _error = [head, ...general].where((x) => x.isNotEmpty).join(' ');
  }
  int _resetKey = 0;

  /// The settings as edited (not necessarily saved).
  UiWorkflowSettings get value => _s;
  bool get dirty => jsonEncode(_s.json) != _saved;

  @override
  void initState() {
    super.initState();
    _registry = widget.registry;
    _adoptInput();
    _load();
  }

  @override
  void didUpdateWidget(UiWorkflowGlobalSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.registry != null && widget.registry != oldWidget.registry) _registry = widget.registry;
    if (widget.settings != oldWidget.settings) _adoptInput();
    if (widget.api != oldWidget.api) _load();
  }

  void _adoptInput() {
    final s = widget.settings;
    if (s != null && widget.api == null) {
      _s = wfWithoutRemovedSettings(s);
      _saved = jsonEncode(_s.json);
    }
  }

  /// Bumped per load, so a slower answer from an earlier api never replaces a newer one.
  int _loadSeq = 0;

  Future<void> _load() async {
    final api = widget.api;
    if (api == null) return;
    final n = ++_loadSeq;
    try {
      final st = await api.settings();
      final schema = widget.registry != null ? null : await api.schema();
      List<UiWfTriggerOverview> triggers;
      try {
        triggers = await api.triggers();
      } catch (_) {
        triggers = const [];
      }
      if (!mounted || n != _loadSeq) return;
      final clean = wfWithoutRemovedSettings(st.settings);
      setState(() {
        _s = clean;
        _saved = jsonEncode(clean.json);
        _revision = st.revision;
        if (schema != null) _registry = schema.registry;
        _triggers = triggers;
      });
    } catch (e) {
      if (mounted && n == _loadSeq) setState(() => _error = e is UiWfApiError ? e.message : 'Could not load the settings.');
    }
  }

  void _patch(UiJson p) => setState(() {
    _s = _s.patch(p);
    _status = '';
  });

  void _patchDefaults(UiJson p) => _patch({'defaults': wfPatch(_s.defaults ?? const {}, p)});
  UiJson get _calendar => _s.calendar ?? const {};
  UiJson get _webhooks => wfMapOrNull(_s.json['webhooks']) ?? const {};
  UiJson get _audit => _s.audit ?? const {};

  void _toggleDay(String d, bool on) {
    final days = [for (final x in _days) if (x.value == d ? on : _s.workDays.contains(x.value)) x.value];
    _patch({'calendar': {..._calendar, 'days': days}});
  }

  void _setHours(int i, String v) {
    // Only whole times are kept.
    if (!RegExp(r'^\d{2}:\d{2}$').hasMatch(v) || v == _s.hours[i]) return;
    final h = [..._s.hours];
    h[i] = v;
    _patch({'calendar': {..._calendar, 'hours': h}});
  }

  void _addHoliday(String? d) {
    if (d == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)) return;
    final list = {..._s.holidays, d}.toList()..sort();
    _patch({'calendar': {..._calendar, 'holidays': list}});
    setState(() => _resetKey++);
  }

  void _removeHoliday(String d) => _patch({'calendar': {..._calendar, 'holidays': _s.holidays.where((x) => x != d).toList()}});

  void _patchChannel(String key, UiJson p) {
    final cur = wfPatch(_s.channels?[key] ?? const {}, p);
    _patch({'channels': {...?_s.channels, key: cur}});
  }

  void _addOrigin() {
    final v = _newOrigin.trim().replaceFirst(RegExp(r'/+$'), '');
    if (!RegExp(r'^https?://[^/\s]+$').hasMatch(v)) {
      setState(() => _originError = 'Enter an address like https://hooks.example.com (no path).');
      return;
    }
    setState(() {
      _originError = '';
      _newOrigin = '';
      _resetKey++;
    });
    _patch({'webhooks': {..._webhooks, 'allowedOrigins': {..._s.allowedOrigins, v}.toList()}});
  }

  void _removeOrigin(String o) => _patch({'webhooks': {..._webhooks, 'allowedOrigins': _s.allowedOrigins.where((x) => x != o).toList()}});

  /// Keys of the connections in the last saved settings: webhook steps may refer to them.
  Set<String> get _savedKeys => {for (final c in UiWorkflowSettings.fromJson(jsonDecode(_saved)).connections) c.key};

  /// Whether a connection is saved already (its key is then fixed, as steps may use it).
  bool _isSaved(String key) => _savedKeys.contains(key);

  void _addConnection() {
    final list = _s.connections;
    final labels = {for (final c in list) c.label};
    var n = list.length + 1;
    while (labels.contains('Connection $n')) {
      n++;
    }
    final label = 'Connection $n';
    // Unique among the keys on the page and the saved ones (a removed connection's key may still be in use).
    final key = wfKey(label, [for (final c in list) c.key, ..._savedKeys]);
    _patch({
      'webhooks': {
        ..._webhooks,
        'connections': [...list, {'key': key, 'label': label, 'baseUrl': 'https://', 'auth': 'none'}],
      },
    });
  }

  void _patchConnection(int i, UiJson p) {
    final list = [
      for (var j = 0; j < _s.connections.length; j++)
        if (j != i)
          _s.connections[j]
        else
          () {
            final c = _s.connections[j];
            final n = wfPatch(c.json, p);
            final label = p['label'];
            // A new (unsaved) connection's key follows its name, unique on the page; a saved one keeps
            // its key, so the webhook steps that use it keep working.
            if (label is String && !_isSaved(c.key)) {
              n['key'] = wfKey(label, [for (var k = 0; k < _s.connections.length; k++) if (k != i) _s.connections[k].key, ..._savedKeys]);
            }
            return UiWfConnection.fromJson(n);
          }(),
    ];
    _patch({'webhooks': {..._webhooks, 'connections': list}});
  }

  void _removeConnection(int i) => _patch({'webhooks': {..._webhooks, 'connections': [..._s.connections]..removeAt(i)}});

  void _setRetention(String category, num? days) {
    final r = <String, Object?>{...?wfMapOrNull(_audit['retentionDays'])};
    if (days != null && days > 0) {
      r[category] = days;
    } else {
      r.remove(category);
    }
    _patch({'audit': {..._audit, 'retentionDays': r}});
  }

  void _addMasked(String v) {
    if (v.isEmpty) return;
    setState(() => _resetKey++);
    _patch({'audit': {..._audit, 'maskedFields': [..._s.maskedFields, v]}});
  }

  void _removeMasked(String v) => _patch({'audit': {..._audit, 'maskedFields': _s.maskedFields.where((x) => x != v).toList()}});

  bool _isPaused(String entity) => _s.paused.contains(entity);

  /// Pauses or resumes a record type at once. Only that change is saved: it is applied to the last
  /// saved settings, and any other edits on the page stay unsaved, as they were.
  Future<void> _setPaused(String entity, bool on) async {
    if (_busy || _isPaused(entity) == on) return;
    final toSave = _withPaused(UiWorkflowSettings.fromJson(jsonDecode(_saved)), entity, on);
    setState(() {
      _s = _withPaused(_s, entity, on);
      _error = '';
    });
    final api = widget.api;
    if (api == null) {
      setState(() {
        _saved = jsonEncode(toSave.json);
        _status = on ? 'Paused.' : 'Running again.';
      });
      widget.onSettingsChanged?.call(toSave);
      return;
    }
    setState(() => _busy = true);
    try {
      final rev = await api.saveSettings(toSave, _revision);
      if (!mounted) return;
      setState(() {
        _revision = rev;
        _saved = jsonEncode(toSave.json);
        _status = '${on ? 'Paused.' : 'Running again.'}${dirty ? ' Your other changes are not saved yet.' : ''}';
      });
      widget.onSettingsChanged?.call(toSave);
    } catch (e) {
      // Put the switch back; the rest of the page keeps its edits.
      if (mounted) {
        setState(() {
          _s = _withPaused(_s, entity, !on);
          _showSaveError(e, toSave);
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _discard() => setState(() {
    _s = UiWorkflowSettings.fromJson(jsonDecode(_saved));
    _error = '';
    _problems = const [];
    _resetKey++;
  });

  /// Saves the settings (through the API, or locally without one).
  Future<void> save() async {
    if (_busy) return;
    final api = widget.api;
    setState(() => _error = '');
    if (api == null) {
      setState(() {
        _saved = jsonEncode(_s.json);
        _status = 'Saved.';
      });
      widget.onSettingsChanged?.call(_s);
      return;
    }
    setState(() => _busy = true);
    final sent = _s;
    try {
      final rev = await api.saveSettings(sent, _revision);
      if (!mounted) return;
      setState(() {
        _revision = rev;
        // What was sent is what's saved; anything changed while it was on its way stays unsaved.
        _saved = jsonEncode(sent.json);
        _problems = const [];
        _status = 'Saved.';
      });
      widget.onSettingsChanged?.call(sent);
    } catch (e) {
      if (mounted) setState(() => _showSaveError(e, sent));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Sections ──────────────────────────────────────────────────────────────────────────────

  Widget _h2(String text) => Semantics(header: true, child: Text(text, style: context.uiText.label.copyWith(fontSize: 16 * context.ui.fontScale, fontWeight: FontWeight.w700, color: context.ui.text)));

  Widget _card(List<Widget> children) {
    final t = context.ui;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: children),
    );
  }

  /// `application.applicantEmail` reads "Application › Applicant email".
  String _fieldName(String path) {
    final i = path.indexOf('.');
    if (i < 0) return path;
    final e = _registry?.entities.where((x) => x.key == path.substring(0, i)).firstOrNull;
    final f = e?.fields.where((x) => x.key == path.substring(i + 1)).firstOrNull;
    return e != null && f != null ? '${e.label} › ${f.label}' : path;
  }

  Widget _items(List<String> values, ValueChanged<String> onRemove, {String removeVerb = 'Remove', bool code = false, String Function(String v)? labelOf}) {
    final t = context.ui;
    return Wrap(spacing: 4, runSpacing: 4, children: [
      for (final v in values)
        Container(
          padding: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(t.radiusXs)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 2, children: [
            Text(labelOf?.call(v) ?? v, style: (code ? context.uiText.code : context.uiText.body).copyWith(fontSize: 12.5, color: t.text)),
            UiInteractive(
              onTap: () => onRemove(v),
              semanticLabel: '$removeVerb ${labelOf?.call(v) ?? v}',
              excludeChildSemantics: true,
              pressScale: false,
              builder: (context, s) => Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.hovered ? t.danger.withValues(alpha: 0.12) : null, borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : null),
                child: UiIcon(WfIcons.cancel01, size: 12, strokeWidth: 2, color: s.hovered ? t.danger : t.textMuted),
              ),
            ),
          ]),
        ),
    ]);
  }

  List<Widget> _time() {
    final zone = _s.timeZone ?? 'UTC';
    return [
      _h2('Time and working hours'),
      const FbHint('Deadlines, reminders and time limits marked “working time” only count these hours.'),
      FbSetting(
        label: 'Time zone',
        child: WfSelect(
          label: 'Time zone',
          value: zone,
          // UTC first, and a saved zone the list lacks kept as a choice.
          options: [
            for (final z in {if (!uiWfTimeZones.contains(zone)) zone, ...uiWfTimeZones})
              (value: z, label: z == 'UTC' ? 'UTC (Coordinated Universal Time)' : z.replaceAll('_', ' ')),
          ],
          onChanged: (z) => _patch({'timeZone': z}),
        ),
      ),
      ..._problemsFor('timeZone'),
      FbSetting(label: 'Working days', child: WfChecks(label: 'Working days', options: _days, isChecked: _s.workDays.contains, onChanged: _toggleDay)),
      ..._problemsFor('days'),
      WfPair(children: [
        FbSetting(label: 'From', child: UiTimePicker(size: UiSize.sm, label: 'From', value: _s.hours[0], onChanged: (v) => _setHours(0, v))),
        FbSetting(label: 'To', child: UiTimePicker(size: UiSize.sm, label: 'To', value: _s.hours[1], onChanged: (v) => _setHours(1, v))),
      ]),
      ..._problemsFor('hours'),
      FbSetting(
        label: 'Holidays',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
          if (_s.holidays.isNotEmpty) _items(_s.holidays, _removeHoliday),
          // Picking a date adds it (the web `pickHoliday`); the picker then empties for the next one. Full width,
          // like every field of the form.
          UiDatePicker(key: ValueKey('h$_resetKey'), size: UiSize.sm, label: 'Holiday date', placeholder: 'Add a holiday', value: null, onChanged: _addHoliday),
          ..._problemsFor('holidays'),
        ]),
      ),
    ];
  }

  List<Widget> _defaults() {
    final d = _s.defaults ?? const {};
    final retry = wfMapOrNull(d['retry']) ?? const {};
    return [
      _h2('Defaults'),
      // The engine has no "tasks are due" default: a reminder counts from when the task opens.
      FbSetting(
        label: 'Remind people of an open task after',
        child: WfDurationInput(value: wfStringsOrNull(d['reminders'])?.firstOrNull ?? 'P1D', label: 'Reminder', onChanged: (v) => _patchDefaults({'reminders': [v]})),
      ),
      ..._problemsFor('reminders'),
      WfPair(children: [
        FbSetting(
          label: 'Retry failed calls',
          child: UiNumberInput(
            size: UiSize.sm,
            value: wfNum(retry['max']) ?? 0,
            min: 0,
            max: 10,
            suffix: 'times',
            semanticLabel: 'Retry failed calls',
            onChanged: (v) => _patchDefaults({'retry': {...retry, 'max': v ?? 0, 'backoff': 'exponential', 'initial': wfStrOrNull(retry['initial']) ?? 'PT1M'}}),
          ),
        ),
        FbSetting(
          label: 'At most, for each',
          child: UiNumberInput(size: UiSize.sm, value: wfNum(d['forEachMax']) ?? 500, min: 1, max: 500, suffix: 'items', semanticLabel: 'At most, for each', onChanged: (v) => _patchDefaults({'forEachMax': v ?? 500})),
        ),
      ]),
      ..._problemsFor('retry'),
      ..._problemsFor('forEachMax'),
      FbSetting(
        label: 'A workflow starts again for the same record while running',
        child: WfSelect(
          label: 'A workflow starts again for the same record while running',
          value: wfStrOrNull(d['concurrency']) ?? 'perRecordSerial',
          options: const [(value: 'perRecordSerial', label: 'Wait for the earlier run'), (value: 'parallel', label: 'Run both'), (value: 'skipIfRunning', label: 'Don’t start it again')],
          onChanged: (v) => _patchDefaults({'concurrency': v}),
        ),
      ),
      ..._problemsFor('concurrency'),
      FbSetting(
        label: 'Stop chains of workflows starting workflows after',
        child: UiNumberInput(
          size: UiSize.sm,
          value: wfNum(d['maxChainDepth']) ?? 5,
          min: 1,
          max: 20,
          suffix: 'levels',
          semanticLabel: 'Stop chains of workflows starting workflows after',
          onChanged: (v) => _patchDefaults({'maxChainDepth': v ?? 5}),
        ),
      ),
      ..._problemsFor('maxChainDepth'),
      WfSwitch(
        value: _s.people?['delegation'] == true,
        label: 'People may hand tasks to someone else',
        onChanged: (on) => _patch({'people': wfPatch(_s.people ?? const {}, {'delegation': on ? true : null})}),
      ),
    ];
  }

  List<Widget> _channels() {
    final channels = _registry?.channels ?? const <UiWfLabelled>[];
    return [
      _h2('Notification channels'),
      const FbHint('The channels your app sends through. Switch one off to stop workflows using it.'),
      if (channels.isEmpty) const FbHint('The app has not registered any channels.'),
      for (final c in channels)
        _card([
          WfSwitch(value: _s.channels?[c.key]?['enabled'] != false, label: c.label, onChanged: (on) => _patchChannel(c.key, {'enabled': on ? null : false})),
          FbSetting(
            label: 'Footer added to every message',
            child: UiInput(
              key: ValueKey('f${c.key}$_resetKey'),
              size: UiSize.sm,
              value: wfStrOrNull(_s.channels?[c.key]?['footer']) ?? '',
              semanticLabel: '${c.label} footer',
              onChanged: (v) => _patchChannel(c.key, {'footer': v.isEmpty ? null : v}),
            ),
          ),
        ]),
    ];
  }

  List<Widget> _webhooksSection() {
    final t = context.ui;
    final conns = _s.connections;
    return [
      _h2('Webhooks'),
      const FbHint('Workflows can only call these addresses. Secrets stay on the server; a connection only names one.'),
      FbSetting(
        label: 'Allowed addresses',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
          if (_s.allowedOrigins.isNotEmpty) _items(_s.allowedOrigins, _removeOrigin, code: true),
          Row(spacing: t.space2, children: [
            Expanded(
              child: UiInput(
                key: ValueKey('o$_resetKey'),
                size: UiSize.sm,
                value: _newOrigin,
                placeholder: 'https://hooks.example.com',
                semanticLabel: 'Address',
                onChanged: (v) => setState(() => _newOrigin = v),
                onSubmitted: (_) => _addOrigin(),
              ),
            ),
            UiButton(label: 'Add', size: UiSize.sm, variant: UiButtonVariant.outline, onPressed: _addOrigin),
          ]),
          if (_originError.isNotEmpty) WfNote(_originError),
          ..._problemsFor('origins'),
        ]),
      ),
      FbSetting(
        label: 'Connections',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
          for (var i = 0; i < conns.length; i++)
            _card([
              WfPair(children: [
                UiInput(key: ValueKey('cl$i$_resetKey'), size: UiSize.sm, value: conns[i].label, placeholder: 'Name', semanticLabel: 'Name', onChanged: (v) => _patchConnection(i, {'label': v})),
                UiInput(
                  key: ValueKey('cu$i$_resetKey'),
                  size: UiSize.sm,
                  value: conns[i].baseUrl,
                  placeholder: 'https://erp.example.com/api',
                  semanticLabel: 'Base address',
                  onChanged: (v) => _patchConnection(i, {'baseUrl': v}),
                ),
                WfSelect(
                  label: 'Sign-in',
                  value: conns[i].auth,
                  options: const [(value: 'none', label: 'No secret'), (value: 'secret', label: 'Uses a secret')],
                  onChanged: (v) => _patchConnection(i, {'auth': v}),
                ),
                if (conns[i].auth == 'secret')
                  UiInput(
                    key: ValueKey('cs$i$_resetKey'),
                    size: UiSize.sm,
                    value: conns[i].secretName ?? '',
                    placeholder: 'Secret name (set on the server)',
                    semanticLabel: 'Secret name',
                    onChanged: (v) => _patchConnection(i, {'secretName': v}),
                  ),
              ]),
              Text.rich(
                TextSpan(children: [
                  const TextSpan(text: 'Key '),
                  TextSpan(text: conns[i].key, style: context.uiText.code.copyWith(fontSize: 12, color: t.textSecondary)),
                  if (_isSaved(conns[i].key)) TextSpan(text: ' · webhook steps use it, so it stays when the name changes', style: TextStyle(color: t.textMuted)),
                ]),
                style: context.uiText.body.copyWith(fontSize: 12, color: t.textSecondary),
              ),
              Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Remove', color: t.danger, onTap: () => _removeConnection(i))),
              ..._problemsFor('conn:$i'),
            ]),
          ..._problemsFor('connections'),
          Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Add a connection', icon: WfIcons.add01, onTap: _addConnection)),
        ]),
      ),
    ];
  }

  List<Widget> _auditSection() {
    final t = context.ui;
    final retention = wfMapOrNull(_audit['retentionDays']) ?? const {};
    final taken = _s.maskedFields.toSet();
    final maskable = <WfOption>[
      for (final e in _registry?.entities ?? const <UiWfEntityDescriptor>[])
        for (final f in e.fields)
          if (!f.sensitive && !taken.contains('${e.key}.${f.key}') && f.type != 'collection') (value: '${e.key}.${f.key}', label: '${e.label} › ${f.label}'),
    ];
    return [
      _h2('Audit log'),
      const FbHint('Every change and decision is recorded in a tamper-evident chain. Old entries can be removed after a while; the chain stays checkable.'),
      LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / 158).floor().clamp(1, 4);
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in _auditCategories)
            SizedBox(
              width: w,
              child: FbSetting(
                label: c.label,
                child: UiNumberInput(
                  key: ValueKey('r${c.value}$_resetKey'),
                  size: UiSize.sm,
                  value: wfNum(retention[c.value]),
                  min: 1,
                  suffix: 'days',
                  placeholder: 'Keep',
                  semanticLabel: '${c.label}: days to keep',
                  onChanged: (v) => _setRetention(c.value, v),
                ),
              ),
            ),
        ]);
      }),
      ..._problemsFor('retention'),
      FbSetting(
        label: 'Hide these values in the log and run views',
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
          if (_s.maskedFields.isNotEmpty) _items(_s.maskedFields, _removeMasked, removeVerb: 'Stop hiding', labelOf: _fieldName),
          WfSelect(key: ValueKey('m$_resetKey'), label: 'Add a field to hide', placeholder: 'Add a field…', value: null, options: maskable, onChanged: _addMasked),
          ..._problemsFor('masked'),
          const FbHint('Fields the app marks as sensitive are always hidden.'),
          SizedBox(height: t.space1),
        ]),
      ),
    ];
  }

  List<Widget> _watching() {
    final t = context.ui;
    final groups = <String, List<UiWfTriggerOverview>>{};
    for (final tr in _triggers) {
      (groups[tr.entity ?? ''] ??= []).add(tr);
    }
    final conflicts = <String>{
      for (final a in _triggers)
        for (final b in _triggers)
          if (!identical(a, b) && a.entity == b.entity && a.type == b.type && (a.field ?? '').isNotEmpty && a.field == b.field && a.type != 'lifecycle') a.definitionId,
    };
    return [
      _h2('What is being watched'),
      const FbHint('Every published workflow and what starts it, by record type. Pause a record type to stop new runs while you sort something out; pausing saves at once and leaves other unsaved changes as they are.'),
      if (_error.isNotEmpty) WfNote(_error) else if (_status.isNotEmpty) Semantics(liveRegion: true, child: FbHint(_status)),
      ..._problemsFor('paused'),
      if (groups.isEmpty) const FbHint('Nothing is published yet.'),
      for (final MapEntry(key: entity, value: triggers) in groups.entries)
        () {
          final label = _registry?.entities.where((e) => e.key == entity).firstOrNull?.label ?? (entity.isNotEmpty ? entity : 'Not about a record');
          var conflict = false;
          for (var i = 0; i < triggers.length; i++) {
            for (var j = i + 1; j < triggers.length; j++) {
              final a = triggers[i], b = triggers[j];
              if (a.type == b.type && a.type != 'lifecycle' && a.field == b.field && (a.field ?? '').isNotEmpty) conflict = true;
            }
          }
          return _card([
            Row(children: [
              Expanded(child: Text(label, style: context.uiText.body.copyWith(fontSize: 13.5 * context.ui.fontScale, fontWeight: FontWeight.w700, color: t.text))),
              Align(
                alignment: AlignmentDirectional.centerStart,
                widthFactor: 1,
                // On means running: an off switch reads "Paused".
                child: UiSwitch(
                  value: !_isPaused(entity),
                  size: UiSize.sm,
                  label: _isPaused(entity) ? 'Paused' : 'Running',
                  semanticLabel: 'Run workflows for $label',
                  onChanged: _busy ? null : (on) => _setPaused(entity, !on),
                ),
              ),
            ]),
            for (final tr in triggers)
              Row(spacing: 6, crossAxisAlignment: CrossAxisAlignment.start, children: [
                // One chip width, so the workflow names line up whatever their kind.
                ConstrainedBox(constraints: const BoxConstraints(minWidth: 76), child: WfChip(tr.kind == 'lifecycle' ? 'Lifecycle' : 'Automation')),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(text: tr.title),
                      TextSpan(text: ' — ${tr.summary}', style: TextStyle(color: t.textMuted, fontSize: 12.5)),
                    ]),
                    style: context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, color: conflicts.contains(tr.definitionId) ? t.warning : t.text),
                  ),
                ),
              ]),
            if (conflict) const WfNote('Two workflows start on the same change here. Check they don’t work against each other.', warning: true, alert: false),
          ]);
        }(),
    ];
  }

  List<Widget> _registrySection() {
    final t = context.ui;
    final reg = _registry;
    final small = context.uiText.body.copyWith(fontSize: 12.5, color: t.text);
    final muted = small.copyWith(color: t.textMuted);
    return [
      _h2('What workflows can use'),
      const FbHint('Set by the app’s developers. Ask them to add a record type, field or action.'),
      UiAccordion(multiple: true, children: [
      for (final e in reg?.entities ?? const <UiWfEntityDescriptor>[])
        UiAccordionItem(
          title: '${e.label} · ${e.fields.length} fields',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final row in [null, ...e.fields])
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(border: Border(top: BorderSide(color: t.borderSubtle))),
                child: Row(spacing: 6, children: [
                  Expanded(
                    flex: 4,
                    child: row == null
                        ? Text('Field', style: muted)
                        : Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text(row.label, style: small),
                            if (row.sensitive) const WfChip('sensitive', tone: 'warning'),
                            if (row.lifecycle) const WfChip('lifecycle', tone: 'info'),
                          ]),
                  ),
                  Expanded(flex: 2, child: Text(row == null ? 'Type' : row.type, style: row == null ? muted : small)),
                  Expanded(flex: 2, child: Text(row == null ? 'Watch' : (row.watchable ? 'Yes' : ''), style: row == null ? muted : small)),
                  Expanded(flex: 2, child: Text(row == null ? 'Change' : (row.settable ? 'Yes' : ''), style: row == null ? muted : small)),
                ]),
              ),
          ]),
        ),
      ]),
      if (reg?.actions?.isNotEmpty ?? false) ...[
        Text('Actions', style: context.uiText.label.copyWith(fontSize: 13 * context.ui.fontScale, color: t.text)),
        for (final a in reg!.actions!)
          Text.rich(TextSpan(children: [TextSpan(text: '${a.label} ', style: const TextStyle(fontWeight: FontWeight.w700)), TextSpan(text: a.description ?? '', style: muted)]), style: small),
      ],
      if (reg?.signals?.isNotEmpty ?? false) ...[
        Text('Events', style: context.uiText.label.copyWith(fontSize: 13 * context.ui.fontScale, color: t.text)),
        for (final sg in reg!.signals!) Text(sg.label, style: small),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 620;
      final bounded = box.hasBoundedHeight;
      final content = switch (_section) {
        'defaults' => _defaults(),
        'channels' => _channels(),
        'webhooks' => _webhooksSection(),
        'audit' => _auditSection(),
        'watching' => _watching(),
        'registry' => _registrySection(),
        _ => _time(),
      };
      Widget body = Padding(
        padding: EdgeInsets.all(t.space4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, spacing: t.space3, children: content),
        ),
      );
      body = Align(alignment: Alignment.topLeft, child: body);
      // Content running on under the footer fades out, so it reads as "scrolls on", not "cut off".
      if (bounded) body = Expanded(child: UiScrollFade(axis: Axis.vertical, child: SingleChildScrollView(child: body)));
      final showFoot = _section != 'watching' && _section != 'registry';
      final foot = Container(
        padding: EdgeInsets.symmetric(horizontal: t.space4, vertical: 8),
        decoration: BoxDecoration(color: t.surface, border: Border(top: BorderSide(color: t.border))),
        child: Row(spacing: 8, children: [
          Expanded(child: _error.isNotEmpty ? WfNote(_error) : FbHint(_status)),
          UiButton(label: 'Discard', size: UiSize.sm, variant: UiButtonVariant.ghost, onPressed: !dirty || _busy ? null : _discard),
          UiButton(label: 'Save settings', size: UiSize.sm, onPressed: !dirty || _busy ? null : save),
        ]),
      );
      final nav = _Nav(section: _section, wide: wide, divider: bounded, bad: _badSections, onSelect: (s) => setState(() => _section = s));
      final main = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
        children: [if (!wide) nav, body, if (showFoot) foot],
      );
      return DefaultTextStyle.merge(
        style: context.uiText.body.copyWith(fontSize: 13.5 * context.ui.fontScale, color: t.text),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: t.bg, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
          child: !wide
              ? main
              : bounded
              ? Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [nav, Expanded(child: main)])
              // Unbounded: the section column is the taller one, so it draws the divider.
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  nav,
                  Expanded(
                    child: Container(decoration: BoxDecoration(border: Border(left: BorderSide(color: t.border))), child: main),
                  ),
                ]),
        ),
      );
    });
  }
}

class _Nav extends StatelessWidget {
  const _Nav({required this.section, required this.wide, required this.onSelect, this.divider = true, this.bad = const {}});

  /// Sections with a problem to fix, marked with a dot.
  final Set<String> bad;
  final String section;
  final bool wide;
  final bool divider;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    Widget item(WfOption s) {
      final on = s.value == section;
      return UiInteractive(
        onTap: () => onSelect(s.value),
        semanticLabel: bad.contains(s.value) ? '${s.label}, needs fixing' : s.label,
        selected: on,
        excludeChildSemantics: true,
        pressScale: false,
        builder: (context, st) => Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            color: on ? t.primary.withValues(alpha: 0.12) : (st.hovered ? t.surfaceHover : null),
            borderRadius: BorderRadius.circular(t.radiusXs),
            boxShadow: st.focused ? t.focusRing : null,
          ),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: t.space2, children: [
            Text(s.label, maxLines: 1, style: context.uiText.body.copyWith(fontSize: 13 * context.ui.fontScale, fontWeight: on ? FontWeight.w600 : FontWeight.w400, color: on || st.hovered ? t.text : t.textSecondary)),
            if (bad.contains(s.value)) Container(key: ValueKey('bad-${s.value}'), width: 6, height: 6, decoration: BoxDecoration(color: t.danger, shape: BoxShape.circle)),
          ]),
        ),
      );
    }

    return Semantics(
      container: true,
      label: 'Settings sections',
      child: Container(
        width: wide ? 200 : null,
        padding: EdgeInsets.all(t.space2),
        decoration: BoxDecoration(
          color: t.surface,
          border: wide ? (divider ? Border(right: BorderSide(color: t.border)) : null) : Border(bottom: BorderSide(color: t.border)),
        ),
        child: wide
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: [for (final s in _sections) item(s)])
            // On a phone the sections wrap onto a second row rather than scrolling out of sight.
            : Wrap(spacing: 2, runSpacing: 2, children: [for (final s in _sections) IntrinsicWidth(child: item(s))]),
      ),
    );
  }
}
