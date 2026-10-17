import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../button/button.dart';
import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../datepicker/date_picker.dart';
import '../dialog/modal.dart';
import '../form_builder/editor/form_builder.dart';
import '../form_builder/engine/definition.dart' show createDefinition, migrateDefinition;
import '../form_builder/engine/field_types.dart';
import '../form_builder/engine/schema.dart' show UiFbOperator;
import '../forms/choice/token_input.dart';
import '../forms/text/inputs.dart';
import '../forms/text/number_input.dart';
import '../forms/text/time_picker.dart';
import '../theme/theme.dart';
import 'api.dart';
import 'bits.dart';
import 'definition.dart';
import 'icons.dart';
import 'json.dart';
import 'schema.dart';

// ── Token select ────────────────────────────────────────────────────────────────────────────

/// `ui-wf-token-select`: pick a value to read (a field of the record, an earlier step's result…).
/// Options read "Group › Label", the web select's option groups.
class WfTokenSelect extends StatelessWidget {
  const WfTokenSelect({
    super.key,
    required this.tokens,
    required this.value,
    required this.onChanged,
    this.types,
    this.placeholder = 'Choose a value…',
    this.label = 'Value',
    this.enabled = true,
  });

  final List<UiWfToken> tokens;
  final String? value;
  final ValueChanged<String> onChanged;

  /// Only offer tokens of these types (`any` tokens always pass).
  final List<String>? types;
  final String placeholder;
  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final filtered = [for (final tk in tokens) if (types == null || tk.type == 'any' || types!.contains(tk.type)) tk];
    return WfSelect(
      label: label,
      placeholder: placeholder,
      enabled: enabled,
      value: value,
      options: [for (final tk in filtered) (value: tk.path, label: tokenLabel(filtered, tk.path))],
      onChanged: onChanged,
    );
  }
}

// ── Template ────────────────────────────────────────────────────────────────────────────────

/// A template as token-input runs.
List<UiTokenRun> wfTemplateRuns(UiWfTemplate? t) {
  if (t == null) return const [];
  return [for (final p in t.parts) p is UiWfTemplateRef ? UiTokenRun.token(p.ref) : UiTokenRun.text(p as String)];
}

/// Token-input runs as a template: plain text stays a string, text with tokens a list.
UiWfTemplate wfTemplateFromRuns(List<UiTokenRun> runs) {
  final parts = <Object>[];
  for (final r in runs) {
    if (r.token != null) {
      parts.add({'ref': r.token});
    } else if ((r.text ?? '').isNotEmpty) {
      if (parts.isNotEmpty && parts.last is String) {
        parts[parts.length - 1] = (parts.last as String) + r.text!;
      } else {
        parts.add(r.text!);
      }
    }
  }
  if (parts.isEmpty) return const UiWfTemplate.text('');
  return parts.length == 1 && parts[0] is String ? UiWfTemplate.text(parts[0] as String) : UiWfTemplate.parts(parts);
}

/// `ui-wf-template`: text with values from the workflow mixed in ("Hello [Applicant], your
/// application [Title] was approved"). Values are chips; pick one from "Insert a value…" and it
/// lands at the caret.
class WfTemplateEditor extends StatefulWidget {
  const WfTemplateEditor({super.key, required this.tokens, required this.value, required this.onChanged, this.multiline = true, this.placeholder = '', this.label = 'Text'});
  final List<UiWfToken> tokens;
  final UiWfTemplate? value;
  final ValueChanged<UiWfTemplate> onChanged;
  final bool multiline;
  final String placeholder;
  final String label;

  @override
  State<WfTemplateEditor> createState() => _WfTemplateEditorState();
}

class _WfTemplateEditorState extends State<WfTemplateEditor> {
  final GlobalKey<UiTokenInputState> _input = GlobalKey();
  int _insertKey = 0;

