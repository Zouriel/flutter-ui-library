import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../theme/theme.dart';
import 'pinned_edges.dart';

/// `ui-sidebar-layout`: an app shell. A fixed [sidebar] beside a scrolling [body] under a top bar
/// ([header]) when there is room; at or below [breakpoint] wide the sidebar becomes a drawer that
/// slides in from the start edge over a dimmed backdrop, opened by a built-in menu button.
///
/// The sidebar sits on the start side, so it is on the right under a right-to-left
/// [Directionality] and its drawer slides in from the right.
///
/// The breakpoint is measured on the space the layout is given, so it works inside a preview as well
/// as full screen. Tapping the backdrop, Escape and the system back gesture close the drawer; while it
/// is open the page behind it is hidden from screen readers and focus stays inside, and closing it
/// gives focus back to whatever had it before (the menu button). Widening past the breakpoint
/// closes it. The slide is instant under reduced motion.
///
/// Leave [open] null to let the layout keep its own drawer state, or drive it with [open] +
/// [onOpenChanged] (close it on navigation, for example).
///
/// As a full-screen app shell (a chat app with its own top bar): `bar: false` drops the built-in
/// bar and menu button, and `fill: true` gives the body all the space with no padding and no
/// scroll view (it scrolls itself, with a composer docked at the bottom) and keeps clear of the
/// system's safe area. Read [UiSidebarLayout.of] inside to show your own menu button only in
/// drawer mode (`compact`) and to open the drawer.
///
/// The sidebar can have a fixed top and bottom, docked and in the drawer: [sidebarHeader] (a New
/// chat button) and [sidebarFooter] (account, settings) stay put and only [sidebar] between them
/// scrolls (or scrolls itself, with [scrollSidebar] false: a paging `ListView`). The safe area goes
/// on the outer parts, and a hairline shows under the header and over the footer while the list is
/// scrolled out of sight on that side (the web `[sidebar-header]` / `[sidebar-footer]`).
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
    this.bar = true,
    this.fill = false,
    this.scrollSidebar,
    this.sidebarHeader,
    this.sidebarFooter,
  });

  final Widget sidebar;
  final Widget body;

  /// Fixed at the top of the sidebar, above [sidebar] (the web `[sidebar-header]`).
  final Widget? sidebarHeader;

  /// Fixed at the bottom of the sidebar, below [sidebar] (the web `[sidebar-footer]`). With [fill]
  /// it sits at the bottom of the screen, clear of the home indicator.
  final Widget? sidebarFooter;

  /// Top-bar content, after the menu button.
  final Widget? header;

  /// The widest layout (px) that still uses the drawer.
  final double breakpoint;
  final double sidebarWidth;
  final bool? open;
  final ValueChanged<bool>? onOpenChanged;

  /// Padding around the page (the web `--ui-shell-pad`): 24, or 16 in drawer mode; none with [fill].
  final EdgeInsetsGeometry? padding;

  /// Wrap [body] in a vertical scroll view. Turn off when the body scrolls itself (a list). Ignored
  /// with [fill], whose body always scrolls itself.
  final bool scrollBody;

  /// The built-in top bar with [header] and the menu button. Off: no bar at all; the app opens the
  /// drawer itself ([open], [UiSidebarLayout.of]).
  final bool bar;

  /// A full-screen app shell: the body gets all the space with no padding and no scroll view, the
  /// sidebar scrolls inside itself, and both keep clear of the system's safe area (the insets in
  /// [MediaQuery], which are then removed for the children).
  final bool fill;

  /// Wrap [sidebar] in a vertical scroll view. Defaults to [fill]. Turn off when the sidebar scrolls
  /// itself (a `ListView`), since a list can't sit inside another scroll view.
  final bool? scrollSidebar;

  /// The nearest layout's state, for widgets inside it (sidebar, header, body).
  static UiSidebarLayoutScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'UiSidebarLayout.of() called outside a UiSidebarLayout');
    return scope!;
  }

  /// Like [of], but null outside a layout.
  static UiSidebarLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SidebarScope>()?.data;

  @override
  State<UiSidebarLayout> createState() => UiSidebarLayoutState();
}

