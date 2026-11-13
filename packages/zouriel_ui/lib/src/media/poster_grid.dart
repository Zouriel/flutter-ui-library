import 'dart:ui' show ImageFilter;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/icon.dart';
import '../core/interactive.dart';
import '../core/types.dart';
import '../theme/theme.dart';

/// A small dot over a poster's corner: something the grid must say without words (unread,
/// unfinished). Only [UiStatus.primary], [UiStatus.warning] and [UiStatus.neutral] are drawn, as on
/// the web.
@immutable
class UiPosterMark {
  const UiPosterMark({required this.tone, required this.label});
  final UiStatus tone;

  /// Read out with the poster's name; the dot itself has no text.
  final String label;
}

/// One tile of a [UiPosterGrid] (the web `UiPoster`).
@immutable
class UiPoster {
  const UiPoster({required this.label, this.image, this.colors, this.mark, this.details, this.corner, this.action});

  /// The picture. Without one (or when it fails to load) the tile shows [colors] as a gradient.
  final ImageProvider? image;

  /// The tile's name: its semantic label, or read with [details] when there are details.
  final String label;

  /// Fallback gradient stops, e.g. a design's colours. Without them the theme's primary and accent.
  final List<Color>? colors;
  final UiPosterMark? mark;

  /// Drawn on the tile over the bottom of its picture on a compact [UiScrim] (the web's
  /// `uiPosterDetails` template). Keep it short (a title and a line or two, with ellipsis) and
  /// non-interactive: the whole tile is the target.
  final Widget? details;

  /// Drawn over the top-start corner of the picture (top-left in a left-to-right app), e.g. a
  /// venue's [UiAvatarTag] at size xs (the web's `uiPosterCorner` template). It sits inside the
  /// picture with a `space2` inset, above the picture and the details, never grows wider than the
  /// picture (less the room for the [mark]'s dot) and takes no taps: the whole tile is the target.
  final Widget? corner;

  /// One small action of the tile's own at the top-end corner of the picture (top-right in a
  /// left-to-right app), e.g. a ghost [UiIconButton] to view the invitation (the web's
  /// `uiPosterAction` template). It is laid over the tile but outside its tap handling, so tapping it
  /// never calls [UiPosterGrid.onSelect], and a round backdrop in the media scrim colour keeps it
  /// readable on any picture (ghost buttons inside draw in the on-scrim colour). Keep it to one small
  /// icon button (size sm or md). The [mark]'s dot moves beside it. 0.77.0.
  final Widget? action;
}

/// Which part of a picture survives a poster's crop.
enum UiPosterFocus { top, center }

/// The gradient a poster without a picture shows, shared by [UiPosterGrid] and [UiPosterView].
Gradient uiPosterFallback(BuildContext context, List<Color>? colors) {
  final t = context.ui;
  final c = colors ?? const <Color>[];
  final stops = c.length >= 2
      ? c
      : c.length == 1
          ? [c.first, Color.lerp(c.first, t.bg, 0.45)!]
          : [Color.lerp(t.primary, t.bg, 0.3)!, Color.lerp(t.accent, t.bg, 0.4)!];
  // 160deg on the web: from the top, leaning a little to the right.
  return LinearGradient(begin: const Alignment(-0.35, -1), end: const Alignment(0.35, 1), colors: stops);
}

/// `ui-poster-grid`: a grid of same-shape picture tiles ([ratio], width / height): 2 columns on a
/// phone, 3 from 544 wide, 4 from 992 and 5 from 1280 (of the grid's own width). A poster with
/// [UiPoster.details] carries them over the bottom of its picture on a compact [UiScrim] that fades
/// from clear to dark, so the words stay readable on any picture; without details a tile is the
/// picture alone, named by its semantic label. A tile with no picture shows a gradient, and a small dot
/// ([UiPoster.mark]) can flag it, named for screen readers. [UiPoster.corner] draws something small
/// (a [UiAvatarTag]) over the picture's top-start corner and [UiPoster.action] one small action (an
/// icon button) at its top-end corner, outside the tile's tap handling; a mark's dot then sits beside
/// the action. Tapping a tile calls [onSelect] with its index. It doesn't scroll: put it in a scroll view. (The web's `href` link tiles have no meaning
/// here: a tap is the only way to open a tile.)
class UiPosterGrid extends StatelessWidget {
  const UiPosterGrid({super.key, required this.posters, required this.onSelect, this.ratio = 0.75, this.focus = UiPosterFocus.center});