  void _change(List<UiTokenRun> runs) {
    final next = wfTemplateFromRuns(runs);
    if (!jsonEquals(next.json, widget.value?.json ?? '')) widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
      UiTokenInput(
        key: _input,
        value: wfTemplateRuns(widget.value),
        onChanged: _change,
        multiline: widget.multiline,
        placeholder: widget.placeholder,
        label: widget.label,
        minHeight: widget.multiline ? 84 : null,
        tokenLabel: (path) => tokenLabel(widget.tokens, path),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: WfTokenSelect(
            // A fresh select each time so it shows its placeholder again.
            key: ValueKey(_insertKey),
            tokens: widget.tokens,
            value: null,
            placeholder: 'Insert a value…',
            label: 'Insert a value into ${widget.label}',
            onChanged: (path) {
              final s = _input.currentState;
              if (s != null) {
                s.insertToken(path);
              } else {
                widget.onChanged(wfTemplateFromRuns([...wfTemplateRuns(widget.value), UiTokenRun.token(path)]));
              }
              setState(() => _insertKey++);
            },
          ),
        ),
      ),
      SizedBox(height: t.space1 / 2),
    ]);
  }
}

// ── Duration ────────────────────────────────────────────────────────────────────────────────

/// A one-unit ISO duration: an amount, a unit (`M` minutes, `H`, `D`, `W`, `Mo` months), and a sign.
typedef WfSimpleDuration = ({int n, String unit, bool negative});

final RegExp _simple = RegExp(r'^(-)?P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$');

/// Reads an ISO duration as one number and unit (`P3D` is 3 days). Durations written with several
/// parts elsewhere become their total in the largest unit that keeps them exact (`P1DT12H` is 36
/// hours); null when that's impossible (months mixed with days) or it isn't a duration.
WfSimpleDuration? parseSimpleDuration(String? iso) {
  final text = iso ?? '';
  final m = _simple.firstMatch(text);
  if (m == null || text == 'P' || text == '-P' || text.endsWith('T')) return null;
  final negative = m.group(1) != null;
  int g(int i) => int.parse(m.group(i) ?? '0');
  final months = g(2) * 12 + g(3);
  final w = g(4), d = g(5), h = g(6), mi = g(7), sec = g(8);
  final minutes = ((w * 7 + d) * 24 + h) * 60 + mi + (sec / 60).round();
  if (months != 0 && minutes != 0) return null;
  if (months != 0) return (n: months, unit: 'Mo', negative: negative);
  if (w != 0 && d == 0 && h == 0 && mi == 0 && sec == 0) return (n: w, unit: 'W', negative: negative);
  if (minutes % 1440 == 0) return (n: minutes ~/ 1440, unit: 'D', negative: negative);
  if (minutes % 60 == 0) return (n: minutes ~/ 60, unit: 'H', negative: negative);
  return (n: minutes, unit: 'M', negative: negative);
}

/// The most of each unit a duration may hold (the engines refuse more than 50 years).
const Map<String, int> wfDurationUnitMax = {'Mo': 600, 'W': 2600, 'D': 18250, 'H': 438000, 'M': 26280000};

String formatSimpleDuration(num n, String unit, [bool negative = false]) {
  final v = n.isFinite ? math.min(wfDurationUnitMax[unit] ?? 600, n < 0 ? 0 : n.round()) : 0;
  final body = switch (unit) { 'Mo' => 'P${v}M', 'W' => 'P${v}W', 'D' => 'P${v}D', 'H' => 'PT${v}H', _ => 'PT${v}M' };
  return (negative ? '-' : '') + body;
}

const List<WfOption> _units = [
  (value: 'M', label: 'minutes'), (value: 'H', label: 'hours'), (value: 'D', label: 'days'), (value: 'W', label: 'weeks'), (value: 'Mo', label: 'months'),
];

/// `ui-wf-duration`: "3 days", "4 hours", stored as an ISO 8601 duration. [signed] adds before/after.
class WfDurationInput extends StatelessWidget {
  const WfDurationInput({super.key, required this.value, required this.onChanged, this.label = 'Duration', this.signed = false});
  final String? value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool signed;

