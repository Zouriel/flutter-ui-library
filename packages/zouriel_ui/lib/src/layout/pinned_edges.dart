import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../behaviors/scrolling.dart';
import '../theme/theme.dart';

/// Builds a drawer's (or sidebar's) scrolling body around [controller]: a `ListView` that pages, say.
/// It is the only part that scrolls; its padding is the caller's (see `UiDrawer.bodyPadding`).
typedef UiScrollBodyBuilder = Widget Function(BuildContext context, ScrollController controller);

/// The column used by `UiDrawer` and `UiSidebarLayout` (the web `.dh / .bd / .df` and
/// `.sb-hd / .sb-bd / .sb-ft`): a fixed [header], the [body] that takes the rest and is the only part
/// that scrolls, and a fixed [footer]. Each part keeps a 1px border so its height never changes; the
/// border shows under the header while the body is scrolled away from its top, and over the footer
/// while more of the body is below it. Not exported: the public API is on the drawer and the sidebar.
class UiPinnedEdges extends StatefulWidget {
  const UiPinnedEdges({
    super.key,
    required this.body,
    this.header,
    this.footer,
    required this.headerPadding,
    required this.footerPadding,
  });

  /// Builds the body around the column's own controller (a `SingleChildScrollView`, a `ListView`).
  /// A body that scrolls itself with its own controller still drives the hairlines: they follow the
  /// nearest vertical scroll view's notifications.
  final UiScrollBodyBuilder body;
  final Widget? header;
  final Widget? footer;
  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry footerPadding;

  /// Keys of the header's and footer's boxes (the ones that carry the hairline), for tests.
  static const headerKey = ValueKey('ui-pinned-edges-header');
  static const footerKey = ValueKey('ui-pinned-edges-footer');

  @override
  State<UiPinnedEdges> createState() => _UiPinnedEdgesState();
}

class _UiPinnedEdgesState extends State<UiPinnedEdges> {
  final ScrollController _controller = ScrollController();
  bool _before = false, _after = false;

  /// The body has been measured once: from then on the hairlines fade; the first report (on open)
  /// draws them at once.
  bool _measured = false;
  bool _instant = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _edges(bool before, bool after) {
    final first = !_measured;
    _measured = true;
    if (!mounted || (before == _before && after == _after)) return;
    setState(() {
      _instant = first;
      _before = before;
      _after = after;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final dur = context.uiAnimate && !_instant ? t.motionFast : Duration.zero;
    _instant = false;
    // Each part is its own focus group, so Tab goes header, body, footer even when rows scrolled out
    // of sight below sit under the footer on screen (reading order alone would visit the footer
    // first); the sort keys give screen readers the same order.
    Widget group(int order, Widget child) => Semantics(
          container: true,
          sortKey: OrdinalSortKey(order.toDouble()),
          child: FocusTraversalGroup(child: child),
        );
    Widget part(Key key, Widget child, EdgeInsetsGeometry padding, {required bool top, required bool show}) {
      final side = BorderSide(color: show ? t.border : t.border.withValues(alpha: 0));
      return AnimatedContainer(
        key: key,
        duration: dur,
        curve: t.easeStandard,
        padding: padding,
        decoration: BoxDecoration(border: top ? Border(top: side) : Border(bottom: side)),
        child: child,
      );
    }

    // No fixed parts: just the body, as before 0.41 (no extra focus groups or semantics nodes).
    if (widget.header == null && widget.footer == null) return widget.body(context, _controller);
    final body = UiScrollFade(
      size: 0,
      axis: Axis.vertical,
      onEdgesChanged: _edges,
      child: Builder(builder: (context) => widget.body(context, _controller)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.header != null) group(0, part(UiPinnedEdges.headerKey, widget.header!, widget.headerPadding, top: false, show: _before)),
        Expanded(child: group(1, body)),
        if (widget.footer != null) group(2, part(UiPinnedEdges.footerKey, widget.footer!, widget.footerPadding, top: true, show: _after)),
      ],
    );
  }
}