/// What [UiSidebarLayout.of] gives the layout's children: whether it is in drawer mode and the
/// drawer is open, and the calls that open and close it.
@immutable
class UiSidebarLayoutScope {
  const UiSidebarLayoutScope({required this.compact, required this.open, required this.toggle, required this.close});

  /// At or below the breakpoint: the sidebar is a drawer (show a menu button).
  final bool compact;

  /// The drawer is open (always false when not [compact]).
  final bool open;

  /// Open or close the drawer.
  final VoidCallback toggle;

  /// Close the drawer.
  final VoidCallback close;

  @override
  bool operator ==(Object other) => other is UiSidebarLayoutScope && other.compact == compact && other.open == open;

  @override
  int get hashCode => Object.hash(compact, open);
}

class _SidebarScope extends InheritedWidget {
  const _SidebarScope({required this.data, required super.child});
  final UiSidebarLayoutScope data;

  @override
  bool updateShouldNotify(_SidebarScope oldWidget) => oldWidget.data != data;
}

/// Reach it with a `GlobalKey<UiSidebarLayoutState>` to call [toggle] / [close].
class UiSidebarLayoutState extends State<UiSidebarLayout> {
  bool _ownOpen = false;
  bool _compact = false;
  bool _wasOpen = false;
  FocusNode? _opener;
  final FocusScopeNode _drawerScope = FocusScopeNode(debugLabel: 'UiSidebarLayout drawer');

  bool get isOpen => _compact && (widget.open ?? _ownOpen);

  /// At or below the breakpoint: the sidebar is a drawer.
  bool get compact => _compact;

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