  @override
  Widget build(BuildContext context) {
    final p = parseSimpleDuration(value) ?? (n: 1, unit: 'D', negative: false);
    // The unit select keeps room for its longest word ("minutes", "months"), the direction for
    // "before"; the amount takes what is left, up to 96. (The web reserves 88 and 76; this select's
    // padding and chevron need a little more.) Touch steppers are 48 wide each and don't fit a box
    // this small, so on touch the amount is typed (a number keyboard) and can shrink to 64; with a
    // mouse its 24-wide steppers stay and it keeps 88.
    const unitMin = 108.0, directionMin = 96.0;
    final touch = uiTouchPlatform(context);
    return LayoutBuilder(builder: (context, box) {
      final rest = box.maxWidth - 6 - unitMin - (signed ? 6 + directionMin : 0);
      final amount = rest.clamp(touch ? 64.0 : 88.0, signed ? 88.0 : 96.0);
      return Row(spacing: 6, children: [
        SizedBox(
          width: amount,
          child: UiNumberInput(
            size: UiSize.sm,
            steppers: !touch,
            value: p.n,
            min: 0,
            max: wfDurationUnitMax[p.unit],
            semanticLabel: '$label amount',
            onChanged: (v) => onChanged(formatSimpleDuration(v ?? 0, p.unit, p.negative)),
          ),
        ),
        Expanded(flex: 10, child: WfSelect(label: '$label unit', value: p.unit, options: _units, onChanged: (u) => onChanged(formatSimpleDuration(p.n, u, p.negative)))),
        if (signed)
          Expanded(
            flex: 9,
            child: WfSelect(
              label: '$label direction',
              value: p.negative ? 'before' : 'after',
              options: const [(value: 'before', label: 'before'), (value: 'after', label: 'after')],
              onChanged: (d) => onChanged(formatSimpleDuration(p.n, p.unit, d == 'before')),
            ),
          ),
      ]);
    });
  }
}

// ── People ──────────────────────────────────────────────────────────────────────────────────

final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// `ui-wf-assignees`: who a task is for, who may apply a transition, or who gets a message: roles,
/// groups, people, a person stored on the record, someone's manager, or whoever started the run.
class WfAssigneesEditor extends StatefulWidget {
  const WfAssigneesEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.registry,
    this.tokens = const [],
    this.api,
    this.label = 'people',
    this.emptyText = '',
    this.allowEmail = false,
    this.allowManagerOfAssignees = false,
  });

  final List<UiWfAssignee> value;
  final ValueChanged<List<UiWfAssignee>> onChanged;
  final UiWorkflowRegistry? registry;
  final List<UiWfToken> tokens;
  final UiWorkflowApi? api;
  final String label;
  final String emptyText;
  final bool allowEmail;
  final bool allowManagerOfAssignees;

  @override
  State<WfAssigneesEditor> createState() => _WfAssigneesEditorState();
}

class _WfAssigneesEditorState extends State<WfAssigneesEditor> {
  bool _searching = false;
  bool _emailing = false;
  String _query = '';
  String _emailText = '';
  List<UiWfUser> _results = const [];
  final Map<String, String> _names = {};
  int _searchSeq = 0;
  int _addKey = 0;

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  @override
  void didUpdateWidget(WfAssigneesEditor old) {
    super.didUpdateWidget(old);
    _loadNames();
  }

  /// Show people by name, not id.
  void _loadNames() {
    final api = widget.api;
    if (api == null) return;
    for (final a in widget.value) {
      if (a.kind != 'user' || _names.containsKey(a.value)) continue;
      final id = a.value;
      _names[id] = id;
      api.user(id).then((u) {
        if (u != null && mounted) setState(() => _names[id] = u.name);
      }).catchError((Object _) {});
    }
  }

  List<UiWfToken> get _userTokens => [for (final t in widget.tokens) if (t.type == 'user' && !t.path.startsWith('steps.')) t];

  String _describe(UiWfAssignee a) => describeAssignees(
    [a],
    UiWfDescribeContext(registry: widget.registry, def: createWorkflow('automation'), tokens: widget.tokens, userName: (id) => _names[id]),
  );

  void _push(UiWfAssignee a) {
    final json = jsonStringify(a.json);
    if (widget.value.any((x) => jsonStringify(x.json) == json)) return;
    widget.onChanged([...widget.value, a]);
  }

  void _add(String v) {
    setState(() => _addKey++);
    if (v == 'person') {
      setState(() {
        _searching = true;
        _emailing = false;
      });
      return;
    }
    if (v == 'email') {
      setState(() {
        _emailing = true;
        _searching = false;
      });
      return;
    }
    final i = v.indexOf(':');
    final kind = i < 0 ? v : v.substring(0, i);
    final key = i < 0 ? '' : v.substring(i + 1);
    _push(switch (kind) {
      'role' => UiWfAssignee.role(key),
      'group' => UiWfAssignee.group(key),
      'field' => UiWfAssignee.field(key),
      'managerOf' => UiWfAssignee.managerOf(key),
      _ => UiWfAssignee.initiator(),
    });
  }