  final List<UiPoster> posters;
  final ValueChanged<int> onSelect;

  /// Width / height of every tile. 3/4 by default: invitations are read upright.
  final double ratio;

  /// [UiPosterFocus.top] keeps a poster's heading.
  final UiPosterFocus focus;

  /// How many columns a grid [width] wide shows.
  static int columnsFor(double width) => width >= 1280 ? 5 : width >= 992 ? 4 : width >= 544 ? 3 : 2;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    return LayoutBuilder(builder: (context, box) {
      final columns = columnsFor(box.maxWidth);
      final gap = box.maxWidth >= 544 ? t.space3 : t.space2;
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(spacing: gap, runSpacing: gap, children: [
        for (var i = 0; i < posters.length; i++)
          SizedBox(
            width: width,
            child: AspectRatio(aspectRatio: ratio, child: _Tile(poster: posters[i], focus: focus, onTap: () => onSelect(i))),
          ),
      ]);
    });
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.poster, required this.focus, required this.onTap});
  final UiPoster poster;
  final UiPosterFocus focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final r = BorderRadius.circular(context.uiTheme.radius());
    final mark = poster.mark;
    final action = poster.action;
    final fallback = DecoratedBox(decoration: BoxDecoration(gradient: uiPosterFallback(context, poster.colors)));
    // Room the corner keeps clear at the end: the dot, the action (one sm/md icon button), or both.
    final cornerEnd = action == null
        ? (mark != null ? t.space2 * 3 + 10 : t.space2)
        : (mark != null ? t.space2 * 4 + t.sizeMd + 10 : t.space2 * 3 + t.sizeMd);
    final tile = UiInteractive(
      onTap: onTap,
      padTouchTarget: false,
      // With details the words name the tile (and the dot's meaning is read after them).
      semanticLabel: poster.details != null ? null : mark == null ? poster.label : '${poster.label}, ${mark.label}',
      excludeChildSemantics: poster.details == null,
      builder: (context, s) => AnimatedContainer(
        duration: context.uiAnimate ? t.motionBase : Duration.zero,
        decoration: BoxDecoration(
          borderRadius: r,
          color: t.surfaceRaised,
          boxShadow: s.focused ? uiFocusRing(t, show: true) : s.hovered ? [BoxShadow(color: t.borderStrong, spreadRadius: 2)] : null,
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Stack(fit: StackFit.expand, children: [
            if (poster.image case final image?)
              Image(
                image: image,
                fit: BoxFit.cover,
                alignment: focus == UiPosterFocus.top ? Alignment.topCenter : Alignment.center,
                excludeFromSemantics: true,
                // A stored URL can outlive its file: the gradient, never a broken-image icon.
                errorBuilder: (_, _, _) => fallback,
              )
            else
              fallback,
            if (mark != null && action == null)
              PositionedDirectional(top: t.space2, end: t.space2, child: ExcludeSemantics(child: UiPosterDot(tone: mark.tone))),
            if (poster.details case final details?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: UiScrim(
                  compact: true,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
                    details,
                    if (mark != null) Semantics(label: mark.label, child: const SizedBox.shrink()),
                  ]),
                ),
              ),
            if (poster.corner case final corner?)
              // Inside the picture: start and end inset so it can never grow past it (nor over the dot).
              PositionedDirectional(
                key: const ValueKey('ui-poster-corner'),
                top: t.space2,
                start: t.space2,
                end: cornerEnd,
                child: IgnorePointer(child: Align(alignment: AlignmentDirectional.topStart, child: corner)),
              ),
          ]),
        ),
      ),
    );
    if (action == null) return tile;
    // The action sits beside the tile, not inside its UiInteractive: its own focus stop, and its taps
    // never select the tile. The dot beside it takes no taps, so they still reach the tile.
    return Stack(fit: StackFit.expand, children: [
      tile,
      PositionedDirectional(
        key: const ValueKey('ui-poster-action'),
        top: t.space2,
        end: t.space2,
        child: _HitPastEdges(
          child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (mark != null) ...[
              IgnorePointer(child: ExcludeSemantics(child: UiPosterDot(key: const ValueKey('ui-poster-action-dot'), tone: mark.tone))),
              SizedBox(width: t.space2),
            ],
            _ActionBackdrop(child: action),
          ]),
        ),
      ),
    ]);
  }
}

