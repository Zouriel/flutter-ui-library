import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-code-block`: a monospace code panel with a language label and a Copy button. The code keeps
/// its line breaks and indentation and scrolls sideways instead of wrapping.
///
/// The button says "Copied" for a moment after copying, or "Copy failed" when the clipboard refused,
/// rather than claiming it worked; either is announced to screen readers.
class UiCodeBlock extends StatefulWidget {
  const UiCodeBlock({super.key, required this.code, this.language = 'text', this.radius = true});

  final String code;
  final String language;
  final bool radius;

  @override
  State<UiCodeBlock> createState() => _UiCodeBlockState();
}

enum _CopyState { idle, copied, failed }

class _UiCodeBlockState extends State<UiCodeBlock> {
  _CopyState _state = _CopyState.idle;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    _CopyState next;
    try {
      await Clipboard.setData(ClipboardData(text: widget.code));
      next = _CopyState.copied;
    } catch (_) {
      next = _CopyState.failed;
    }
    if (!mounted) return;
    setState(() => _state = next);
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _state = _CopyState.idle);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = widget.radius ? context.uiTheme.radius() : 0.0;
    final small = context.uiText.body.copyWith(fontSize: 12, height: 1.35);
    final label = switch (_state) { _CopyState.idle => 'Copy', _CopyState.copied => 'Copied', _CopyState.failed => 'Copy failed' };
    return Container(
      decoration: BoxDecoration(color: t.surface, border: Border.all(color: t.border), borderRadius: BorderRadius.circular(r)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r > 1 ? r - 1 : 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsetsDirectional.fromSTEB(t.space3, 2, t.space2, 2),
              decoration: BoxDecoration(color: t.surfaceRaised, border: Border(bottom: BorderSide(color: t.border))),
              child: Row(children: [
                Expanded(child: Text(widget.language.toUpperCase(), style: small.copyWith(color: t.textMuted, letterSpacing: 12 * 0.04))),
                UiInteractive(
                  onTap: _copy,
                  pressScale: false,
                  builder: (context, s) => Semantics(
                    liveRegion: true,
                    child: AnimatedContainer(
                      duration: context.uiAnimate ? t.motionFast : Duration.zero,
                      height: t.sizeSm,
                      padding: EdgeInsets.symmetric(horizontal: t.space2),
                      decoration: BoxDecoration(
                        color: s.hovered || s.pressed ? t.surfaceHover : null,
                        borderRadius: BorderRadius.circular(t.radiusXs),
                        boxShadow: s.focused ? t.focusRing : const [],
                      ),
                      child: Align(
                        widthFactor: 1,
                        child: Text(label, style: small.copyWith(color: _state == _CopyState.failed ? t.danger : (s.hovered ? t.text : t.textMuted))),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.all(t.space3),
              child: Text(widget.code.replaceAll('\t', '  '), softWrap: false, style: context.uiText.code.copyWith(fontSize: t.fontSizeSm, height: 1.5, color: t.text)),
            ),
          ],
        ),
      ),
    );
  }
}