  void _search(String q) {
    setState(() => _query = q);
    final api = widget.api;
    final n = ++_searchSeq;
    if (api == null || q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    api.searchUsers(q.trim(), take: 10).then((r) {
      if (n == _searchSeq && mounted) setState(() => _results = r);
    }).catchError((Object _) {
      if (mounted) setState(() => _results = const []);
    });
  }

  void _pickUser(UiWfUser u) {
    _names[u.id] = u.name;
    _push(UiWfAssignee.user(u.id));
    setState(() {
      _searching = false;
      _query = '';
      _results = const [];
    });
  }

  void _addEmail() {
    final e = _emailText.trim();
    if (!_email.hasMatch(e)) return;
    _push(UiWfAssignee.email(UiWfTemplate.text(e)));
    setState(() {
      _emailText = '';
      _emailing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final reg = widget.registry;
    final users = _userTokens;
    final options = <WfOption>[
      for (final r in reg?.roles ?? const <UiWfLabelled>[]) (value: 'role:${r.key}', label: 'Everyone with a role › ${r.label}'),
      for (final g in reg?.groups ?? const <UiWfLabelled>[]) (value: 'group:${g.key}', label: 'A group › ${g.label}'),
      for (final u in users) (value: 'field:${u.path}', label: 'A person on the record › ${u.group} › ${u.label}'),
      (value: 'initiator', label: 'Whoever started it'),
      (value: 'managerOf:initiator', label: 'The manager of whoever started it'),
      if (widget.allowManagerOfAssignees) (value: 'managerOf:assignees', label: 'Their managers'),
      for (final u in users) (value: 'managerOf:${u.path}', label: 'Manager of ${u.label}'),
      if (widget.api != null) (value: 'person', label: 'A specific person…'),
      if (widget.allowEmail) (value: 'email', label: 'An email address…'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
      if (widget.value.isNotEmpty)
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (var i = 0; i < widget.value.length; i++) _PersonChip(label: _describe(widget.value[i]), onRemove: () => widget.onChanged([...widget.value]..removeAt(i))),
        ])
      else if (widget.emptyText.isNotEmpty)
        FbHint(widget.emptyText),
      WfSelect(key: ValueKey(_addKey), label: 'Add to ${widget.label}', placeholder: 'Add…', value: null, options: options, onChanged: _add),
      if (_searching)
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 4, children: [
          UiInput(size: UiSize.sm, value: _query, placeholder: 'Search people by name', semanticLabel: 'Search people', autofocus: true, onChanged: _search),
          if (_results.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(border: Border.all(color: t.border), borderRadius: BorderRadius.circular(t.radius)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (final u in _results)
                  UiInteractive(
                    onTap: () => _pickUser(u),
                    semanticLabel: u.name,
                    excludeChildSemantics: true,
                    pressScale: false,
                    builder: (context, s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: s.hovered || s.focused ? t.surfaceHover : null, borderRadius: BorderRadius.circular(t.radiusXs)),
                      child: Row(children: [
                        Expanded(child: Text(u.name, style: context.uiText.body.copyWith(fontSize: 13, color: t.text))),
                        Text(u.email ?? u.id, style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
                      ]),
                    ),
                  ),
              ]),
            )
          else if (_query.isNotEmpty)
            const FbHint('Nobody found.'),
        ]),
      if (_emailing)
        Row(spacing: t.space2, children: [
          Expanded(
            child: UiInput(
              size: UiSize.sm,
              type: UiInputType.email,
              value: _emailText,
              placeholder: 'name@example.com',
              semanticLabel: 'Email address',
              autofocus: true,
              onChanged: (v) => setState(() => _emailText = v),
              onSubmitted: (_) => _addEmail(),
            ),
          ),
          FbLink(label: 'Add', onTap: _addEmail),
        ]),
    ]);
  }
}

