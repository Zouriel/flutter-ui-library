import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../core/interactive.dart';
import '../../theme/theme.dart';
import 'form_field.dart';
import 'text_core.dart';

/// The character an empty cell takes in the value when a later cell is filled.
const String uiOtpHole = ' ';

/// `ui-otp-input`: fixed-length one-time-code entry, one cell per character.
///
/// The value keeps every character in its cell's position: an empty cell before a filled one is a
/// space and empty cells at the end are dropped, so 1, 2, empty, 4 reads `"12 4"`, and writing
/// `"12 4"` back fills the same cells. Typing moves to the next cell; Backspace in an empty cell
/// and ArrowLeft/Right move between cells. Pasting or autofilling a whole code fills every cell
/// from the first. The first cell offers SMS one-time-code autofill.
///
/// Validation, as the web control does itself: use [UiOtpInput.validator] in a
/// [UiFormField.validated]. A value that isn't empty but has fewer than [length] filled cells is
/// incomplete; an empty value is valid unless the field is `required`.
class UiOtpInput extends StatefulWidget {
  const UiOtpInput({
    super.key,
    this.value,
    this.onChanged,
    this.length = 6,
    this.numeric = true,
    this.invalid = false,
    this.enabled = true,
    this.autofocus = false,
    this.semanticLabel = 'One-time code',
  });

  final String? value;
  final ValueChanged<String>? onChanged;
  final int length;

  /// Digits only (and the numeric keyboard).
  final bool numeric;
  final bool invalid;
  final bool enabled;
  final bool autofocus;

  /// Name of the group of cells.
  final String semanticLabel;

  /// How many cells of [value] are filled (holes and missing cells don't count).
  static int filledCount(String? value, int length) {
    final v = value ?? '';
    final cut = v.length > length ? v.substring(0, length) : v;
    return cut.split('').where((c) => c != uiOtpHole).length;
  }

  /// Whether [value] is started but not finished (the web `otpIncomplete` error).
  static bool isIncomplete(String? value, int length) => (value ?? '').isNotEmpty && filledCount(value, length) < length;

  /// A [FormFieldValidator] for the code: fails while the code is incomplete. [message] gets the
  /// filled count and the length.
  static FormFieldValidator<String> validator({int length = 6, String Function(int filled, int length)? message}) =>
      (v) => isIncomplete(v, length) ? (message ?? (f, l) => 'Enter all $l characters ($f of $l so far)')(filledCount(v, length), length) : null;

  @override
  State<UiOtpInput> createState() => _UiOtpInputState();
}

class _UiOtpInputState extends State<UiOtpInput> {
  late List<TextEditingController> _cells;
  late List<FocusNode> _nodes;
  List<String> _chars = [];
  String _emitted = '';
  UiFieldLink? _link;

  @override
  void initState() {
    super.initState();
    _build();
    _write(widget.value ?? '');
  }

  void _build() {
    _cells = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (i) => FocusNode(debugLabel: 'otp $i'));
    for (final n in _nodes) {
      n.addListener(_rebuild);
    }
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _disposeCells() {
    for (final c in _cells) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final link = UiFieldScope.maybeOf(context)?.link;
    if (link != _link) {
      _link?.detach(_nodes.first);
      _link = link;
      _link?.attach(_nodes.first);
    }
  }

