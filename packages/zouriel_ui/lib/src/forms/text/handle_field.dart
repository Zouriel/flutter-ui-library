import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../badge/badge.dart';
import '../../core/icon.dart';
import '../../core/interactive.dart';
import '../../core/types.dart';
import '../../feedback/spinner.dart';
import '../../theme/theme.dart';
import 'inputs.dart';

/// Where a [UiHandleField]'s check stands (the web `UiHandleCheck['state']`).
enum UiHandleState { idle, checking, available, taken, invalid }

/// The answer to a handle check (the web `UiHandleCheck`).
class UiHandleCheck {
  const UiHandleCheck(this.state, {this.message, this.suggestion});
  final UiHandleState state;

  /// Replaces the field's own wording ("@x is free", "@x is taken").
  final String? message;

  /// A free handle to offer instead, shown as a "Use @x" chip.
  final String? suggestion;

  @override
  bool operator ==(Object other) => other is UiHandleCheck && other.state == state && other.message == message && other.suggestion == suggestion;
  @override
  int get hashCode => Object.hash(state, message, suggestion);
}

/// Lowercases what is typed or pasted and drops anything but a-z, 0-9, dot and underscore.
class UiHandleFormatter extends TextInputFormatter {
  const UiHandleFormatter(this.maxLength);
  final int maxLength;

  static String clean(String s, int maxLength) {
    final kept = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9._]'), '');
    return kept.length > maxLength ? kept.substring(0, maxLength) : kept;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = clean(newValue.text, maxLength);
    if (text == newValue.text) return newValue;
    // Keep the caret where it was, less what was dropped before it.
    final before = clean(newValue.text.substring(0, newValue.selection.baseOffset.clamp(0, newValue.text.length)), maxLength);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: before.length.clamp(0, text.length)));
  }
}

