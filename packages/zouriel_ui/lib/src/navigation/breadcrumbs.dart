import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../theme/theme.dart';

/// One step of a [UiBreadcrumbs] trail.
@immutable
class UiBreadcrumb {
  const UiBreadcrumb({required this.label, this.value});
  final String label;
  final String? value;
}

/// `ui-breadcrumbs`: the trail to the current page. Every crumb but the last is a link that reports
/// itself through [onNavigate]; the last is the current page (announced as selected, the web
/// `aria-current="page"`). Crumbs are at least 24px tall and wide, and padded to 48dp on touch screens.
///
/// When the whole trail doesn't fit on one line, the middle collapses into a "more" button that shows
/// the full path when tapped (the first crumb and the last two stay). Long labels are cut with an
/// ellipsis.
class UiBreadcrumbs extends StatefulWidget {
  const UiBreadcrumbs({super.key, required this.items, this.onNavigate, this.separator = '/', this.label = 'Breadcrumb', this.collapse = true});

  final List<UiBreadcrumb> items;
  final ValueChanged<UiBreadcrumb>? onNavigate;
  final String separator;
  final String label;

  /// Collapse the middle crumbs when the trail is wider than its space.
  final bool collapse;

  @override
  State<UiBreadcrumbs> createState() => _UiBreadcrumbsState();
}

class _UiBreadcrumbsState extends State<UiBreadcrumbs> {
  bool _expanded = false;

  /// Widest a crumb gets before its label is cut (the web `max-width: 24ch`).
  static const double _maxCrumb = 180;

  @override
  void didUpdateWidget(UiBreadcrumbs old) {
    super.didUpdateWidget(old);
    if (old.items.length != widget.items.length) _expanded = false;
  }

  TextStyle _style(BuildContext context) {
    final t = context.ui;
    return context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 24 / t.fontSizeSm, color: t.textMuted);
  }

  double _measure(BuildContext context, List<UiBreadcrumb> items, {bool withMore = false}) {
    final t = context.ui;
    final style = _style(context);
    final touch = uiTouchPlatform(context);
    final scale = MediaQuery.textScalerOf(context);
    double w(String s, {double max = double.infinity}) {
      final p = TextPainter(text: TextSpan(text: s, style: style), textDirection: TextDirection.ltr, textScaler: scale, maxLines: 1)..layout();
      final width = p.width;
      p.dispose();
      return width.clamp(0, max).toDouble();
    }

    final minHit = touch ? uiMinTouchTarget : 24.0;
    final pad = touch ? t.space2 * 2 : 0.0;
    final sep = w(widget.separator);
    var total = 0.0;
    final count = items.length + (withMore ? 1 : 0);
    for (final c in items) {
      total += (w(c.label, max: _maxCrumb) + pad).clamp(minHit, double.infinity);
    }
    if (withMore) total += minHit;
    // Each gap is the separator, with a space either side when the crumbs have no padding.
    total += (count - 1) * (sep + (touch ? 0 : t.space1 * 2));
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final items = widget.items;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.navigation,
      label: widget.label,
      child: LayoutBuilder(builder: (context, box) {
        var shown = <UiBreadcrumb?>[...items]; // null = the "more" button
        if (widget.collapse && !_expanded && items.length > 3 && box.maxWidth.isFinite && _measure(context, items) > box.maxWidth) {
          final tailTwo = [items.first, ...items.sublist(items.length - 2)];
          shown = _measure(context, tailTwo, withMore: true) <= box.maxWidth || items.length == 3
              ? [items.first, null, ...items.sublist(items.length - 2)]
              : [items.first, null, items.last];
        }
        final touch = uiTouchPlatform(context);
        final children = <Widget>[];
        for (var i = 0; i < shown.length; i++) {
          final crumb = shown[i];
          final last = i == shown.length - 1;
          children.add(Row(mainAxisSize: MainAxisSize.min, spacing: touch ? 0 : t.space1, children: [
            if (crumb == null)
              _MoreCrumb(hidden: items.length - shown.length + 1, onTap: () => setState(() => _expanded = true))
            else if (last)
              _Crumb(label: crumb.label, current: true, style: _style(context))
            else
              _Crumb(label: crumb.label, style: _style(context), onTap: () => widget.onNavigate?.call(crumb)),
            if (!last) ExcludeSemantics(child: Text(widget.separator, style: _style(context))),
          ]));
        }
        return Wrap(spacing: touch ? 0 : t.space1, crossAxisAlignment: WrapCrossAlignment.center, children: children);
      }),
    );
  }
}

class _Crumb extends StatelessWidget {
  const _Crumb({required this.label, required this.style, this.onTap, this.current = false});
  final String label;
  final TextStyle style;
  final VoidCallback? onTap;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    // On touch the crumbs carry an even horizontal padding, so the 48dp targets don't leave uneven
    // gaps around the separators.
    final pad = uiTouchPlatform(context) ? t.space2 : 0.0;
    Widget text(Color c, {bool underline = false, FontWeight? weight}) => Container(
          constraints: BoxConstraints(minWidth: 24, maxWidth: _UiBreadcrumbsState._maxCrumb + pad * 2),
          padding: EdgeInsets.symmetric(horizontal: pad),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style.copyWith(color: c, fontWeight: weight, decoration: underline ? TextDecoration.underline : null, decorationColor: c),
          ),
        );
    if (current) {
      return Semantics(selected: true, child: text(t.text, weight: FontWeight.w500));
    }
    return UiInteractive(
      onTap: onTap,
      button: false,
      pressScale: false,
      builder: (context, s) => Semantics(
        link: true,
        child: DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(t.radiusXs), boxShadow: s.focused ? t.focusRing : const []),
          child: text(s.hovered || s.pressed ? t.text : t.textMuted, underline: s.hovered || s.pressed),
        ),
      ),
    );
  }
}

class _MoreCrumb extends StatelessWidget {
  const _MoreCrumb({required this.hidden, required this.onTap});
  final int hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Show $hidden more',
      excludeChildSemantics: true,
      pressScale: false,
      builder: (context, s) => AnimatedContainer(
        duration: t.motionFast,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: s.hovered || s.pressed ? t.surfaceHover : null,
          borderRadius: BorderRadius.circular(t.radiusXs),
          boxShadow: s.focused ? t.focusRing : const [],
        ),
        child: Center(child: UiIcon(HugeIcons.strokeRoundedMoreHorizontal, size: 16, color: s.hovered ? t.text : t.textMuted)),
      ),
    );
  }
}
