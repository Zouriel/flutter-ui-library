import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';

/// `ui-sidebar-layout`: an app shell. A fixed [sidebar] beside a scrolling [body] under a top bar
/// ([header]) when there is room; at or below [breakpoint] wide the sidebar becomes a drawer that
/// slides in from the start edge over a dimmed backdrop, opened by a built-in menu button.
///
/// The breakpoint is measured on the space the layout is given, so it works inside a preview as well
/// as full screen. Tapping the backdrop, Escape and the system back gesture close the drawer; while it
/// is open the page behind it is hidden from screen readers and focus stays inside. Widening past
/// the breakpoint closes it. The slide is instant under reduced motion.
///
/// Leave [open] null to let the layout keep its own drawer state, or drive it with [open] +
/// [onOpenChanged] (close it on navigation, for example).
class UiSidebarLayout extends StatefulWidget {
  const UiSidebarLayout({
    super.key,
    required this.sidebar,
    required this.body,
    this.header,
    this.breakpoint = 860,
    this.sidebarWidth = 248,
    this.open,
    this.onOpenChanged,
    this.padding,
    this.scrollBody = true,
  });

  final Widget sidebar;
  final Widget body;

  /// Top-bar content, after the menu button.
  final Widget? header;

  /// The widest layout (px) that still uses the drawer.
  final double breakpoint;
  final double sidebarWidth;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;

  /// Padding around the page (the web `--ui-shell-pad`): 24, or 16 in drawer mode.
  final EdgeInsetsGeometry? padding;

  /// Wrap [body] in a vertical scroll view. Turn off when the body scrolls itself (a list).
  final bool scrollBody;

  @override
  State<UiSidebarLayout> createState() => UiSidebarLayoutState();
}

/// Reach it with a `GlobalKey<UiSidebarLayoutState>` to call [toggle] / [close].
class UiSidebarLayoutState extends State<UiSidebarLayout> {
  bool _ownOpen = false;
  bool _compact = false;
  bool _wasOpen = false;
  final FocusScopeNode _drawerScope = FocusScopeNode(debugLabel: 'UiSidebarLayout drawer');

  bool get isOpen => _compact && (widget.open ?? _ownOpen);

  void _set(bool v) {
    if (widget.open == null) setState(() => _ownOpen = v);
    widget.onOpenChanged?.call(v);
  }

  /// Open or close the drawer.
  void toggle() => _set(!(widget.open ?? _ownOpen));

  /// Close the drawer (call on navigation).
  void close() {
    if (widget.open ?? _ownOpen) _set(false);
  }

  @override
  void dispose() {
    _drawerScope.dispose();
    super.dispose();
  }

  void _compactChanged(bool compact) {
    if (compact == _compact) return;
    _compact = compact;
    // Never leave a stale drawer open on a wide layout.
    if (!compact && (widget.open ?? _ownOpen)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) close();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      _compactChanged(box.maxWidth <= widget.breakpoint);
      final compact = _compact;
      final open = isOpen;
      if (open != _wasOpen) {
        _wasOpen = open;
        // Focus moves into the drawer so Escape and Tab work there, and leaves it on close.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (open) {
            _drawerScope.requestFocus();
          } else if (_drawerScope.hasFocus) {
            _drawerScope.unfocus();
          }
        });
      }
      final pad = widget.padding ?? EdgeInsets.all(compact ? t.space4 : t.space6);

      final bar = Container(
        constraints: BoxConstraints(minHeight: t.sizeTouch),
        padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: compact ? t.space4 : t.space6),
        decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.border))),
        child: Row(spacing: t.space3, children: [
          if (compact) _Burger(open: open, onTap: toggle),
          if (widget.header != null) Expanded(child: widget.header!),
        ]),
      );
      Widget page = Padding(padding: pad, child: widget.body);
      if (widget.scrollBody) page = SingleChildScrollView(child: page);
      final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [bar, Expanded(child: page)]);

      final side = DecoratedBox(
        decoration: BoxDecoration(color: t.surface, border: Border(right: BorderSide(color: t.border))),
        child: widget.sidebar,
      );

      if (!compact) {
        return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: widget.sidebarWidth, child: side),
          Expanded(child: main),
        ]);
      }

      final width = widget.sidebarWidth.clamp(0.0, box.maxWidth * 0.84);
      final dur = context.uiAnimate ? t.motionBase : Duration.zero;
      return PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: Stack(children: [
          Positioned.fill(child: ExcludeSemantics(excluding: open, child: ExcludeFocus(excluding: open, child: main))),
          // Backdrop: fades in, tap closes.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !open,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration: dur,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  excludeFromSemantics: true,
                  child: ColoredBox(color: t.overlay),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: dur,
            curve: t.easeStandard,
            top: 0,
            bottom: 0,
            left: open ? 0 : -width - 16,
            width: width,
            // Kept built while closed (it slides), but out of reach of focus and screen readers.
            child: ExcludeSemantics(
              excluding: !open,
              child: ExcludeFocus(
              excluding: !open,
              child: Container(
                decoration: BoxDecoration(color: t.surface, border: Border(right: BorderSide(color: t.border)), boxShadow: open ? t.shadow2 : null),
                padding: EdgeInsets.all(t.space3),
                // Shortcuts sit above the scope: key events bubble up from the focused node.
                child: Shortcuts(
                  shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
                  child: Actions(
                    actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => close())},
                    child: FocusScope(
                      node: _drawerScope,
                      child: Semantics(scopesRoute: open, explicitChildNodes: true, namesRoute: open, label: 'Navigation', child: widget.sidebar),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

/// The three-line menu button (30px visual, 48dp target on touch).
class _Burger extends StatelessWidget {
  const _Burger({required this.open, required this.onTap});
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: 'Toggle navigation',
      semanticHint: open ? 'Navigation open' : null,
      builder: (context, s) => Semantics(
        expanded: open,
        child: AnimatedContainer(
          duration: context.uiAnimate ? t.motionFast : Duration.zero,
          width: t.sizeMd,
          height: t.sizeMd,
          padding: EdgeInsets.symmetric(horizontal: t.space2),
          decoration: BoxDecoration(
            color: s.hovered || s.pressed ? t.surfaceHover : null,
            border: Border.all(color: t.border),
            borderRadius: BorderRadius.circular(context.uiTheme.radius()),
            boxShadow: uiFocusRing(t, show: s.focused),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [for (var i = 0; i < 3; i++) Container(height: 2, decoration: BoxDecoration(color: t.text, borderRadius: BorderRadius.circular(2)))],
          ),
        ),
      ),
    );
  }
}