/// `ui-handle-field`: a field for an `@handle` (a public link name) that checks as you type
/// whether it is free.
///
/// What's typed is lowercased and keeps only a-z, 0-9, `.` and `_`, up to [maxLength]. After
/// [debounce] without typing, [check] is asked (not when shorter than [minLength]); an answer for an
/// older value never replaces a newer one. The line under the field says where it stands with an
/// icon, and a suggestion (from the answer, or [suggestion] while the field is empty) shows as a
/// "Use @x" chip that fills it in.
class UiHandleField extends StatefulWidget {
  const UiHandleField({
    super.key,
    required this.value,
    required this.onChanged,
    required this.check,
    this.label = 'Your link name',
    this.prefix = '@',
    this.debounce = const Duration(milliseconds: 400),
    this.minLength = 3,
    this.maxLength = 30,
    this.suggestion,
    this.hint,
    this.onStatus,
    this.enabled = true,
    this.autofocus = false,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final Future<UiHandleCheck> Function(String handle) check;
  final String label;
  final String prefix;
  final Duration debounce;
  final int minLength, maxLength;

  /// Offered while the field is empty (e.g. made from the person's name).
  final String? suggestion;

  /// Shown under the field before anything is checked (e.g. "invites.blog/@yourname").
  final String? hint;
  final ValueChanged<UiHandleCheck>? onStatus;
  final bool enabled;
  final bool autofocus;

  @override
  State<UiHandleField> createState() => _UiHandleFieldState();
}

class _UiHandleFieldState extends State<UiHandleField> {
  late final _controller = TextEditingController(text: UiHandleFormatter.clean(widget.value, widget.maxLength));
  Timer? _timer;
  int _asked = 0;
  UiHandleCheck _status = const UiHandleCheck(UiHandleState.idle);

  @override
  void initState() {
    super.initState();
    if (_controller.text.isNotEmpty) _schedule(_controller.text, now: true);
  }

  @override
  void didUpdateWidget(UiHandleField old) {
    super.didUpdateWidget(old);
    final v = UiHandleFormatter.clean(widget.value, widget.maxLength);
    if (v != _controller.text) {
      _controller.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
      _schedule(v);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _set(UiHandleCheck s) {
    if (!mounted || s == _status) return;
    setState(() => _status = s);
    widget.onStatus?.call(s);
  }

  void _schedule(String v, {bool now = false}) {
    _timer?.cancel();
    final ask = ++_asked;
    if (v.isEmpty) return _set(const UiHandleCheck(UiHandleState.idle));
    if (v.length < widget.minLength) {
      return _set(UiHandleCheck(UiHandleState.invalid, message: 'At least ${widget.minLength} letters or numbers'));
    }
    _set(const UiHandleCheck(UiHandleState.checking));
    void run() {
      widget.check(v).then((r) {
        if (ask == _asked) _set(r);
      }, onError: (Object _) {
        if (ask == _asked) _set(const UiHandleCheck(UiHandleState.invalid, message: "Couldn't check. Try again."));
      });
    }

    now ? run() : _timer = Timer(widget.debounce, run);
  }

  void _changed(String v) {
    widget.onChanged(v);
    _schedule(v);
  }

  void _use(String s) {
    final v = UiHandleFormatter.clean(s, widget.maxLength);
    _controller.value = TextEditingValue(text: v, selection: TextSelection.collapsed(offset: v.length));
    widget.onChanged(v);
    _schedule(v, now: true);
  }

  String get _shown => '${widget.prefix}${_controller.text}';

  Widget _line(BuildContext context) {
    final t = context.ui;
    final caption = context.uiText.caption;
    Widget row(Widget icon, String text, Color color) => Row(children: [
          IconTheme.merge(data: IconThemeData(size: 16, color: color), child: icon),
          SizedBox(width: t.space1),
          Expanded(child: Text(text, style: caption.copyWith(color: color))),
        ]);
    return switch (_status.state) {
      UiHandleState.idle => widget.hint == null ? const SizedBox.shrink() : Text(widget.hint!, style: caption.copyWith(color: t.textMuted)),
      UiHandleState.checking => row(const UiSpinner(size: 14), 'Checking…', t.textMuted),
      UiHandleState.available => row(const UiIcon(HugeIcons.strokeRoundedCheckmarkCircle02), _status.message ?? '$_shown is free', t.success),
      UiHandleState.taken => row(const UiIcon(HugeIcons.strokeRoundedCancelCircle), _status.message ?? '$_shown is taken', t.danger),
      UiHandleState.invalid => row(const UiIcon(HugeIcons.strokeRoundedAlert02), _status.message ?? 'Use letters, numbers, dots or underscores', t.danger),
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final offer = _status.suggestion ?? (_controller.text.isEmpty ? widget.suggestion : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Text(widget.label, style: context.uiText.label),
      SizedBox(height: t.space1),
      UiInput(
        controller: _controller,
        onChanged: _changed,
        semanticLabel: widget.label,
        enabled: widget.enabled,
        autofocus: widget.autofocus,
        keyboardType: TextInputType.visiblePassword, // no autocorrect or capitals on Android keyboards
        inputFormatters: [UiHandleFormatter(widget.maxLength)],
        invalid: _status.state == UiHandleState.taken || _status.state == UiHandleState.invalid,
        leading: Padding(
          padding: EdgeInsetsDirectional.only(start: t.space2),
          child: Text(widget.prefix, style: context.uiText.body.copyWith(color: t.textMuted, fontWeight: FontWeight.w600)),
        ),
      ),
      SizedBox(height: t.space1),
      Semantics(liveRegion: true, child: _line(context)),
      if (offer != null && offer.isNotEmpty && offer != _controller.text) ...[
        SizedBox(height: t.space1),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: UiInteractive(
            semanticLabel: 'Use ${widget.prefix}$offer',
            onTap: widget.enabled ? () => _use(offer) : null,
            builder: (context, s) => DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusPill),
                boxShadow: s.focused ? t.focusRing : null,
              ),
              child: ExcludeSemantics(child: UiChip(label: 'Use ${widget.prefix}$offer', leading: const UiIcon(HugeIcons.strokeRoundedMagicWand01), tone: UiStatus.primary)),
            ),
          ),
        ),
      ],
    ]);
  }
}