class _PersonChip extends StatelessWidget {
  const _PersonChip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return Container(
      height: 24,
      padding: const EdgeInsets.only(left: 7),
      decoration: BoxDecoration(color: t.surfaceHover, borderRadius: BorderRadius.circular(t.radiusXs)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.uiText.label.copyWith(fontSize: 12, fontWeight: FontWeight.w500, color: t.text))),
        UiInteractive(
          onTap: onRemove,
          semanticLabel: 'Remove $label',
          excludeChildSemantics: true,
          pressScale: false,
          builder: (context, s) => Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.hovered ? t.danger.withValues(alpha: 0.12) : null,
              borderRadius: BorderRadius.circular(3),
              boxShadow: s.focused ? t.focusRing : null,
            ),
            child: UiIcon(WfIcons.cancel01, size: 11, strokeWidth: 2, color: s.hovered ? t.danger : t.textMuted),
          ),
        ),
      ]),
    );
  }
}

// ── Values ──────────────────────────────────────────────────────────────────────────────────

/// A typed input for one constant value of a registry field.
class WfValueInput extends StatelessWidget {
  const WfValueInput({super.key, this.field, this.type, required this.value, required this.onChanged, this.label = 'Value', this.placeholder = ''});
  final UiWfFieldDescriptor? field;

  /// A registry field type (or `any`), when there's no [field].
  final String? type;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String label;
  final String placeholder;

  String get _kind {
    final t = field?.type ?? type;
    if (t == 'enum' && (field?.options?.isNotEmpty ?? false)) return 'enum';
    if (t == 'boolean') return 'boolean';
    if (t == 'number' || t == 'currency') return 'number';
    if (t == 'date') return 'date';
    if (t == 'dateTime') return 'dateTime';
    return 'text';
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    switch (_kind) {
      case 'enum':
        final opts = field!.options!;
        return WfSelect(
          label: label,
          placeholder: 'Choose…',
          value: v == null || v == '' ? null : jsString(v),
          options: [for (final o in opts) (value: jsString(o.value), label: o.label)],
          // Keep numbers as numbers when the options are numeric.
          onChanged: (s) => onChanged(opts.where((o) => jsString(o.value) == s).firstOrNull?.value ?? s),
        );
      case 'boolean':
        return WfSelect(label: label, value: v == true ? 'true' : 'false', options: const [(value: 'true', label: 'Yes'), (value: 'false', label: 'No')], onChanged: (s) => onChanged(s == 'true'));
      case 'number':
        return UiNumberInput(size: UiSize.sm, value: v is num ? v : null, steppers: false, semanticLabel: label, onChanged: onChanged);
      case 'date':
        return UiDatePicker(size: UiSize.sm, value: v is String && v.isNotEmpty ? v : null, label: label, onChanged: onChanged);
      case 'dateTime':
        final local = v is String && v.isNotEmpty ? DateTime.tryParse(v)?.toLocal() : null;
        String two(int n) => n.toString().padLeft(2, '0');
        final date = local == null ? null : '${local.year}-${two(local.month)}-${two(local.day)}';
        final time = local == null ? null : '${two(local.hour)}:${two(local.minute)}';
        void emit(String? d, String? tm) {
          if (d == null) return onChanged(null);
          final parsed = DateTime.tryParse('${d}T${tm ?? '00:00'}');
          onChanged(parsed?.toUtc().toIso8601String());
        }

        return Row(spacing: 6, children: [
          Expanded(flex: 3, child: UiDatePicker(size: UiSize.sm, value: date, label: '$label date', onChanged: (d) => emit(d, time))),
          Expanded(flex: 2, child: UiTimePicker(size: UiSize.sm, value: time, label: '$label time', onChanged: (tm) => emit(date, tm))),
        ]);
      default:
        return UiInput(size: UiSize.sm, value: v == null ? '' : jsString(v), semanticLabel: label, placeholder: placeholder, onChanged: onChanged);
    }
  }
}

/// `ui-wf-operand`: what a field is set to: a fixed value, another value from the workflow, or a
/// date relative to today.
class WfOperandEditor extends StatelessWidget {
  const WfOperandEditor({super.key, required this.value, required this.onChanged, this.field, this.type, this.tokens = const [], this.label = 'Value'});
  final UiWfOperand? value;
  final ValueChanged<UiWfOperand> onChanged;
  final UiWfFieldDescriptor? field;
  final String? type;
  final List<UiWfToken> tokens;
  final String label;

