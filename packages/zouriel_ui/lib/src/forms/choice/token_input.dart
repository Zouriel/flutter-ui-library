import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../theme/theme.dart';
import 'bare_input.dart';

/// One run of a [UiTokenInput] value: literal [text], or an atomic [token] (a variable, a mention).
@immutable
class UiTokenRun {
  const UiTokenRun({this.text, this.token, this.bold = false, this.italic = false}) : assert((text == null) != (token == null), 'A run is text or a token.');
  const UiTokenRun.text(String this.text, {this.bold = false, this.italic = false}) : token = null;
  const UiTokenRun.token(String this.token, {this.bold = false, this.italic = false}) : text = null;

  final String? text;

  /// The token's machine value, e.g. `event.date`.
  final String? token;
  final bool bold;
  final bool italic;

  bool get isToken => token != null;

  /// The web's JSON shape: `{text}` or `{token}`, with `bold` / `italic` only when set.
  Map<String, Object> toJson() => {
        'text': ?text,
        'token': ?token,
        if (bold) 'bold': true,
        if (italic) 'italic': true,
      };

  factory UiTokenRun.fromJson(Map<String, Object?> j) =>
      UiTokenRun(text: j['token'] == null ? (j['text'] as String? ?? '') : null, token: j['token'] as String?, bold: j['bold'] == true, italic: j['italic'] == true);

  @override
  bool operator ==(Object other) => other is UiTokenRun && other.text == text && other.token == token && other.bold == bold && other.italic == italic;
  @override
  int get hashCode => Object.hash(text, token, bold, italic);
  @override
  String toString() => 'UiTokenRun(${toJson()})';
}

/// Merges adjacent text runs with the same marks and drops empty ones (the web `normalizeRuns`).
List<UiTokenRun> uiNormalizeRuns(List<UiTokenRun> runs) {
  final out = <UiTokenRun>[];
  for (final run in runs) {
    if (run.isToken) {
      out.add(run);
      continue;
    }
    if (run.text == null || run.text!.isEmpty) continue;
    final prev = out.isEmpty ? null : out.last;
    if (prev != null && !prev.isToken && prev.bold == run.bold && prev.italic == run.italic) {
      out[out.length - 1] = UiTokenRun.text(prev.text! + run.text!, bold: run.bold, italic: run.italic);
    } else {
      out.add(run);
    }
  }
  return out;
}

/// The character a token stands on in the text: one character, so the caret steps over a chip and
/// one Backspace removes it.
const String _obj = '￼';

@immutable
class _Mark {
  const _Mark({this.bold = false, this.italic = false, this.token});
  final bool bold, italic;
  final String? token;
  _Mark copyWith({bool? bold, bool? italic}) => _Mark(bold: bold ?? this.bold, italic: italic ?? this.italic, token: token);
}

/// Text plus a mark per character; renders tokens as chips.
class _TokenController extends TextEditingController {
  _TokenController({required this.chip});

  Widget Function(String token, TextStyle style) chip;
  List<_Mark> marks = [];

  /// The style for the next typed characters when the caret has no selection (Ctrl+B with nothing
  /// selected), or null to follow the character before the caret.
  _Mark? pending;

  bool _silent = false;

  void load(List<UiTokenRun> runs) {
    final b = StringBuffer();
    final m = <_Mark>[];
    for (final r in runs) {
      if (r.isToken) {
        b.write(_obj);
        m.add(_Mark(bold: r.bold, italic: r.italic, token: r.token));
      } else {
        b.write(r.text);
        m.addAll(List.filled(r.text!.length, _Mark(bold: r.bold, italic: r.italic)));
      }
    }
    _silent = true;
    marks = m;
    final text = b.toString();
    value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    _silent = false;
  }

  List<UiTokenRun> get runs {
    final out = <UiTokenRun>[];
    for (var i = 0; i < text.length && i < marks.length; i++) {
      final m = marks[i];
      out.add(m.token != null ? UiTokenRun.token(m.token!, bold: m.bold, italic: m.italic) : UiTokenRun.text(text[i], bold: m.bold, italic: m.italic));
    }
    return uiNormalizeRuns(out);
  }

