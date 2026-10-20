import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-chat-bubble`: one message in a conversation. The person's own ([mine]) sit at the inline end
/// in the primary colour; the other side's at the inline start on the raised surface. Both follow
/// the text direction (in RTL, mine sit on the left). [meta] is a small line under the text: the
/// time, a read status. The corner nearest the speaker is tucked in.
///
/// Put bubbles in a Column (crossAxisAlignment stretch) and they align themselves; text wraps at
/// 80% of the width. [semanticLabel] names the message ("You, 09:41") when the text alone doesn't
/// say who sent it.
class UiChatBubble extends StatelessWidget {
  const UiChatBubble({super.key, required this.child, this.mine = false, this.meta, this.semanticLabel});

  /// The message, usually a Text.
  final Widget child;
  final bool mine;
  final String? meta;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final theme = context.uiTheme;
    final big = theme.radius(t.radiusLg), small = theme.radius(t.radiusXs);
    final fg = mine ? t.primaryContrast : t.text;
    final body = context.uiText.body.copyWith(color: fg, height: 1.45);
    final bubble = Container(
      padding: EdgeInsets.symmetric(horizontal: t.space3, vertical: t.space2),
      decoration: BoxDecoration(
        color: mine ? t.primary : t.surfaceRaised,
        border: mine ? null : Border.all(color: t.border),
        borderRadius: BorderRadiusDirectional.only(
          topStart: Radius.circular(big),
          topEnd: Radius.circular(big),
          bottomStart: Radius.circular(mine ? big : small),
          bottomEnd: Radius.circular(mine ? small : big),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        DefaultTextStyle.merge(style: body, child: child),
        if (meta != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              meta!,
              textAlign: TextAlign.end,
              style: body.copyWith(fontSize: 12, height: 1.35, color: mine ? t.primaryContrast.withValues(alpha: 0.8) : t.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
      ]),
    );
    return Semantics(
      container: true,
      label: semanticLabel,
      child: LayoutBuilder(
        builder: (context, box) => Align(
          alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth.isFinite ? box.maxWidth * 0.8 : double.infinity), child: IntrinsicWidth(child: bubble)),
        ),
      ),
    );
  }
}
