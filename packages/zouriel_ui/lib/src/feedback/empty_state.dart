import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-empty-state`: a centred placeholder for empty content: optional [art], an optional [icon], a
/// [heading], a [description], [actions] and [starters] (the web `[empty-art]` / `[empty-icon]` /
/// `[empty-actions]` / `[empty-starters]` slots).
class UiEmptyState extends StatelessWidget {
  const UiEmptyState({super.key, this.heading, this.description, this.icon, this.actions = const [], this.art, this.starters = const []});

  /// A picture of what will fill the page (0.75.0), above everything: at most 320 x 200, scaled
  /// down on narrow screens, keeping its shape.
  final Widget? art;

  /// Ways to start (0.75.0), usually [UiStarterCard]s: one column on a phone, then two or three
  /// across (each at least 200px wide, the grid at most 720px), centred.
  final List<Widget> starters;

  /// [UiStrings.emptyHeading] when null.
  final String? heading;
  final String? description;

  /// Usually a `UiIcon`; drawn at 32px in the muted colour.
  final Widget? icon;

  /// Buttons under the text, wrapping onto more lines when they don't fit.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final ty = context.uiText;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space6, horizontal: t.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (art != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320, maxHeight: 200),
                child: FittedBox(fit: BoxFit.contain, child: art),
              ),
            ),
          if (icon != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space2),
              child: IconTheme.merge(data: IconThemeData(size: 32, color: t.icon ?? t.textMuted), child: ExcludeSemantics(child: icon!)),
            ),
          Text(heading ?? context.uiStrings.emptyHeading, textAlign: TextAlign.center, style: ty.body.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
          if (description != null)
            Padding(
              padding: EdgeInsets.only(top: t.space2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(description!, textAlign: TextAlign.center, style: ty.caption.copyWith(height: 1.35)),
              ),
            ),
          if (actions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: t.space4),
              child: Wrap(alignment: WrapAlignment.center, spacing: t.space2, runSpacing: t.space2, children: actions),
            ),
          if (starters.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: t.space4),
              child: UiStarterGrid(children: starters),
            ),
        ],
      ),
    );
  }
}

/// The empty state's starters layout (the web `.starters` grid): columns of at least [minWidth]
/// with [UiTokens.space3] between them, as many as fit up to the number of children, at most
/// [maxWidth] wide; rows are as tall as their tallest card.
class UiStarterGrid extends StatelessWidget {
  const UiStarterGrid({super.key, required this.children, this.minWidth = 200, this.maxWidth = 720});

  final List<Widget> children;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gap = context.ui.space3;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : maxWidth;
        final fit = ((w + gap) / (minWidth + gap)).floor().clamp(1, 1 << 20);
        final cols = fit < children.length ? fit : children.length;
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final row = children.sublist(i, i + cols > children.length ? children.length : i + cols);
          rows.add(IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (var j = 0; j < cols; j++) ...[
                if (j > 0) SizedBox(width: gap),
                Expanded(child: j < row.length ? row[j] : const SizedBox.shrink()),
              ],
            ]),
          ));
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) SizedBox(height: gap), rows[i]],
          ],
        );
      }),
    );
  }
}