  @override
  set value(TextEditingValue next) {
    if (!_silent) {
      final old = text, now = next.text;
      if (old != now) {
        var p = 0;
        while (p < old.length && p < now.length && old.codeUnitAt(p) == now.codeUnitAt(p)) {
          p++;
        }
        var s = 0;
        while (s < old.length - p && s < now.length - p && old.codeUnitAt(old.length - 1 - s) == now.codeUnitAt(now.length - 1 - s)) {
          s++;
        }
        final style = pending ?? (p > 0 && p - 1 < marks.length ? _Mark(bold: marks[p - 1].bold, italic: marks[p - 1].italic) : const _Mark());
        final inserted = now.length - s - p;
        marks = [
          ...marks.take(p),
          for (var i = 0; i < inserted; i++) style,
          ...marks.skip(old.length - s),
        ];
        if (inserted > 0) pending = null;
      } else if (next.selection != selection) {
        pending = null;
      }
    }
    super.value = next;
  }

  /// Bold or italic over the selection; with no selection, for what's typed next.
  void toggle({bool bold = false}) {
    final sel = selection;
    if (!sel.isValid) return;
    bool get(_Mark m) => bold ? m.bold : m.italic;
    if (sel.isCollapsed) {
      final base = pending ?? (sel.start > 0 && sel.start - 1 < marks.length ? marks[sel.start - 1] : const _Mark());
      pending = bold ? _Mark(bold: !base.bold, italic: base.italic) : _Mark(bold: base.bold, italic: !base.italic);
      notifyListeners();
      return;
    }
    final range = marks.sublist(sel.start, sel.end);
    final on = !range.every(get);
    marks = [
      for (var i = 0; i < marks.length; i++)
        if (i >= sel.start && i < sel.end) (bold ? marks[i].copyWith(bold: on) : marks[i].copyWith(italic: on)) else marks[i],
    ];
    notifyListeners();
  }

  void insertToken(String token) {
    final sel = selection.isValid ? selection : TextSelection.collapsed(offset: text.length);
    final start = sel.start, end = sel.end;
    final m = pending ?? (start > 0 && start - 1 < marks.length ? marks[start - 1] : const _Mark());
    _silent = true;
    marks = [...marks.take(start), _Mark(bold: m.bold, italic: m.italic, token: token), ...marks.skip(end)];
    value = TextEditingValue(text: text.replaceRange(start, end, _obj), selection: TextSelection.collapsed(offset: start + 1));
    _silent = false;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final base = style ?? const TextStyle();
    final children = <InlineSpan>[];
    var i = 0;
    while (i < text.length) {
      final m = i < marks.length ? marks[i] : const _Mark();
      final st = base.copyWith(fontWeight: m.bold ? FontWeight.w700 : null, fontStyle: m.italic ? FontStyle.italic : null);
      if (m.token != null) {
        children.add(WidgetSpan(alignment: PlaceholderAlignment.middle, style: st, child: chip(m.token!, st)));
        i++;
        continue;
      }
      var j = i + 1;
      while (j < text.length && j < marks.length && marks[j].token == null && marks[j].bold == m.bold && marks[j].italic == m.italic) {
        j++;
      }
      children.add(TextSpan(text: text.substring(i, j), style: st));
      i = j;
    }
    return TextSpan(style: base, children: children);
  }
}

class _PasteIntent extends Intent {
  const _PasteIntent();
}

class _ToggleIntent extends Intent {
  const _ToggleIntent(this.bold);
  final bool bold;
}

