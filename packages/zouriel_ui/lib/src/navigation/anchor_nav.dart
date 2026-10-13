import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// A section an [UiAnchorNav] links to: put [key] on the section's widget.
@immutable
class UiAnchorItem {
  const UiAnchorItem({required this.key, required this.label});
  final GlobalKey key;
  final String label;
}

/// `ui-anchor-nav`: "on this page" navigation for a long scroll view (a scrollspy). It highlights
/// the section being read and scrolls to a section when its link is tapped.
///
/// Give it the page's [controller] and the sections as [items] (each with a [GlobalKey] placed on
/// the section). A section counts as being read once its top passes 35% of the way down the
/// viewport, below a fixed header of [offset] px, like the web version's observer band.
/// [Axis.horizontal] lays the links out as a scrolling strip, for the top of a phone screen.
class UiAnchorNav extends StatefulWidget {
  const UiAnchorNav({super.key, required this.items, required this.controller, this.offset = 0, this.axis = Axis.vertical, this.label = 'On this page'});

  final List<UiAnchorItem> items;
  final ScrollController controller;

  /// Height of anything covering the top of the scroll view (a header).
  final double offset;
  final Axis axis;
  final String label;

  @override
  State<UiAnchorNav> createState() => _UiAnchorNavState();
}

class _UiAnchorNavState extends State<UiAnchorNav> {
  int _active = 0;
  bool _jumping = false;
  final List<GlobalKey> _linkKeys = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_spy);
    WidgetsBinding.instance.addPostFrameCallback((_) => _spy());
  }

  @override
  void didUpdateWidget(UiAnchorNav old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_spy);
      widget.controller.addListener(_spy);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_spy);
    super.dispose();
  }

  /// The last section whose top has passed the reading line.
  void _spy() {
    // One scroll view only: the controller must belong to the page being followed.
    if (_jumping || widget.controller.positions.length != 1) return;
    final position = widget.controller.position;
    final viewport = position.context.notificationContext?.findRenderObject();
    if (viewport is! RenderBox || !viewport.hasSize) return;
    final top = viewport.localToGlobal(Offset.zero).dy;
    final line = top + widget.offset + (viewport.size.height - widget.offset) * 0.35;
    var next = 0;
    for (var i = 0; i < widget.items.length; i++) {
      final box = widget.items[i].key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      if (box.localToGlobal(Offset.zero).dy <= line) next = i;
    }
    _setActive(next);
  }

  void _setActive(int i) {
    if (i == _active || !mounted) return;
    setState(() => _active = i);
    // Keep the highlighted link visible in a horizontal strip.
    if (widget.axis == Axis.horizontal && i < _linkKeys.length) {
      final c = _linkKeys[i].currentContext;
      if (c != null) Scrollable.ensureVisible(c, alignment: 0.5, duration: context.uiAnimate ? context.ui.motionBase : Duration.zero);
    }
  }

  Future<void> _go(int i) async {
    final c = widget.items[i].key.currentContext;
    _setActive(i);
    if (c == null) return;
    _jumping = true;
    try {
      await Scrollable.ensureVisible(c, duration: context.uiAnimate ? context.ui.motionSlow : Duration.zero, curve: context.ui.easeStandard);
    } finally {
      _jumping = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    while (_linkKeys.length < widget.items.length) {
      _linkKeys.add(GlobalKey());
    }
    final horizontal = widget.axis == Axis.horizontal;
    final links = [
      for (var i = 0; i < widget.items.length; i++)
        _AnchorLink(key: _linkKeys[i], label: widget.items[i].label, active: i == _active, horizontal: horizontal, onTap: () => _go(i)),
    ];
    // The 1px rule runs under the links, so the active link's 2px edge covers it.
    final rule = ColoredBox(color: t.border);
    final Widget body = horizontal
        ? LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: box.maxWidth.isFinite ? box.maxWidth : 0),
                child: Stack(children: [
                  Positioned(left: 0, right: 0, bottom: 0, height: 1, child: rule),
                  Row(mainAxisSize: MainAxisSize.min, children: links),
                ]),
              ),
            ),
          )
        : Stack(children: [
            PositionedDirectional(start: 0, top: 0, bottom: 0, width: 1, child: rule),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, spacing: 2, children: links),
          ]);
    return Semantics(container: true, explicitChildNodes: true, role: SemanticsRole.navigation, label: widget.label, child: body);
  }
}

class _AnchorLink extends StatelessWidget {
  const _AnchorLink({super.key, required this.label, required this.active, required this.horizontal, required this.onTap});
  final String label;
  final bool active;
  final bool horizontal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final touch = uiTouchPlatform(context);
    return UiInteractive(
      onTap: onTap,
      selected: active,
      padTouchTarget: false,
      pressScale: false,
      builder: (context, s) {
        final c = active ? t.primary : (s.hovered || s.pressed ? t.text : t.textMuted);
        final edge = BorderSide(color: active ? t.primary : const Color(0x00000000), width: 2);
        return AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          curve: t.easeStandard,
          constraints: BoxConstraints(minHeight: touch ? uiMinTouchTarget : 0),
          padding: EdgeInsets.symmetric(vertical: t.space1, horizontal: t.space3),
          decoration: BoxDecoration(
            border: horizontal ? Border(bottom: edge) : BorderDirectional(start: edge),
            boxShadow: s.focused ? t.focusRing : const [],
          ),
          child: Align(
            alignment: horizontal ? Alignment.center : AlignmentDirectional.centerStart,
            widthFactor: horizontal ? 1 : null,
            heightFactor: 1,
            child: Text(label, maxLines: horizontal ? 1 : null, style: context.uiText.body.copyWith(fontSize: t.fontSizeSm, height: 1.35, color: c)),
          ),
        );
      },
    );
  }
}