  String get _mode {
    final v = value;
    if (v == null) return 'const';
    if (v.isRef) return 'ref';
    if (v.isToday) return 'today';
    if (v.isCalc) return 'calc';
    return 'const';
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;
    final isDate = (field?.type ?? type) == 'date';
    final Widget input = switch (mode) {
      'ref' => WfTokenSelect(tokens: tokens, value: value?.ref, label: label, onChanged: (p) => onChanged(UiWfOperand.ref(p))),
      'today' => UiNumberInput(size: UiSize.sm, value: value?.today ?? 0, semanticLabel: '$label: days from today', onChanged: (n) => onChanged(UiWfOperand.today(n ?? 0))),
      'calc' => const FbHint('Set up in the JSON (calculation)'),
      _ => WfValueInput(field: field, type: type, value: value?.constValue, label: label, onChanged: (v) => onChanged(UiWfOperand.constant(v))),
    };
    return LayoutBuilder(builder: (context, box) {
      final mode0 = WfSelect(
        label: '$label: source',
        value: mode,
        options: [
          (value: 'const', label: 'A value'),
          (value: 'ref', label: 'From…'),
          if (isDate) (value: 'today', label: 'Days from today'),
          if (mode == 'calc') (value: 'calc', label: 'A calculation'),
        ],
        onChanged: (m) => onChanged(m == 'ref' ? UiWfOperand.ref('') : m == 'today' ? UiWfOperand.today(0) : UiWfOperand.constant(null)),
      );
      return Row(spacing: 6, children: [
        SizedBox(width: (box.maxWidth * 0.36).clamp(90, 160), child: mode0),
        Expanded(child: input),
      ]);
    });
  }
}

// ── Conditions ──────────────────────────────────────────────────────────────────────────────

const Set<String> _multiOps = {'anyOf', 'noneOf', 'includesAny', 'includesAll'};

UiWfCondition _asGroup(UiWfCondition? c) {
  if (c == null) return UiWfCondition.empty();
  return c.isGroup ? c : UiWfCondition.group('all', [c]);
}

List<UiFbOperatorInfo> _opsFor(UiWfToken? token) => operatorsFor(valueKindOfField(token?.type == 'any' ? null : token?.type).subject);

/// One rule: "[value] [is any of] [Approved, Rejected]".
class WfRuleEditor extends StatelessWidget {
  const WfRuleEditor({super.key, required this.rule, required this.tokens, required this.onChanged, required this.onRemove});
  final UiWfCondition rule;
  final List<UiWfToken> tokens;
  final ValueChanged<UiWfCondition> onChanged;
  final VoidCallback onRemove;

  UiWfToken? get _token => tokens.where((t) => t.path == rule.ref).firstOrNull;

  Object? _constOf(UiWfOperand? v) => v != null && v.isConst ? v.constValue : null;

  void _patch(UiJson p) => onChanged(UiWfCondition.fromJson(wfPatch(rule.json, p)));

  void _setRef(String ref) {
    final ops = _opsFor(tokens.where((x) => x.path == ref).firstOrNull);
    final op = ops.any((o) => o.op.name == rule.op) ? rule.op : ops.first.op.name;
    onChanged(UiWfCondition.fromJson({'ref': ref, 'op': op}));
  }

