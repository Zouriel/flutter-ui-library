import 'package:flutter/widgets.dart';

import '../theme/theme.dart';

/// `uiInfiniteScroll`: wrap a vertical scrollable; [onScrolledToEnd] fires once when a scroll brings
/// it within [threshold] px of the end, and again only after it has been scrolled back above that
/// line, or once the content grows (the new items arrived), when it checks again: a scroll that
/// jumps straight to the new end still loads. It reacts to scrolling, so content shorter than the
/// viewport never triggers it on its own.
class UiInfiniteScroll extends StatefulWidget {
  const UiInfiniteScroll({super.key, required this.child, required this.onScrolledToEnd, this.threshold = 120, this.enabled = true});

  final Widget child;
  final VoidCallback onScrolledToEnd;
  final double threshold;
  final bool enabled;

  @override
  State<UiInfiniteScroll> createState() => _UiInfiniteScrollState();
}

class _UiInfiniteScrollState extends State<UiInfiniteScroll> {
  bool _armed = true;
  double? _extent;

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || !widget.enabled) return false;
    _check(n.metrics);
    return false;
  }

  // New content arrived. Only after a load (while disarmed), so short content still waits for a scroll.
  bool _onMetrics(ScrollMetricsNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical) return false;
    final m = n.metrics;
    final grew = _extent != null && m.maxScrollExtent > _extent!;
    _extent = m.maxScrollExtent;
    if (grew && !_armed && widget.enabled) {
      _armed = true;
      _check(m);
    }
    return false;
  }

  void _check(ScrollMetrics m) {
    _extent = m.maxScrollExtent;
    if (m.extentAfter <= widget.threshold) {
      if (_armed) {
        _armed = false;
        widget.onScrolledToEnd();
      }
    } else {
      _armed = true;
    }
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollMetricsNotification>(
        onNotification: _onMetrics,
        child: NotificationListener<ScrollUpdateNotification>(onNotification: _onScroll, child: widget.child),
      );
}

/// `ui-virtual-list`: builds only the rows in view of a long list. Every row is exactly [itemExtent]
/// tall, so use it for fixed-height rows. (Flutter's `ListView.builder` already virtualises; this
/// is that, sized like the web component.)
class UiVirtualList<T> extends StatelessWidget {
  const UiVirtualList({super.key, required this.items, required this.itemBuilder, this.itemExtent = 32, this.height = 320, this.controller});

  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final double itemExtent;
  final double height;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        controller: controller,
        padding: EdgeInsets.zero,
        itemExtent: itemExtent,
        itemCount: items.length,
        itemBuilder: (context, i) => itemBuilder(context, items[i], i),
      ),
    );
  }
}

/// `uiScrollFade`: wrap a scroll view (a horizontal [SingleChildScrollView], say); each edge with more
/// content past it fades out, so a cut-off row reads as "scrolls on" rather than "ends here". Nothing
/// changes while the content fits. Used by `UiTable` and `UiSegmented`; [axis] vertical for a column
/// (`UiWorkflowGlobalSettings` above its footer).
class UiScrollFade extends StatefulWidget {
  const UiScrollFade({super.key, required this.child, this.size = 24, this.axis = Axis.horizontal, this.onEdgesChanged});

  final Widget child;

  /// Width of the fade, in logical px. 0 draws no fade: only [onEdgesChanged] reports (the web
  /// `[uiScrollFadeSize]="0"` with `#x="uiScrollFade"`).
  final double size;

  /// Whether there is hidden content before ([start]) and after ([end]) the visible part, each time
  /// that changes (the web `more` signal).
  final void Function(bool start, bool end)? onEdgesChanged;

  /// Which way the wrapped view scrolls.
  final Axis axis;

  @override
  State<UiScrollFade> createState() => _UiScrollFadeState();
}

class _UiScrollFadeState extends State<UiScrollFade> {
  bool _start = false, _end = false;
  // Keeps the scroll view (and its position) alive when the mask comes and goes around it.
  final _key = GlobalKey();

  bool _onMetrics(ScrollMetrics m) {
    if (m.axis != widget.axis) return false;
    final start = m.extentBefore > 0.5, end = m.extentAfter > 0.5;
    if (start != _start || end != _end) {
      setState(() {
        _start = start;
        _end = end;
      });
      widget.onEdgesChanged?.call(start, end);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final child = NotificationListener<ScrollMetricsNotification>(
      key: _key,
      onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) => n.depth == 0 && _onMetrics(n.metrics),
        child: widget.child,
      ),
    );
    if ((!_start && !_end) || widget.size <= 0) return child;
    // Any opaque colour works as a mask; only its alpha matters.
    final solid = context.ui.text;
    final clear = solid.withValues(alpha: 0);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) {
        final vertical = widget.axis == Axis.vertical;
        final extent = vertical ? r.height : r.width;
        final f = extent <= 0 ? 0.0 : (widget.size / extent).clamp(0.0, 0.5);
        return LinearGradient(
          begin: vertical ? Alignment.topCenter : Alignment.centerLeft,
          end: vertical ? Alignment.bottomCenter : Alignment.centerRight,
          colors: [_start ? clear : solid, solid, solid, _end ? clear : solid],
          stops: [0, f, 1 - f, 1],
        ).createShader(r);
      },
      child: child,
    );
  }
}