  @override
  void didUpdateWidget(UiOtpInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.length != widget.length) {
      _link?.detach(_nodes.first);
      _disposeCells();
      _build();
      _link?.attach(_nodes.first);
      _write(widget.value ?? '');
    } else if ((widget.value ?? '') != _emitted) {
      _write(widget.value ?? '');
    }
  }

  @override
  void dispose() {
    _link?.detach(_nodes.first);
    _disposeCells();
    super.dispose();
  }

  void _write(String v) {
    final cut = v.length > widget.length ? v.substring(0, widget.length) : v;
    _chars = List.generate(widget.length, (i) => i < cut.length && cut[i] != uiOtpHole ? cut[i] : '');
    _emitted = v;
    for (var i = 0; i < widget.length; i++) {
      _setCell(i, _chars[i]);
    }
  }

  void _setCell(int i, String ch) {
    if (_cells[i].text != ch) {
      _cells[i].value = TextEditingValue(text: ch, selection: TextSelection.collapsed(offset: ch.length));
    }
  }

  String _sanitize(String raw) => widget.numeric ? raw.replaceAll(RegExp(r'\D'), '') : raw.replaceAll(RegExp(r'\s'), '');

  void _emit() {
    final v = List.generate(widget.length, (i) => _chars[i].isEmpty ? uiOtpHole : _chars[i]).join().trimRight();
    _emitted = v;
    widget.onChanged?.call(v);
    setState(() {});
  }

  void _focusCell(int i) {
    if (i < 0 || i >= widget.length) return;
    _nodes[i].requestFocus();
    final c = _cells[i];
    c.selection = TextSelection(baseOffset: 0, extentOffset: c.text.length);
  }

  /// A whole code (paste, autofill) fills from the first cell; anchoring it at the cell it landed
  /// in would silently drop the tail.
  void _fill(String code, int start) {
    for (var i = 0; i < code.length && start + i < widget.length; i++) {
      _chars[start + i] = code[i];
    }
    for (var i = 0; i < widget.length; i++) {
      _setCell(i, _chars[i]);
    }
    _emit();
    _focusCell((start + code.length).clamp(0, widget.length - 1));
  }

  void _onCellChanged(int i, String text) {
    final clean = _sanitize(text);
    // The old character may still be in the cell next to the new one: keep the new one. A longer
    // run of characters is a pasted or autofilled code.
    final old = _chars[i];
    if (clean.length > 2 || (clean.length == 2 && old.isEmpty)) {
      _fill(clean, 0);
      return;
    }
    String ch;
    if (clean.isEmpty) {
      ch = '';
    } else if (clean.length == 2 && clean.startsWith(old)) {
      ch = clean.substring(1);
    } else if (clean.length == 2 && clean.endsWith(old)) {
      ch = clean.substring(0, 1);
    } else {
      ch = clean.substring(clean.length - 1);
    }
    if (text.isNotEmpty && clean.isEmpty) {
      // A rejected character (a letter in a numeric code): put the cell back.
      _setCell(i, old);
      return;
    }
    _chars[i] = ch;
    _setCell(i, ch);
    _emit();
    if (ch.isNotEmpty) _focusCell(i + 1);
  }

  KeyEventResult _onKey(int i, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.backspace && _chars[i].isEmpty) {
      _focusCell(i - 1);
      return KeyEventResult.handled;
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (k == LogicalKeyboardKey.arrowLeft) {
      _focusCell(rtl ? i + 1 : i - 1);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight) {
      _focusCell(rtl ? i - 1 : i + 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final invalid = uiFieldInvalid(context, widget.invalid);
    final style = context.uiText.code.copyWith(fontSize: t.fontSizeLg, color: t.text, height: 1.2);
    final group = UiFieldScope.maybeOf(context)?.label ?? widget.semanticLabel;
    // The web cell is md wide and lg tall; on phones 48dp wide so each one is a full target. In a
    // narrow space the gaps close up first, then the cells shrink.
    final preferred = uiTouchPlatform(context) && t.sizeMd < uiMinTouchTarget ? uiMinTouchTarget : t.sizeMd;
    final n = widget.length;
    return LayoutBuilder(
      builder: (context, c) {
        var gap = t.space2;
        var cell = preferred;
        if (c.maxWidth.isFinite && cell * n + gap * (n - 1) > c.maxWidth) {
          gap = t.space1;
          cell = ((c.maxWidth - gap * (n - 1)) / n).floorToDouble().clamp(0.0, preferred);
        }
        return Semantics(
          container: true,
          label: group,
          explicitChildNodes: true,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              for (var i = 0; i < widget.length; i++)
                SizedBox(
                  width: cell,
                  child: UiFieldFrame(
                    height: t.sizeLg,
                    focused: _nodes[i].hasFocus,
                    invalid: invalid,
                    enabled: widget.enabled,
                    child: UiFieldScope(
                      // Each cell is named on its own, not by the field label (that names the group).
                      label: 'Digit ${i + 1}',
                      child: UiTextEditor(
                        controller: _cells[i],
                        focusNode: _nodes[i],
                        style: style,
                        textAlign: TextAlign.center,
                        enabled: widget.enabled,
                        keyboardType: widget.numeric ? TextInputType.number : TextInputType.text,
                        autofillHints: i == 0 ? const [AutofillHints.oneTimeCode] : null,
                        textInputAction: i == widget.length - 1 ? TextInputAction.done : TextInputAction.next,
                        onChanged: (s) => _onCellChanged(i, s),
                        onKeyEvent: (_, e) => _onKey(i, e),
                        selectAllOnFocus: true,
                        autofocus: widget.autofocus && i == 0,
                        semanticLabel: 'Digit ${i + 1}',
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