  void _openChanged(bool open) {
    if (open == _wasOpen) return;
    _wasOpen = open;
    // Remember what had focus (the menu button) before the drawer takes it.
    if (open) _opener = FocusManager.instance.primaryFocus;
    // Focus moves into the drawer so Escape and Tab work there, and goes back on close.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (open) {
        _drawerScope.requestFocus();
        return;
      }
      final back = _opener;
      _opener = null;
      if (!_drawerScope.hasFocus) return;
      if (back != null && back.context != null && back.canRequestFocus && !_drawerScope.descendants.contains(back)) {
        back.requestFocus();
      } else {
        _drawerScope.unfocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final strings = context.uiStrings;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final fill = widget.fill;
    final scrollSidebar = widget.scrollSidebar ?? fill;
    final safe = fill ? MediaQuery.paddingOf(context) : EdgeInsets.zero;
    // Physical insets on the sidebar's (start) side and the far (end) side.
    final startInset = rtl ? safe.right : safe.left;
    final endInset = rtl ? safe.left : safe.right;
    return LayoutBuilder(builder: (context, box) {
      _compactChanged(box.maxWidth <= widget.breakpoint);
      final compact = _compact;
      final open = isOpen;
      _openChanged(open);
      final pad = widget.padding ?? (fill ? EdgeInsets.zero : EdgeInsets.all(compact ? t.space4 : t.space6));

      Widget? topBar;
      if (widget.bar) {
        topBar = Container(
          constraints: BoxConstraints(minHeight: t.sizeTouch),
          padding: EdgeInsets.symmetric(vertical: t.space2, horizontal: compact ? t.space4 : t.space6),
          decoration: BoxDecoration(color: t.bg, border: Border(bottom: BorderSide(color: t.border))),
          child: Row(spacing: t.space3, children: [
            if (compact) _Burger(open: open, label: strings.sidebarToggle, onTap: toggle),
            if (widget.header != null) Expanded(child: widget.header!),
          ]),
        );
      }
      Widget page = Padding(padding: pad, child: widget.body);
      if (widget.scrollBody && !fill) page = SingleChildScrollView(child: page);
      Widget main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [?topBar, Expanded(child: page)]);
      if (fill) {
        // The page keeps clear of the notch and home indicator; the sidebar has its own side.
        main = Padding(
          padding: EdgeInsetsDirectional.only(top: safe.top, bottom: safe.bottom, start: compact ? startInset : 0, end: endInset),
          child: MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, removeLeft: true, removeRight: true, child: main),
        );
      }

      // The sidebar's own content, padded (and, in fill, clear of the safe area on its side). With a
      // fixed header or footer, the top inset goes on the first part and the bottom one on the last.
      Widget sideContent() {
        Widget clean(Widget c) => fill ? MediaQuery.removePadding(context: context, removeTop: true, removeBottom: true, removeLeft: true, removeRight: true, child: c) : c;
        final head = widget.sidebarHeader, foot = widget.sidebarFooter;
        final insets = EdgeInsetsDirectional.only(
          top: t.space3 + (head == null ? safe.top : 0),
          bottom: t.space3 + (foot == null ? safe.bottom : 0),
          start: t.space3 + startInset,
          end: t.space3,
        );
        Widget body(BuildContext context, ScrollController? controller) {
          final c = clean(widget.sidebar);
          if (scrollSidebar) return SingleChildScrollView(controller: controller, padding: insets, child: c);
          return Padding(padding: insets, child: c);
        }

        if (head == null && foot == null) return body(context, null);
        return UiPinnedEdges(
          header: head == null ? null : clean(head),
          footer: foot == null ? null : clean(foot),
          headerPadding: EdgeInsetsDirectional.only(top: t.space3 + safe.top, bottom: t.space3, start: t.space3 + startInset, end: t.space3),
          footerPadding: EdgeInsetsDirectional.only(top: t.space3, bottom: t.space3 + safe.bottom, start: t.space3 + startInset, end: t.space3),
          body: body,
        );
      }

      final scopeData = UiSidebarLayoutScope(compact: compact, open: open, toggle: toggle, close: close);
      Widget scoped(Widget child) => _SidebarScope(data: scopeData, child: child);

      if (!compact) {
        final side = DecoratedBox(
          decoration: BoxDecoration(color: t.surface, border: BorderDirectional(end: BorderSide(color: t.border))),
          child: sideContent(),
        );
        return scoped(Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(width: widget.sidebarWidth, child: side),
          Expanded(child: main),
        ]));
      }

      final width = widget.sidebarWidth.clamp(0.0, box.maxWidth * 0.84);
      final dur = context.uiAnimate ? t.motionBase : Duration.zero;
      return scoped(PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) close();
        },
        child: Stack(children: [
          Positioned.fill(child: ExcludeSemantics(excluding: open, child: ExcludeFocus(excluding: open, child: main))),
          // Backdrop: fades in, tap closes. Screen readers get it as a "Close navigation" button.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !open,
              child: ExcludeSemantics(
                excluding: !open,
                child: Semantics(
                  button: true,
                  label: strings.sidebarClose,
                  onTap: close,
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
            ),
          ),
          AnimatedPositionedDirectional(
            duration: dur,
            curve: t.easeStandard,
            top: 0,
            bottom: 0,
            start: open ? 0 : -width - 16,
            width: width,
            // Kept built while closed (it slides), but out of reach of focus and screen readers.
            child: ExcludeSemantics(
              excluding: !open,
              child: ExcludeFocus(
              excluding: !open,
              child: Container(
                decoration: BoxDecoration(color: t.surface, border: BorderDirectional(end: BorderSide(color: t.border)), boxShadow: open ? t.shadow2 : null),
                // Shortcuts sit above the scope: key events bubble up from the focused node.
                child: Shortcuts(
                  shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
                  child: Actions(
                    actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => close())},
                    child: FocusScope(
                      node: _drawerScope,
                      child: Semantics(
                        scopesRoute: open,
                        explicitChildNodes: true,
                        namesRoute: open,
                        label: strings.sidebarLabel,
                        onDismiss: open ? close : null,
                        child: sideContent(),
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ),
          ),
        ]),
      ));
    });
  }
}

/// The three-line menu button (30px visual, 48dp target on touch).
class _Burger extends StatelessWidget {
  const _Burger({required this.open, required this.label, required this.onTap});
  final bool open;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return UiInteractive(
      onTap: onTap,
      semanticLabel: label,
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
