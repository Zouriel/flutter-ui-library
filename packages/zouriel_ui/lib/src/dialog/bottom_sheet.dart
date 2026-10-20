import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../overlay/backdrop.dart';
import '../theme/theme.dart';
import 'modal.dart';

/// A fast release (logical px per second) moves one snap in that direction, however short the drag.
const double _flick = 450;

/// `ui-bottom-sheet`: a panel resting at the bottom of the screen that the user drags between
/// heights, the mobile answer to a sidebar. Put it last in a `Stack` over your page.
///
/// Heights are [snaps]: fractions of the room it has (the screen less [offset] below it for a
/// toolbar and [topInset] above it for a header). [snap] is the index it rests at; a first snap of
/// 0 is closed. Drag the header, or flick it: a fast release moves one snap that way. Dragging the
/// body moves the sheet when the content can't use the drag: pulling down with the content at its
/// top, or pushing up while there's a taller snap. Otherwise the content scrolls. Give a
/// [builder] that puts the provided controller on your own scroll view to make a list take part.
///
/// Non-modal by default: what's above stays usable, opening it does not move focus, and Tab can
/// leave it. With [backdrop] it is modal while open: the page dims and a tap on it closes the
/// sheet, focus moves to the handle and Tab stays inside, and screen readers can't reach the page.
/// Escape (with focus inside) and the Android back button close it either way; closing sends
/// focus back to where it came from. The handle is a button that steps through the snaps, and
/// ArrowUp/Down on it do the same. On a phone, focusing a text field inside raises it to its
/// tallest snap ([expandOnFocus]), and while the keyboard is up the sheet rests on top of it.
class UiBottomSheet extends StatefulWidget {
  const UiBottomSheet({
    super.key,
    this.child,
    this.builder,
    this.snaps = const [0, 0.5, 1],
    this.snap = 0,
    this.onSnapChanged,
    this.title = '',
    this.offset = 0,
    this.topInset = 0,
    this.backdrop = false,
    this.closable = true,
    this.hasHeader = false,
    this.actions,
    this.expandOnFocus = true,
    this.onHeightChanged,
    this.onCoverChanged,
  }) : assert(child != null || builder != null, 'Give the sheet a child or a builder.');

  /// The content, in a scroll view the sheet provides.
  final Widget? child;

  /// Builds your own scrolling content; put [controller] on its scroll view.
  final Widget Function(BuildContext context, ScrollController controller)? builder;

  /// The body padding a [child] gets (12px top and bottom, 16px sides, as in UiModal and UiDrawer).
  /// A [builder]'s own scroll view should use it too, so its content lines up with the title.
  static EdgeInsets bodyPadding(BuildContext context) {
    final t = context.ui;
    return EdgeInsets.symmetric(horizontal: t.space4, vertical: t.space3);
  }

  /// Resting heights as fractions (0 to 1) of the room the sheet has; ascending.
  final List<double> snaps;
  final int snap;

  /// The sheet came to rest at another snap (a drag, the handle, a backdrop tap, Escape, back).
  final ValueChanged<int>? onSnapChanged;
  final String title;

  /// Space kept free below the sheet, in px: a toolbar it sits on.
  final double offset;

  /// Space kept free above its tallest snap, in px: a header that stays reachable.
  final double topInset;
  final bool backdrop;

  /// Show a close button in the header.
  final bool closable;

  /// Show the header row even without a title, for the close button and [actions].
  final bool hasHeader;

  /// Extra header buttons (the web `[sheet-actions]` slot).
  final Widget? actions;
  final bool expandOnFocus;

  /// The height it came to rest at, in px.
  final ValueChanged<double>? onHeightChanged;

  /// How much of the screen, from its bottom edge, it covers once settled: the sheet plus what it
  /// rests on ([offset] or the keyboard). 0 when closed. For keeping content above it.
  final ValueChanged<double>? onCoverChanged;

  @override
  State<UiBottomSheet> createState() => UiBottomSheetState();
}

class UiBottomSheetState extends State<UiBottomSheet> {
  final DraggableScrollableController _sheet = DraggableScrollableController();
  final FocusScopeNode _scope = FocusScopeNode(debugLabel: 'UiBottomSheet');
  final FocusNode _handle = FocusNode(debugLabel: 'UiBottomSheet handle');
  late int _snap = widget.snap;
  int _pointers = 0;
  bool _headerDrag = false;

  /// Moves the sheet is making on its own (to a snap we already know about).
  int _moving = 0;
  double _room = 0, _bottom = 0;

  /// The last thing outside the sheet that had focus: where closing sends focus back.
  FocusNode? _returnTo;
  bool _wasModal = false;