  void _setOp(String op) {
    final info = operatorInfo(UiFbOperator(op));
    final keep = _multiOps.contains(op) == _multiOps.contains(rule.op) ? rule.value : null;
    final next = <String, Object?>{...rule.json}..remove('value')..remove('value2');
    next['op'] = op;
    if (info.arity > 0 && keep != null) next['value'] = keep.json;
    if (info.arity == 2 && rule.value2 != null) next['value2'] = rule.value2!.json;
    onChanged(UiWfCondition.fromJson(next));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final token = _token;
    final ops = _opsFor(token);
    final arity = operatorInfo(UiFbOperator(rule.op)).arity;
    final multi = _multiOps.contains(rule.op);
    final countOp = rule.op == 'countGte' || rule.op == 'countLte';
    final isDate = token?.type == 'date' || token?.type == 'dateTime';
    final options = token?.options ?? const <UiWfFieldOption>[];
    final v = rule.value;
    final compareMode = v != null && v.isRef ? 'ref' : (v != null && v.isToday ? 'today' : 'const');
    final c = _constOf(v);
    final listValue = c is List ? [for (final x in c) jsString(x)] : (c == null || c == '' ? <String>[] : [jsString(c)]);

    Widget valueInput() {
      if (compareMode == 'ref') {
        return WfTokenSelect(tokens: tokens, value: v?.ref, label: 'Compare with', onChanged: (p) => _patch({'value': UiWfOperand.ref(p).json}));
      }
      if (compareMode == 'today') {
        return Row(spacing: 6, children: [
          SizedBox(width: 96, child: UiNumberInput(size: UiSize.sm, value: v?.today ?? 0, semanticLabel: 'Days from today', onChanged: (n) => _patch({'value': UiWfOperand.today(n ?? 0).json}))),
          const Flexible(child: FbHint('days from today')),
        ]);
      }
      if (multi && options.isNotEmpty) {
        return WfChecks(
          label: 'Values',
          options: [for (final o in options) (value: jsString(o.value), label: o.label)],
          isChecked: listValue.contains,
          onChanged: (x, on) {
            final next = on ? {...listValue, x}.toList() : listValue.where((y) => y != x).toList();
            // Keep numbers as numbers when the options are numeric.
            final typed = [for (final s in next) options.where((o) => jsString(o.value) == s).firstOrNull?.value ?? s];
            _patch({'value': UiWfOperand.constant(typed).json});
          },
        );
      }
      return WfValueInput(
        field: token?.options != null ? UiWfFieldDescriptor.fromJson({'key': '', 'label': '', 'type': 'enum', 'options': [for (final o in token!.options!) o.json]}) : null,
        type: countOp ? 'number' : token?.type,
        value: c,
        label: 'Value',
        onChanged: (x) => _patch({'value': UiWfOperand.constant(x).json}),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
      Row(spacing: 6, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(flex: 6, child: WfTokenSelect(tokens: tokens, value: rule.ref, label: 'Value to check', placeholder: 'Choose a value…', onChanged: _setRef)),
        Expanded(
          flex: 5,
          child: WfSelect(
            label: 'How to compare',
            enabled: rule.ref.isNotEmpty,
            value: rule.op,
            options: [for (final o in ops) (value: o.op.name, label: o.label)],
            onChanged: _setOp,
          ),
        ),
        FbIconButton(icon: WfIcons.delete02, label: 'Remove condition', danger: true, onPressed: onRemove),
      ]),
      if (arity > 0)
        Row(spacing: 6, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: valueInput()),
          if (!multi && !countOp)
            SizedBox(
              width: 132,
              child: WfSelect(
                label: 'Compare with',
                value: compareMode,
                options: [
                  (value: 'const', label: 'a value'),
                  (value: 'ref', label: 'another value'),
                  if (isDate) (value: 'today', label: 'today ±'),
                ],
                onChanged: (m) => _patch({'value': (m == 'ref' ? UiWfOperand.ref('') : m == 'today' ? UiWfOperand.today(0) : UiWfOperand.constant(null)).json}),
              ),
            ),
        ]),
      if (arity == 2)
        Row(spacing: 6, children: [
          Text('and', style: context.uiText.body.copyWith(fontSize: 12, color: t.textMuted)),
          Expanded(child: WfValueInput(type: token?.type, value: _constOf(rule.value2), label: 'Second value', onChanged: (x) => _patch({'value2': UiWfOperand.constant(x).json}))),
        ]),
    ]);
  }
}

/// `ui-wf-condition`: conditions as sentences ("[Amount] [is more than] [5,000]"), combined with
/// all / any / none, with one level of sub-groups. Saved as the form builder's condition JSON.
class WfConditionEditor extends StatelessWidget {
  const WfConditionEditor({super.key, required this.value, required this.tokens, required this.onChanged, this.nested = false, this.emptyText = 'Always (no conditions yet).'});
  final UiWfCondition? value;
  final List<UiWfToken> tokens;

