import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `ui-empty-state`: a centred placeholder for empty content: an optional [icon], a [heading], a
/// [description] and [actions] (the web `[empty-icon]` / `[empty-actions]` slots).
class UiEmptyState extends StatelessWidget {
  const UiEmptyState({super.key, this.heading = 'Nothing here yet', this.description, this.icon, this.actions = const []});

  final String heading;
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
          if (icon != null)
            Padding(
              padding: EdgeInsets.only(bottom: t.space2),
              child: IconTheme.merge(data: IconThemeData(size: 32, color: t.textMuted), child: ExcludeSemantics(child: icon!)),
            ),
          Text(heading, textAlign: TextAlign.center, style: ty.body.copyWith(fontWeight: FontWeight.w600, height: 1.35)),
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
        ],
      ),
    );
  }
}