/// The round scrim backdrop of a [UiPoster.action], with on-scrim colours (and a pill radius) for
/// the buttons inside, as the web sets `--ui-color-text`, `--ui-color-icon` and `--ui-radius` on it.
class _ActionBackdrop extends StatelessWidget {
  const _ActionBackdrop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = context.uiTheme;
    final t = theme.tokens;
    final on = t.mediaOnScrim;
    final scoped = UiThemeData(
      name: theme.name,
      tokens: theme.baseTokens.copyWith(text: on, icon: on, surfaceHover: on.withValues(alpha: 0.18), radius: t.radiusPill),
      config: theme.config,
      compact: theme.compact,
    );
    return _VisualBackdrop(
      key: const ValueKey('ui-poster-action-backdrop'),
      color: t.mediaScrim.withValues(alpha: 0.55),
      child: UiTheme(
        data: scoped,
        child: IconTheme.merge(
          data: IconThemeData(color: on),
          child: DefaultTextStyle.merge(style: TextStyle(color: on), child: child),
        ),
      ),
    );
  }
}

/// Lays out and paints a pill backdrop around the action's *visual*: on touch platforms a button
/// pads its hit area to 44 (UiTouchTarget), which here overflows the box instead of growing it, as
/// the web's invisible `::before` hit-slop does. So the backdrop hugs the 26/30 button, the dot and
/// the corner are placed against it, and the whole padded area still takes taps.
class _VisualBackdrop extends SingleChildRenderObjectWidget {
  const _VisualBackdrop({super.key, required this.color, super.child});
  final Color color;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderVisualBackdrop(color);

  @override
  void updateRenderObject(BuildContext context, _RenderVisualBackdrop renderObject) => renderObject.color = color;
}

class _RenderVisualBackdrop extends RenderProxyBox {
  _RenderVisualBackdrop(this._color);

  Color _color;
  set color(Color v) {
    if (v == _color) return;
    _color = v;
    markNeedsPaint();
  }

  /// Where the child's top-left sits relative to this box (zero or negative: the overflowing padding).
  Offset _shift = Offset.zero;

