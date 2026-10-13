import 'package:flutter/widgets.dart';

/// `uiInfiniteScroll`: wrap a vertical scrollable; [onScrolledToEnd] fires once when a scroll brings
/// it within [threshold] px of the end, and again only after it has been scrolled back above that
/// line. It reacts to scrolling, so content shorter than the viewport never triggers it.
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

  bool _onScroll(ScrollUpdateNotification n) {
    if (n.depth != 0 || n.metrics.axis != Axis.vertical || !widget.enabled) return false;
    if (n.metrics.extentAfter <= widget.threshold) {
      if (_armed) {
        _armed = false;
        widget.onScrolledToEnd();
      }
    } else {
      _armed = true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollUpdateNotification>(onNotification: _onScroll, child: widget.child);
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