/// `ui-token-input`: rich text where some pieces are atomic tokens (variables, mentions) shown as
/// chips. The value is a list of [UiTokenRun]s. A chip acts like one character: the caret steps over
/// it and one Backspace removes it. Ctrl/Cmd+B and Ctrl/Cmd+I toggle bold and italic; pasting always
/// inserts plain text (newlines become spaces when not [multiline]).
///
/// Insert a token at the caret with [UiTokenInputState.insertToken] (through a
/// `GlobalKey<UiTokenInputState>`), or at the end when the field has never had the caret.
/// [tokenLabel] turns a token value into its chip text. Null [onChanged] disables it.
class UiTokenInput extends StatefulWidget {
  const UiTokenInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '',
    this.label = '',
    this.multiline = true,
    this.minHeight,
    this.radius,
    this.tokenLabel,
    this.onFocusChange,
    this.onTokenTap,
    this.focusNode,
  });

  final List<UiTokenRun> value;
  final ValueChanged<List<UiTokenRun>>? onChanged;
  final String placeholder;

  /// Accessible name.
  final String label;
  final bool multiline;

  /// Minimum height of a multiline field.
  final double? minHeight;
  final bool? radius;

  /// Chip text for a token value; defaults to the value itself.
  final String Function(String token)? tokenLabel;
  final ValueChanged<bool>? onFocusChange;

  /// A chip was tapped.
  final ValueChanged<String>? onTokenTap;
  final FocusNode? focusNode;

  @override
  State<UiTokenInput> createState() => UiTokenInputState();
}