  /// The visual inside the child: the child of its first [RenderUiTouchTarget], else the child itself.
  Rect _visualIn(RenderBox c) {
    RenderUiTouchTarget? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is RenderUiTouchTarget) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    c.visitChildren(visit);
    final target = found;
    if (target == null) return Offset.zero & c.size;
    final v = target.visualRect;
    return MatrixUtils.transformRect(target.getTransformTo(c), v);
  }

  @override
  void performLayout() {
    final c = child;
    if (c == null) {
      size = constraints.smallest;
      return;
    }
    c.layout(constraints.loosen(), parentUsesSize: true);
    final visual = _visualIn(c);
    size = constraints.constrain(visual.size);
    _shift = -visual.topLeft;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final r = size.shortestSide / 2;
    context.canvas.drawRRect(RRect.fromRectAndRadius(offset & size, Radius.circular(r)), Paint()..color = _color);
    final c = child;
    if (c != null) context.paintChild(c, offset + _shift);
  }

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(_shift.dx, _shift.dy, 0, 1);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final c = child;
    if (c == null) return false;
    // The child's whole padded area counts, past this box's edges.
    if (!(_shift & c.size).contains(position)) return false;
    final hit = result.addWithPaintOffset(offset: _shift, position: position, hitTest: (r, p) => c.hitTest(r, position: p));
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// Lets a tap on the action's overflowing touch padding (outside the row of dot and backdrop) reach
/// the action: the row itself would refuse it as out of its bounds.
class _HitPastEdges extends SingleChildRenderObjectWidget {
  const _HitPastEdges({super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitPastEdges();
}

class _RenderHitPastEdges extends RenderProxyBox {
  _RenderVisualBackdrop? _backdrop() {
    _RenderVisualBackdrop? found;
    void visit(RenderObject o) {
      if (found != null) return;
      if (o is _RenderVisualBackdrop) {
        found = o;
        return;
      }
      o.visitChildren(visit);
    }

    visitChildren(visit);
    return found;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (size.contains(position)) return super.hitTest(result, position: position);
    final b = _backdrop();
    if (b == null) return false;
    final hit = result.addWithPaintTransform(
      transform: b.getTransformTo(this),
      position: position,
      hitTest: (r, p) => b.hitTest(r, position: p),
    );
    if (hit) result.add(BoxHitTestEntry(this, position));
    return hit;
  }
}

/// The dot of a [UiPosterMark]: 10 across, a light ring then a faint dark edge, so it shows on any
/// picture, dark posters included.
class UiPosterDot extends StatelessWidget {
  const UiPosterDot({super.key, required this.tone});
  final UiStatus tone;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final fill = switch (tone) {
      UiStatus.primary => t.primary,
      UiStatus.warning => t.warning,
      _ => t.mediaOnScrim,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: t.mediaScrim.withValues(alpha: 0.35), spreadRadius: 3), BoxShadow(color: t.mediaOnScrim, spreadRadius: 2)],
      ),
    );
  }
}

/// `ui-scrim`: a see-through layer that fades from clear at its top to the media scrim colour at its
/// bottom, with text and icons in the on-scrim colour. Lay it over a picture to put words on it: the
/// fade has reached 60% before the content starts (after `space12`, or `space8` when [compact]) and
/// 88% at the bottom, so on-scrim text keeps at least 4.5:1 over any picture, white included.
class UiScrim extends StatelessWidget {
  const UiScrim({super.key, required this.child, this.compact = false});
  final Widget child;

  /// Sized for a grid tile: a `space8` fade and tighter padding, no width cap.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final lead = compact ? t.space8 : t.space12;
    final side = compact ? t.space2 : t.space4;
    final maxWidth = compact ? double.infinity : 640.0;
    return CustomPaint(
      painter: _ScrimPainter(color: t.mediaScrim, lead: lead),
      child: Padding(
        padding: EdgeInsets.fromLTRB(side, lead, side, side),
        // As wide as there is room for, up to 640, centred: the web's max-width with margin auto.
        child: LayoutBuilder(builder: (context, box) => Align(
              alignment: Alignment.topCenter,
              heightFactor: 1,
              child: SizedBox(
                width: box.maxWidth.isFinite ? (box.maxWidth < maxWidth ? box.maxWidth : maxWidth) : 640,
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: t.mediaOnScrim),
                  child: IconTheme.merge(data: IconThemeData(color: t.mediaOnScrim), child: child),
                ),
              ),
            )),
      ),
    );
  }
}

/// Clear at the top, 60% at [lead] down, 88% at the bottom: the same stops as the web's gradient.
class _ScrimPainter extends CustomPainter {
  _ScrimPainter({required this.color, required this.lead});
  final Color color;
  final double lead;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 0) return;
    final at = (lead / size.height).clamp(0.0, 1.0);
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.6), color.withValues(alpha: 0.88)],
          stops: [0, at, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ScrimPainter old) => old.color != color || old.lead != lead;
}