  List<double> get _snaps => widget.snaps;
  double get _max => _snaps.reduce(math.max);
  bool get isOpen => _snaps[_snap.clamp(0, _snaps.length - 1)] > 0;
  bool get _modal => widget.backdrop && isOpen;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSize);
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snap != oldWidget.snap && widget.snap != _snap) _goTo(widget.snap, notify: false);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _sheet.dispose();
    _scope.dispose();
    _handle.dispose();
    super.dispose();
  }

  bool _inside(FocusNode? n) => n != null && (n == _scope || n.ancestors.contains(_scope));

  void _onFocus() {
    final f = FocusManager.instance.primaryFocus;
    if (f == null) return;
    if (!_inside(f)) {
      _returnTo = f;
      return;
    }
    // A text field inside, on a touch screen: rise to the tallest snap.
    if (widget.expandOnFocus && uiTouchPlatform(context) && f.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      final top = _snaps.length - 1;
      if (_snap != top) _goTo(top);
    }
  }

  /// Closes it (snap 0), sending focus back first if it is inside.
  void close() => _goTo(0);

  void _goTo(int i, {bool notify = true}) {
    i = i.clamp(0, _snaps.length - 1);
    final closing = _snaps[i] <= 0;
    if (closing) _restoreFocus();
    setState(() => _snap = i);
    if (notify && i != widget.snap) widget.onSnapChanged?.call(i);
    if (_sheet.isAttached) {
      _moving++;
      final done = context.uiAnimate
          ? _sheet.animateTo(_snaps[i], duration: context.ui.motionBase, curve: context.ui.easeStandard)
          : Future<void>.sync(() => _sheet.jumpTo(_snaps[i]));
      done.whenComplete(() => _moving--);
    }
    _report();
  }

  void _restoreFocus() {
    if (!_inside(FocusManager.instance.primaryFocus)) return;
    final back = _returnTo;
    if (back != null && back.context != null && back.canRequestFocus) {
      back.requestFocus();
    } else {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _report() {
    final h = _room * _snaps[_snap];
    widget.onHeightChanged?.call(h);
    widget.onCoverChanged?.call(h > 0 ? h + _bottom : 0);
  }

  /// Body drags and flings are snapped by the sheet itself; note where it comes to rest.
  void _onSize() {
    if (_pointers > 0 || _headerDrag || _moving > 0 || !_sheet.isAttached) return;
    final s = _sheet.size;
    for (var i = 0; i < _snaps.length; i++) {
      if ((s - _snaps[i]).abs() < 0.002 && i != _snap) {
        if (_snaps[i] <= 0) _restoreFocus();
        setState(() => _snap = i);
        if (i != widget.snap) widget.onSnapChanged?.call(i);
        _report();
        return;
      }
    }
  }

  void _stepFromHandle() {
    final last = _snaps.length - 1;
    final firstOpen = _snaps.indexWhere((s) => s > 0);
    _goTo(_snap >= last ? math.max(0, firstOpen) : _snap + 1);
  }

  void _dragUpdate(DragUpdateDetails d) {
    if (!_sheet.isAttached || _room <= 0) return;
    _headerDrag = true;
    _sheet.jumpTo((_sheet.size - d.delta.dy / _room).clamp(_snaps.reduce(math.min), _max));
  }

  void _dragEnd(DragEndDetails d) {
    if (!_headerDrag) return;
    _headerDrag = false;
    final size = _sheet.size;
    final v = d.velocity.pixelsPerSecond.dy;
    int target;
    if (v.abs() >= _flick) {
      // Flicked: the next snap past where it was let go, in the direction of travel.
      final up = v < 0;
      final c = [for (var i = 0; i < _snaps.length; i++) if (up ? _snaps[i] > size + 0.001 : _snaps[i] < size - 0.001) i];
      target = c.isEmpty ? (up ? _snaps.length - 1 : 0) : (up ? c.first : c.last);
    } else {
      target = 0;
      for (var i = 1; i < _snaps.length; i++) {
        if ((_snaps[i] - size).abs() < (_snaps[target] - size).abs()) target = i;
      }
    }
    _goTo(target);
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && isOpen) {
      close();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    _bottom = keyboard > 0 ? keyboard : widget.offset;
    final modal = _modal;
    _scope.traversalEdgeBehavior = modal ? TraversalEdgeBehavior.closedLoop : TraversalEdgeBehavior.parentScope;
    if (modal && !_wasModal) {
      // Became modal: move focus in, to the handle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _modal && !_inside(FocusManager.instance.primaryFocus)) _handle.requestFocus();
      });
    }
    _wasModal = modal;
    final rr = theme.config.radius ? Radius.circular(t.radiusLg) : Radius.zero;

    return PopScope(
      canPop: !isOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isOpen) close();
      },
      child: Stack(
        children: [
          // Always present, so the sheet below keeps its place in the Stack (and its state).
          // The backdrop fades in and out with the sheet (it used to vanish at once on close), and never
          // brightens again on the way out: it stays mounted at 0 while closed, ignoring touches.
          Positioned.fill(
            child: widget.backdrop
                ? IgnorePointer(
                    ignoring: !modal,
                    child: AnimatedOpacity(
                      opacity: modal ? 1 : 0,
                      duration: context.uiAnimate ? (modal ? t.motionBase : t.motionFast) : Duration.zero,
                      curve: t.easeStandard,
                      child: UiBackdrop(onTap: modal ? close : null, semanticLabel: modal ? context.uiStrings.close : null, opacity: kAlwaysCompleteAnimation),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: widget.topInset, bottom: _bottom),
              child: LayoutBuilder(builder: (context, box) {
                final room = box.maxHeight;
                if (room != _room) {
                  final first = _room == 0;
                  _room = room;
                  if (first) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _report() : null);
                }
                final maxH = room * _max;
                final hidden = maxH - room * _snaps[_snap];
                return BlockSemantics(
                  blocking: modal,
                  child: Listener(
                    onPointerDown: (_) => _pointers++,
                    onPointerUp: (_) => WidgetsBinding.instance.addPostFrameCallback((_) {
                      _pointers = math.max(0, _pointers - 1);
                      _onSize();
                    }),
                    onPointerCancel: (_) => _pointers = math.max(0, _pointers - 1),
                    child: DraggableScrollableSheet(
                      controller: _sheet,
                      expand: true,
                      snap: true,
                      snapSizes: _snaps,
                      minChildSize: _snaps.reduce(math.min),
                      maxChildSize: _max,
                      initialChildSize: _snaps[_snap],
                      snapAnimationDuration: context.uiAnimate ? t.motionBase : const Duration(milliseconds: 1),
                      shouldCloseOnMinExtent: false,
                      builder: (context, scroll) => ExcludeFocus(
                        excluding: !isOpen,
                        child: ExcludeSemantics(
                          excluding: !isOpen,
                          // Always laid out at its tallest and clipped, so content doesn't reflow while dragging.
                          child: ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: maxH,
                              maxHeight: maxH,
                              child: _panel(context, scroll, rr, hidden + mq.padding.bottom * (_bottom > 0 ? 0 : 1)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, ScrollController scroll, Radius rr, double bottomPad) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final touch = uiTouchPlatform(context);
    final showHeader = widget.title.isNotEmpty || widget.hasHeader;
    final last = _snaps.length - 1;
    final handle = UiInteractive(
      focusNode: _handle,
      onTap: _stepFromHandle,
      semanticLabel: _snap >= last ? 'Make smaller' : 'Make larger',
      excludeChildSemantics: true,
      padTouchTarget: false,
      pressScale: false,
      cursor: SystemMouseCursors.grab,
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowUp): _StepIntent(1),
        SingleActivator(LogicalKeyboardKey.arrowDown): _StepIntent(-1),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(onInvoke: (i) {
          _goTo((_snap + i.by).clamp(0, last));
          return null;
        }),
      },
      builder: (context, s) => SizedBox(
        height: touch ? uiMinTouchTarget : 24,
        child: Center(
          child: Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: t.borderStrong,
              borderRadius: BorderRadius.circular(t.radiusPill),
              boxShadow: s.focused ? t.focusRing : null,
            ),
          ),
        ),
      ),
    );
    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onVerticalDragUpdate: _dragUpdate,
      onVerticalDragEnd: _dragEnd,
      onVerticalDragCancel: () => _dragEnd(DragEndDetails()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          handle,
          if (showHeader)
            Padding(
              // On touch the buttons' 48dp areas already leave room below their visible boxes.
              padding: EdgeInsetsDirectional.fromSTEB(t.space4, 0, t.space4, touch ? 0 : t.space2),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 32),
                child: Row(
                  spacing: t.space2,
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.typography.body.copyWith(fontWeight: FontWeight.w600, fontSize: t.fontSizeMd, letterSpacing: t.trackingTight * t.fontSizeMd),
                      ),
                    ),
                    ?widget.actions,
                    if (widget.closable) UiDialogCloseButton(onPressed: close),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    final body = widget.builder != null
        ? widget.builder!(context, scroll)
        : SingleChildScrollView(
            controller: scroll,
            physics: const AlwaysScrollableScrollPhysics(),
            // Same body padding as UiModal and UiDrawer, so content lines up with the title.
            padding: UiBottomSheet.bodyPadding(context).copyWith(bottom: t.space3 + bottomPad),
            child: widget.child,
          );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      role: SemanticsRole.dialog,
      label: widget.title.isEmpty ? null : widget.title,
      child: FocusScope(
        node: _scope,
        onKeyEvent: _onKey,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: BorderRadius.only(topLeft: rr, topRight: rr),
            border: Border.all(color: t.border),
            boxShadow: isOpen ? t.shadow3 : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(topLeft: rr, topRight: rr),
            child: DefaultTextStyle.merge(
              style: const TextStyle(height: 1.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Container(height: 1, color: t.borderSubtle),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.by);
  final int by;
}