  /// Always a group (`{match, conditions}`).
  final ValueChanged<UiWfCondition> onChanged;
  final bool nested;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final group = _asGroup(value);
    final conditions = group.conditions;
    void emit(List<UiWfCondition> cs, [String? match]) => onChanged(UiWfCondition.group(match ?? group.match, cs));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 8, children: [
      if (conditions.length > 1 || nested)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(
            width: 230,
            child: WfSelect(
              label: 'Combine conditions',
              value: group.match,
              options: const [(value: 'all', label: 'All of these are true'), (value: 'any', label: 'Any of these is true'), (value: 'none', label: 'None of these is true')],
              onChanged: (m) => emit(conditions, m),
            ),
          ),
        )
      else if (conditions.isEmpty)
        FbHint(emptyText),
      for (var i = 0; i < conditions.length; i++)
        if (conditions[i].isGroup)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: t.primary.withValues(alpha: 0.04),
              border: Border(left: BorderSide(color: t.primary.withValues(alpha: 0.4), width: 2)),
              borderRadius: BorderRadius.horizontal(right: Radius.circular(t.radiusXs)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 6, children: [
              WfConditionEditor(value: conditions[i], tokens: tokens, nested: true, onChanged: (c) => emit([...conditions]..[i] = c)),
              Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: 'Remove group', color: t.danger, onTap: () => emit([...conditions]..removeAt(i)))),
            ]),
          )
        else
          WfRuleEditor(rule: conditions[i], tokens: tokens, onChanged: (c) => emit([...conditions]..[i] = c), onRemove: () => emit([...conditions]..removeAt(i))),
      Wrap(spacing: t.space3, children: [
        FbLink(label: 'Add condition', icon: WfIcons.add01, onTap: () => emit([...conditions, UiWfCondition.fromJson({'ref': '', 'op': 'eq'})])),
        if (!nested)
          FbLink(
            label: 'Add a group',
            onTap: () => emit([...conditions, UiWfCondition.group('any', [UiWfCondition.fromJson({'ref': '', 'op': 'eq'})])]),
          ),
      ]),
    ]);
  }
}

// ── Embedded forms ──────────────────────────────────────────────────────────────────────────

/// Questions in a form definition (fields, inside sections too).
int wfFormQuestionCount(UiJson form) {
  var n = 0;
  void walk(Object? els) {
    for (final e in (els is List ? els : const [])) {
      final m = wfMap(e);
      if (m['kind'] == 'field') n++;
      if (m['kind'] == 'group') walk(m['elements']);
    }
  }

  for (final p in (form['pages'] is List ? form['pages'] as List : const [])) {
    walk(wfMap(p)['elements']);
  }
  return n;
}

/// `ui-wf-form-field`: a form to fill in (at a task, a transition or a manual start), built with
/// [UiFormBuilder] in a full-screen dialog.
class WfFormField extends StatelessWidget {
  const WfFormField({super.key, required this.value, required this.onChanged, this.title = 'Form', this.addLabel = 'Add a form'});
  final UiJson? value;

  /// Null removes the form.
  final ValueChanged<UiJson?> onChanged;
  final String title;
  final String addLabel;

  Future<void> _edit(BuildContext context) async {
    var draft = value != null ? migrateDefinition(value) : createDefinition(title: title);
    final saved = await showUiModal<bool>(
      context: context,
      title: title,
      size: UiModalSize.full,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.78,
        child: StatefulBuilder(builder: (ctx, setInner) => UiFormBuilder(definition: draft, onChanged: (d) => setInner(() => draft = d))),
      ),
      footerBuilder: (ctx) => Row(children: [
        UiButton(label: 'Cancel', variant: UiButtonVariant.ghost, onPressed: () => Navigator.of(ctx).pop(false)),
        const Spacer(),
        UiButton(label: 'Use this form', onPressed: () => Navigator.of(ctx).pop(true)),
      ]),
    );
    if (saved == true) onChanged(draft.toJson());
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final f = value;
    if (f == null) return Align(alignment: AlignmentDirectional.centerStart, child: FbLink(label: addLabel, onTap: () => _edit(context)));
    final n = wfFormQuestionCount(f);
    return Wrap(spacing: t.space3, crossAxisAlignment: WrapCrossAlignment.center, children: [
      Text('$n question${n == 1 ? '' : 's'}', style: context.uiText.body.copyWith(fontSize: 13, color: t.textSecondary)),
      FbLink(label: 'Edit form', onTap: () => _edit(context)),
      FbLink(label: 'Remove', color: t.danger, onTap: () => onChanged(null)),
    ]);
  }
}

/// Shows a stored value with its option label, for summaries.
String wfDisplayValue(UiWfFieldDescriptor? field, Object? value) =>
    value is List ? value.map((v) => wfOptionLabel(field, v)).join(', ') : wfOptionLabel(field, value);