class _Close extends Intent {
  const _Close();
}

/// `ui-poster-view`: one picture full-size, with [child] laid over its bottom on a [UiScrim] (the
/// details and the buttons for whatever the picture stands for). The picture is shown whole, over a
/// blurred copy of itself that fills the screen; without a picture it shows the gradient
/// [UiPosterGrid] gives the tile. Escape, back or the close button close it. Open it with [show].
class UiPosterView extends StatelessWidget {
  const UiPosterView({super.key, required this.label, required this.child, required this.onClose, this.image, this.colors});

  final ImageProvider? image;

  /// The view's semantic label and the picture's.
  final String label;
  final List<Color>? colors;
  final Widget child;
  final VoidCallback onClose;

  /// Pushes the view over everything as a route that fades in. [builder] gets the route's context,
  /// so its buttons can pop it (`Navigator.pop`) before going somewhere else.
  static Future<T?> show<T>(BuildContext context, {required String label, required WidgetBuilder builder, ImageProvider? image, List<Color>? colors}) {
    final animate = context.uiAnimate;
    final t = context.ui;
    return Navigator.of(context).push<T>(PageRouteBuilder<T>(
      opaque: false,
      barrierLabel: label,
      transitionDuration: animate ? t.motionBase : Duration.zero,
      reverseTransitionDuration: animate ? t.motionBase : Duration.zero,
      pageBuilder: (context, _, _) => UiPosterView(
        label: label,
        image: image,
        colors: colors,
        onClose: () => Navigator.of(context).maybePop(),
        child: Builder(builder: builder),
      ),
      transitionsBuilder: (context, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: t.easeDecelerate), child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ui;
    final pad = MediaQuery.paddingOf(context);
    final fallback = DecoratedBox(decoration: BoxDecoration(gradient: uiPosterFallback(context, colors)));
    final pic = image;
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _Close()},
      child: Actions(
        actions: {_Close: CallbackAction<_Close>(onInvoke: (_) => onClose())},
        child: FocusScope(
          autofocus: true,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: label,
            child: ColoredBox(
              color: t.mediaScrim,
              child: Stack(fit: StackFit.expand, children: [
                if (pic != null) ...[
                  ExcludeSemantics(
                    child: ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28, tileMode: TileMode.clamp),
                        child: ColorFiltered(
                          colorFilter: ColorFilter.mode(t.mediaScrim.withValues(alpha: 0.45), BlendMode.srcOver),
                          child: Image(image: pic, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
                        ),
                      ),
                    ),
                  ),
                  Image(image: pic, fit: BoxFit.contain, semanticLabel: label, errorBuilder: (_, _, _) => fallback),
                ] else
                  fallback,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LayoutBuilder(builder: (context, _) {
                    final max = MediaQuery.sizeOf(context).height * 0.7;
                    return ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: max),
                      child: SingleChildScrollView(
                        child: UiScrim(child: Padding(padding: EdgeInsets.only(bottom: pad.bottom), child: child)),
                      ),
                    );
                  }),
                ),
                PositionedDirectional(
                  top: pad.top + t.space4,
                  end: t.space4,
                  child: UiInteractive(
                    onTap: onClose,
                    semanticLabel: context.uiStrings.close,
                    builder: (context, s) => AnimatedContainer(
                      duration: context.uiAnimate ? t.motionBase : Duration.zero,
                      width: uiMinTouchTarget,
                      height: uiMinTouchTarget,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: t.mediaScrim.withValues(alpha: s.hovered || s.pressed ? 0.65 : 0.45),
                        boxShadow: uiFocusRing(t, show: s.focused),
                      ),
                      child: Center(child: UiIcon(HugeIcons.strokeRoundedCancel01, size: 18, color: t.mediaOnScrim, strokeWidth: 2)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
