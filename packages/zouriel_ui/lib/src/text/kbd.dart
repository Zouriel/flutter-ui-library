import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-kbd`: a keyboard key hint ("Ctrl", "K"). Sized from the surrounding text, in the mono font,
/// with a heavier bottom edge like a key cap.
class UiKbd extends StatelessWidget {
  const UiKbd(this.keyLabel, {super.key, this.semanticLabel});

  final String keyLabel;

  /// Spoken name when the visible text is a symbol (e.g. "Command" for the command key).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final em = DefaultTextStyle.of(context).style.fontSize ?? t.fontSizeMd;
    final style = context.uiText.code.copyWith(fontSize: em * 0.82, height: 1, color: t.text);
    return Semantics(
      label: semanticLabel ?? keyLabel,
      child: ExcludeSemantics(
        child: Container(
          constraints: BoxConstraints(minWidth: em * 1.4, minHeight: em * 1.5, maxHeight: em * 1.5),
          padding: EdgeInsets.symmetric(horizontal: em * 0.4),
          decoration: BoxDecoration(
            color: t.surfaceRaised,
            border: Border(
              top: BorderSide(color: t.border),
              left: BorderSide(color: t.border),
              right: BorderSide(color: t.border),
              bottom: BorderSide(color: t.border, width: 2),
            ),
            borderRadius: BorderRadius.circular(t.radiusXs),
          ),
          child: Align(widthFactor: 1, heightFactor: 1, child: Text(keyLabel, style: style, maxLines: 1)),
        ),
      ),
    );
  }
}
