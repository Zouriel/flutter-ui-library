import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/link_scope.dart';
import '../theme/theme.dart';

/// Link colours, the web `ui-link` `tone`.
enum UiLinkTone { primary, muted, plain }

/// `ui-link`: themed link text. Underlined at rest (subtly), so a link never relies on colour alone.
///
/// The library doesn't open URLs itself: [onTap] does (e.g. with `url_launcher`), or, with no [onTap],
/// the [UiLinkScope] above it is handed [href] (0.87.0). [href] is reported to accessibility services
/// as the link's address. [external] adds an arrow marker and tells screen reader users the link
/// leaves the app.
///
/// [current] (0.87.0) marks the page that is open (the web `aria-current="page"`): the text colour,
/// semibold, a solid underline, and selected semantics. Null asks [UiLinkScope.isCurrent] (never for
/// an [external] link).
class UiLink extends StatelessWidget {
  const UiLink(this.label, {super.key, this.onTap, this.href, this.external = false, this.tone = UiLinkTone.primary, this.style, this.focusNode, this.current});

  final String label;
  final VoidCallback? onTap;
  final String? href;
  final bool external;
  final UiLinkTone tone;

  /// Text style to start from (defaults to the surrounding text style).
  final TextStyle? style;
  final FocusNode? focusNode;

  /// The page that is open; null asks [UiLinkScope.isCurrent].
  final bool? current;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final base = style ?? DefaultTextStyle.of(context).style;
    final scope = UiLinkScope.maybeOf(context);
    final href = this.href;
    final isCurrent = current ?? (href != null && !external && (scope?.current(href) ?? false));
    return UiInteractive(
        // With no handler of its own, an href goes through the scope (nothing happens without one).
        onTap: onTap ?? (href == null ? null : () => scope?.navigate(href)),
        focusNode: focusNode,
        button: false,
        selected: isCurrent ? true : null,
        pressScale: false,
        builder: (context, s) {
          final rest = switch (tone) { UiLinkTone.primary => t.primary, UiLinkTone.muted => t.textMuted, UiLinkTone.plain => base.color ?? t.text };
          final hover = switch (tone) { UiLinkTone.primary => t.primaryHover, UiLinkTone.muted => t.text, UiLinkTone.plain => rest };
          final c = isCurrent ? t.text : s.hovered || s.pressed ? hover : rest;
          final text = Text(
            label,
            style: base.copyWith(
              color: c,
              fontWeight: isCurrent ? FontWeight.w600 : null,
              decoration: TextDecoration.underline,
              decorationThickness: isCurrent ? 2 : 1,
              decorationColor: isCurrent || s.hovered || s.pressed ? c : c.withValues(alpha: 0.35),
            ),
          );
          final fs = base.fontSize ?? t.fontSizeMd;
          // Inside the builder so UiInteractive's merged node carries the link flag and address.
          return Semantics(
            link: true,
            linkUrl: href == null ? null : Uri.tryParse(href),
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