class UiTokenInputState extends State<UiTokenInput> {
  late final _TokenController _ctrl = _TokenController(chip: _chip);
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode(debugLabel: 'token input'));
  List<UiTokenRun> _last = const [];
  bool _hadCaret = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void initState() {
    super.initState();
    _last = uiNormalizeRuns(widget.value);
    _ctrl.load(_last);
    _ctrl.addListener(_report);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiTokenInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ctrl.chip = _chip;
    final next = uiNormalizeRuns(widget.value);
    if (!listEquals(next, _last)) {
      _last = next;
      _ctrl.load(next);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _ctrl.dispose();
    _ownFocus?.dispose();
    super.dispose();
  }

  void _onFocus() {
    if (_focus.hasFocus) _hadCaret = true;
    widget.onFocusChange?.call(_focus.hasFocus);
    setState(() {});
  }

  void _report() {
    final runs = _ctrl.runs;
    if (listEquals(runs, _last)) return;
    _last = runs;
    widget.onChanged?.call(runs);
  }

  /// Inserts a token at the caret, replacing any selection; at the end when the field has never had
  /// the caret.
  void insertToken(String token) {
    if (!_enabled) return;
    if (!_hadCaret) _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    _ctrl.insertToken(token);
  }

  Future<void> _pasteSingleLine() async {
    if (!_enabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.isEmpty || !mounted) return;
    final text = raw.replaceAll(RegExp(r'\s*\n\s*'), ' ').replaceAll(_obj, '');
    final sel = _ctrl.selection.isValid ? _ctrl.selection : TextSelection.collapsed(offset: _ctrl.text.length);
    _ctrl.value = TextEditingValue(
      text: _ctrl.text.replaceRange(sel.start, sel.end, text),
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  /// Focuses the field with the caret at the end.
  void focus() {
    _focus.requestFocus();
    _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
  }

  Widget _chip(String token, TextStyle style) {
    final t = context.ui;
    final size = (style.fontSize ?? t.fontSizeMd) * 0.86;
    return Semantics(
      label: (widget.tokenLabel ?? (s) => s)(token),
      child: GestureDetector(
        onTap: widget.onTokenTap == null ? null : () => widget.onTokenTap!(token),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: uiMix(t.primary, 0.18, t.surface),
            border: Border.all(color: t.primary.withValues(alpha: 0.45)),
            borderRadius: BorderRadius.circular(t.radiusPill),
          ),
          child: Text((widget.tokenLabel ?? (s) => s)(token), maxLines: 1, style: style.copyWith(fontSize: size, height: 1.55, color: t.text)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final r = (widget.radius ?? theme.config.radius) ? t.radius : 0.0;
    final focused = _focus.hasFocus;
    final touch = uiTouchPlatform(context);
    final style = context.uiText.body.copyWith(fontSize: t.fontSizeMd, height: 1.6, color: t.text);
    final field = UiBareInput(
      controller: _ctrl,
      focusNode: _focus,
      enabled: _enabled,
      style: style,
      placeholder: widget.placeholder.isEmpty ? null : widget.placeholder,
      semanticLabel: widget.label.isEmpty ? null : widget.label,
      maxLines: widget.multiline ? null : 1,
      keyboardType: widget.multiline ? TextInputType.multiline : TextInputType.text,
      textInputAction: widget.multiline ? TextInputAction.newline : TextInputAction.done,
      inputFormatters: [_PlainPaste(multiline: widget.multiline)],
    );
    final single = !widget.multiline;
    return Actions(
      actions: {
        _ToggleIntent: CallbackAction<_ToggleIntent>(onInvoke: (i) {
          if (_enabled) _ctrl.toggle(bold: i.bold);
          return null;
        }),
        _PasteIntent: CallbackAction<_PasteIntent>(onInvoke: (_) {
          _pasteSingleLine();
          return null;
        }),
      },
      child: Shortcuts(
        shortcuts: {
          // A single-line EditableText drops pasted newlines before any formatter sees them, gluing
          // "one\ntwo" into "onetwo"; paste here instead so line breaks become spaces, as on the web.
          if (single) ...const {
            SingleActivator(LogicalKeyboardKey.keyV, control: true): _PasteIntent(),
            SingleActivator(LogicalKeyboardKey.keyV, meta: true): _PasteIntent(),
          },
          const SingleActivator(LogicalKeyboardKey.keyB, control: true): const _ToggleIntent(true),
          const SingleActivator(LogicalKeyboardKey.keyB, meta: true): const _ToggleIntent(true),
          const SingleActivator(LogicalKeyboardKey.keyI, control: true): const _ToggleIntent(false),
          const SingleActivator(LogicalKeyboardKey.keyI, meta: true): const _ToggleIntent(false),
        },
        child: AnimatedOpacity(
          opacity: _enabled ? 1 : 0.5,
          duration: t.motionBase,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? _focus.requestFocus : null,
            child: AnimatedContainer(
              duration: context.uiAnimate ? t.motionBase : Duration.zero,
              constraints: BoxConstraints(minHeight: single ? (touch ? uiMinTouchTarget : t.sizeMd) : math.max(widget.minHeight ?? 0, touch ? uiMinTouchTarget : 0)),
              height: single ? (touch ? uiMinTouchTarget : t.sizeMd) : null,
              padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: single ? 0 : t.space2),
              alignment: single ? AlignmentDirectional.centerStart : AlignmentDirectional.topStart,
              decoration: BoxDecoration(
                color: t.surface,
                border: Border.all(color: focused ? t.primary : t.controlBorder),
                borderRadius: BorderRadius.circular(r),
                boxShadow: focused ? t.focusRing : const [],
              ),
              child: field,
            ),
          ),
        ),
      ),
    );
  }
}

/// Typed and pasted text stays plain: no object characters (only [UiTokenInputState.insertToken]
/// makes chips), and no newlines in a single-line field.
class _PlainPaste extends TextInputFormatter {
  _PlainPaste({required this.multiline});
  final bool multiline;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Only look at what was inserted; the existing chips' characters must survive.
    final o = oldValue.text, n = newValue.text;
    var p = 0;
    while (p < o.length && p < n.length && o.codeUnitAt(p) == n.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < o.length - p && s < n.length - p && o.codeUnitAt(o.length - 1 - s) == n.codeUnitAt(n.length - 1 - s)) {
      s++;
    }
    final inserted = n.substring(p, n.length - s);
    var clean = inserted.replaceAll(_obj, '');
    if (!multiline) clean = clean.replaceAll(RegExp(r'\s*\n\s*'), ' ');
    if (clean == inserted) return newValue;
    final text = n.substring(0, p) + clean + n.substring(n.length - s);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: p + clean.length));
  }
}
