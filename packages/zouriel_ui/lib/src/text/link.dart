import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// Link colours, the web `ui-link` `tone`.
enum UiLinkTone { primary, muted, plain }

/// `ui-link`: themed link text. Underlined at rest (subtly), so a link never relies on colour alone.
///
/// The library doesn't open URLs itself: [onTap] does (e.g. with `url_launcher`). [href] is reported
/// to accessibility services as the link's address. [external] adds an arrow marker and tells screen
/// reader users the link leaves the app.
class UiLink extends StatelessWidget {
  const UiLink(this.label, {super.key, this.onTap, this.href, this.external = false, this.tone = UiLinkTone.primary, this.style, this.focusNode});

  final String label;
  final VoidCallback? onTap;
  final String? href;
  final bool external;
  final UiLinkTone tone;

  /// Text style to start from (defaults to the surrounding text style).
  final TextStyle? style;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final base = style ?? DefaultTextStyle.of(context).style;
    return UiInteractive(
        onTap: onTap,
        focusNode: focusNode,
        button: false,
        pressScale: false,
        builder: (context, s) {
          final rest = switch (tone) { UiLinkTone.primary => t.primary, UiLinkTone.muted => t.textMuted, UiLinkTone.plain => base.color ?? t.text };
          final hover = switch (tone) { UiLinkTone.primary => t.primaryHover, UiLinkTone.muted => t.text, UiLinkTone.plain => rest };
          final c = s.hovered || s.pressed ? hover : rest;
          final text = Text(
            label,
            style: base.copyWith(
              color: c,
              decoration: TextDecoration.underline,
              decorationThickness: 1,
              decorationColor: s.hovered || s.pressed ? c : c.withValues(alpha: 0.35),
            ),
          );
          final fs = base.fontSize ?? t.fontSizeMd;
          // Inside the builder so UiInteractive's merged node carries the link flag and address.
          return Semantics(
            link: true,
            linkUrl: href == null ? null : Uri.tryParse(href!),
            label: external ? '$label (opens outside the app)' : label,
            child: ExcludeSemantics(child: AnimatedContainer(
            duration: t.motionFast,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : const []),
            child: external
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: text),
                    SizedBox(width: fs * 0.15),
                    UiIcon(HugeIcons.strokeRoundedArrowUpRight01, size: fs * 0.85, color: c, strokeWidth: 2),
                  ])
                : text,
          )));
        },
    );
  }
}
