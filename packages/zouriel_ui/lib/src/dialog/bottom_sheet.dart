import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../core/interactive.dart';
import '../overlay/backdrop.dart';
import '../theme/glass_sheet.dart';
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
/// focus back to where it came from. A sheet whose smallest snap is above 0 is [persistent]: it
/// has no closed state, so Back (and Escape) only collapse it to that smallest snap, and once it
/// rests there Back is not consumed and leaves the page as usual (the Material resting-sheet norm).
/// The handle is a button that steps through the snaps, and ArrowUp/Down on it do the same. On a
/// phone, focusing a text field inside raises it to its tallest snap ([expandOnFocus]), once per
/// field: typing, the keyboard opening and focus coming straight back to the same field don't raise
/// it again. While the keyboard is up the sheet rests on top of it.
///
/// When [snaps] changes (an app that sizes them to the space the keyboard leaves) and [snap] didn't,
/// the sheet stays at the snap nearest the height it rested at and reports it with [onSnapChanged];
/// an index past the end reads as the last snap, never as closed.
///
/// [glass] (0.41.2) makes it see-through, for a sheet over a map, and [glassStrength] (0.41.3) says
/// how much: [UiGlassStrength.clear] (the default) lets a map in the theme's own brightness plainly
/// show through (a light tint over a lightly blurred backdrop squeezed into the theme's clear range),
/// with text, muted text, primary and status colours AA over such a map; [UiGlassStrength.frosted] is
/// 0.41.2's near-opaque glass (60% tint, heavy blur), AA over anything, pure white and black included,
/// for photos or a map in the other brightness ([uiGlassSheetFilter]). Fields and buttons inside keep
/// their own solid fills. Under the platform's high-contrast setting it is the solid surface
/// ([uiGlassSheetSolid]). Off by default, whatever [UiConfig.glass] says.
///
/// [footer] (0.44.0, the web `[sheet-footer]` slot) is a sticky bar pinned to the bottom of the
/// visible sheet at every open snap, the peek included, and while it is dragged: the body scrolls
/// above it (a [child] gets the room automatically; a [builder]'s scroll view should add
/// [UiBottomSheetState.footerHeight] to its bottom padding). It has a hairline above it and the
/// body padding, plus the safe area when the sheet rests on the screen's bottom edge; with the
/// keyboard up it rests on the keyboard with the sheet. It is part of the sheet, so it counts in
/// [onCoverChanged]. Snaps stay fractions of the room, but an open snap too short for the header and
/// the footer is raised to fit them, so the footer is never cut off.
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
    this.maxWidth,
    this.glass = false,
    this.glassStrength = UiGlassStrength.clear,
    this.footer,
  }) : assert(child != null || builder != null, 'Give the sheet a child or a builder.');

  /// A sticky bar at the bottom of the visible sheet (0.44.0): the primary action.
  final Widget? footer;

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

  /// The widest the sheet gets, in px. On a wider screen the sheet (surface, handle, title row and
  /// body) is that wide and centred; the backdrop still covers the whole screen, and
  /// [onCoverChanged] still reports the covered height. Null (the default) is the full width.
  final double? maxWidth;

  /// See-through surface for a sheet over a map (0.41.2); see the class docs.
  final bool glass;

  /// How see-through [glass] is (0.41.3): clear (default) for a map in the theme's brightness,
  /// frosted for anything else.
  final UiGlassStrength glassStrength;

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

  /// The field that last raised the sheet; while [_refocus] runs, focus coming back to it is the
  /// platform's churn, not a new focus.
  FocusNode? _expandedFor;
  Timer? _refocus;
  FocusNode? _lastPrimary;

  /// Focus back on the same field within this long of leaving it doesn't raise the sheet again.
  static const Duration refocusWindow = Duration(milliseconds: 600);
  bool _wasModal = false;

  /// The header's and the footer's laid-out heights, measured after layout (0 until then).
  double _headerH = 0, _footerH = 0;

  /// How tall the footer is, safe area included (0 without one): a [UiBottomSheet.builder]'s scroll
  /// view adds it to its bottom padding.
  double get footerHeight => widget.footer == null ? 0 : _footerH;

  /// The snaps in use: the given ones, with an open snap too short for the header and the footer
  /// raised to fit them (kept ascending).
  List<double> get _snaps {
    final given = widget.snaps;
    if (widget.footer == null || _room <= 0 || _footerH <= 0) return given;
    final least = math.min(1.0, (_headerH + _footerH + 1) / _room);
    final out = <double>[];
    for (final s in given) {
      var v = s > 0 && s < least ? least : s;
      if (out.isNotEmpty && v <= out.last) v = math.min(1.0, out.last + 0.0001);
      out.add(v);
    }
    return out;
  }

  /// A measured height changed: rebuild, and move a resting sheet to its (possibly raised) snap.
  void _measured(void Function() set) {
    if (!mounted) return;
    setState(set);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_sheet.isAttached || _pointers > 0 || _headerDrag) return;
      if ((_sheet.size - _snaps[_index]).abs() > 0.001) {
        _moving++;
        _sheet.jumpTo(_snaps[_index]);
        _moving--;
      }
      _report();
    });
  }
  double get _max => _snaps.reduce(math.max);

  /// [_snap] within the snaps: past the end reads as the last one.
  int get _index => _snap.clamp(0, _snaps.length - 1);
  bool get isOpen => _snaps[_index] > 0;
  bool get _modal => widget.backdrop && isOpen;

  /// Index of the smallest snap.
  int get _lowest {
    var lo = 0;
    for (var i = 1; i < _snaps.length; i++) {
      if (_snaps[i] < _snaps[lo]) lo = i;
    }
    return lo;
  }

  /// Has no closed state: its smallest snap is above 0, so it is always on screen.
  bool get persistent => _snaps[_lowest] > 0;

  /// Back and Escape have something to do: close it, or for a [persistent] sheet, collapse it to
  /// its smallest snap. A persistent sheet resting there lets Back leave the page.
  bool get _collapsible => persistent ? _index != _lowest : isOpen;

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onSize);
    FocusManager.instance.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(UiBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.snap != oldWidget.snap && widget.snap != _snap) {
      _goTo(widget.snap, notify: false);
    } else if (!listEquals(widget.snaps, oldWidget.snaps)) {
      // New snaps, same snap: stay at the one nearest the fraction it rested at.
      final was = oldWidget.snaps[_snap.clamp(0, oldWidget.snaps.length - 1)];
      var best = 0;
      for (var i = 1; i < _snaps.length; i++) {
        if ((_snaps[i] - was).abs() < (_snaps[best] - was).abs()) best = i;
      }
      if (best != _snap) {
        _snap = best;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (best != widget.snap) widget.onSnapChanged?.call(best);
          if (_sheet.isAttached && (_sheet.size - _snaps[_index]).abs() > 0.001) {
            _moving++;
            _sheet.jumpTo(_snaps[_index]);
            _moving--;
          }
          _report();
        });
      }
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocus);
    _refocus?.cancel();
    _sheet.dispose();
    _scope.dispose();
    _handle.dispose();
    super.dispose();
  }

  bool _inside(FocusNode? n) => n != null && (n == _scope || n.ancestors.contains(_scope));

  void _onFocus() {
    final f = FocusManager.instance.primaryFocus;
    final inside = _inside(f);
    if (_lastPrimary == _expandedFor && _expandedFor != null && f != _expandedFor) {
      // Left the field that raised the sheet: for a moment, focus coming back to it is the
      // platform's churn (a blur and refocus), not a new focus.
      _refocus?.cancel();
      _refocus = Timer(refocusWindow, () => _refocus = null);
    }
    _lastPrimary = f;
    if (f == null) return;
    if (!inside) {
      _returnTo = f;
      return;
    }
    // A text field inside, on a touch screen: rise to the tallest snap, once per field.
    if (widget.expandOnFocus && uiTouchPlatform(context) && f.context?.findAncestorWidgetOfExactType<EditableText>() != null) {
      if (f == _expandedFor && _refocus != null) return;
      _expandedFor = f;
      final top = _snaps.length - 1;
      if (_snap != top) _goTo(top);
    }
  }

  /// Closes it (snap 0), sending focus back first if it is inside. A [persistent] sheet collapses
  /// to its smallest snap instead and keeps focus, since it stays on screen.
  void close() => _goTo(persistent ? _lowest : 0);

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

  /// What was last reported, so each change is reported once.
  double? _reportedHeight, _reportedCover;
  bool _reportQueued = false;

  /// Reports the resting height and cover when they differ from the last report. Called on every
  /// change of snap and after every layout (0.41.3): new snaps at the same index (an app that sizes
  /// its peek to content that grew), the keyboard, the offset, a top inset or the safe area all move
  /// the sheet's resting top without a snap change, and the cover must follow them.
  void _report() {
    final h = _room * _snaps[_index];
    final cover = h > 0 ? h + _bottom : 0.0;
    if (h == _reportedHeight && cover == _reportedCover) return;
    _reportedHeight = h;
    _reportedCover = cover;
    widget.onHeightChanged?.call(h);
    widget.onCoverChanged?.call(cover);
  }

  /// [_report] once after this frame, however many layouts it has.
  void _queueReport() {
    if (_reportQueued) return;
    _reportQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportQueued = false;
      if (mounted) _report();
    });
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
    _goTo(_index >= last ? math.max(0, firstOpen) : _index + 1);
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
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape && _collapsible) {
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
    _queueReport();
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
      canPop: !_collapsible,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _collapsible) close();
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
                final room = _room = box.maxHeight;
                _queueReport();
                final maxH = room * _max;
                final hidden = maxH - room * _snaps[_index];
                return BlockSemantics(
                  blocking: modal,
                  // Centred and capped at maxWidth; the sides stay open to the page (Align hit-tests
                  // only its child).
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: widget.maxWidth ?? double.infinity),
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
                          initialChildSize: _snaps[_index],
                          snapAnimationDuration: context.uiAnimate ? t.motionBase : const Duration(milliseconds: 1),
                          shouldCloseOnMinExtent: false,
                          builder: (context, scroll) => ExcludeFocus(
                            excluding: !isOpen,
                            child: ExcludeSemantics(
                              excluding: !isOpen,
                              // Always laid out at its tallest and clipped, so content doesn't reflow while dragging.
                              child: _withFooter(
                                context,
                                rr,
                                ClipRect(
                                  child: OverflowBox(
                                    alignment: Alignment.topCenter,
                                    minHeight: maxH,
                                    maxHeight: maxH,
                                    child: _panel(context, scroll, rr, hidden + (widget.footer != null ? _footerH : mq.padding.bottom * (_bottom > 0 ? 0 : 1))),
                                  ),
                                ),
                              ),
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
      semanticLabel: _index >= last ? 'Make smaller' : 'Make larger',
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
          _goTo((_index + i.by).clamp(0, last));
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
    final header = _SizeReporter(onSize: (sz) {
      if (sz.height != _headerH) _measured(() => _headerH = sz.height);
    }, child: GestureDetector(
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
    ));
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
        child: _surface(
          context,
          rr,
          DefaultTextStyle.merge(
            style: const TextStyle(height: 1.35),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                header,
                Container(height: 1, color: _glass ? t.glassBorder : t.borderSubtle),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _glass => widget.glass && !uiGlassSheetSolid(context);

  /// The sheet's box at its current (live) height with the footer pinned to its bottom, over the
  /// clipped panel. Without a footer, just the panel.
  Widget _withFooter(BuildContext context, Radius rr, Widget panel) {
    final footer = widget.footer;
    if (footer == null) return panel;
    final t = context.ui;
    final mq = MediaQuery.of(context);
    final safe = _bottom > 0 ? 0.0 : mq.padding.bottom;
    // On glass the footer is always frosted (0.44.2): the body scrolls under it, so clear glass would
    // show its text through the buttons.
    Widget bar = Container(
      decoration: BoxDecoration(
        color: _glass ? uiGlassSheetTint(t, strength: UiGlassStrength.frosted) : t.surface,
        border: Border(top: BorderSide(color: _glass ? t.glassBorder : t.borderSubtle)),
      ),
      padding: EdgeInsets.fromLTRB(t.space4, t.space3, t.space4, t.space3 + safe),
      child: footer,
    );
    if (_glass) bar = ClipRect(child: BackdropFilter(filter: uiGlassSheetFilter(t, strength: UiGlassStrength.frosted), child: bar));
    return Stack(fit: StackFit.expand, children: [
      panel,
      Positioned(
        left: 1,
        right: 1,
        bottom: 0,
        child: _SizeReporter(
          key: const ValueKey('ui-bottom-sheet-footer'),
          onSize: (sz) {
            if (sz.height != _footerH) _measured(() => _footerH = sz.height);
          },
          child: bar,
        ),
      ),
    ]);
  }

  /// The sheet's surface: solid, or see-through glass (the tint over a blurred, range-limited backdrop).
  Widget _surface(BuildContext context, Radius rr, Widget child) {
    final t = context.ui;
    final radius = BorderRadius.only(topLeft: rr, topRight: rr);
    if (!_glass) {
      return DecoratedBox(
        decoration: BoxDecoration(color: t.surface, borderRadius: radius, border: Border.all(color: t.border), boxShadow: isOpen ? t.shadow3 : null),
        child: ClipRRect(borderRadius: radius, child: child),
      );
    }
    return UiOutsetShadow(
      key: const ValueKey('ui-bottom-sheet-glass'),
      shadows: isOpen ? t.shadow3 : const [],
      borderRadius: radius,
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: uiGlassSheetFilter(t, strength: widget.glassStrength),
          child: DecoratedBox(
            decoration: BoxDecoration(color: uiGlassSheetTint(t, strength: widget.glassStrength), borderRadius: radius, border: Border.all(color: t.glassBorder)),
            child: child,
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

/// Calls [onSize] after the frame whenever its child's laid-out size changes.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({super.key, required this.onSize, super.child});
  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);
  ValueChanged<Size> onSize;
  Size? _last;

  @override
  void performLayout() {
    super.performLayout();
    if (size == _last) return;
    final s = _last = size;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (attached && _last == s) onSize(s);
    });
  }
}
